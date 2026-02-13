#!/usr/bin/env bash
set -euo pipefail

TAP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORMULA_PATH="${TAP_ROOT}/Formula/tabdump.rb"
RELEASE_REPO="bbr88/tabdump"
TAG=""
SHA256=""
SHA256_FILE=""
FETCH_SHA_FROM_RELEASE=0
CHECK_ASSET_URL=1
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/bump-tabdump-formula.sh --tag <vX.Y.Z> [--sha256 <hash> | --sha256-file <path> | --from-release] [options]

Options:
  --tag <vX.Y.Z>              Release tag (example: v1.2.3).
  --sha256 <hash>             SHA256 for tabdump-homebrew-<tag>.tar.gz.
  --sha256-file <path>        Read SHA256 from a .sha256 file (first token).
  --from-release              Fetch SHA256 from release asset .sha256 file.
  --release-repo <owner/repo> GitHub source repo hosting release assets (default: bbr88/tabdump).
  --skip-url-check            Do not verify release asset URL is reachable.
  --dry-run                   Show proposed changes without writing.
  -h, --help                  Show this help.

Examples:
  scripts/bump-tabdump-formula.sh --tag v0.0.5-test --sha256 <64hex>
  scripts/bump-tabdump-formula.sh --tag v0.0.5-test --sha256-file /tmp/tabdump-homebrew-v0.0.5-test.tar.gz.sha256
  scripts/bump-tabdump-formula.sh --tag v0.0.5-test --from-release
USAGE
}

require_value() {
  local option="$1"
  local value="${2:-}"
  if [[ -z "${value}" || "${value}" == --* ]]; then
    echo "[error] Option ${option} requires a value." >&2
    exit 1
  fi
}

normalize_path() {
  INPUT_PATH_RAW="$1" python3 - <<'PY'
import os
import sys

raw = os.environ.get("INPUT_PATH_RAW", "").strip()
if not raw:
    sys.exit(1)
print(os.path.abspath(os.path.expanduser(raw)))
PY
}

validate_tag() {
  local value="$1"
  if [[ ! "${value}" =~ ^v[0-9A-Za-z][0-9A-Za-z._-]*$ ]]; then
    echo "[error] Invalid tag value: ${value}" >&2
    echo "[hint] Expected something like v1.2.3 or v1.2.3-rc1." >&2
    exit 1
  fi
}

read_sha256_from_file() {
  local path="$1"
  if [[ ! -f "${path}" ]]; then
    echo "[error] SHA256 file not found: ${path}" >&2
    exit 1
  fi
  awk 'NF {print $1; exit}' "${path}"
}

validate_sha256() {
  local value="$1"
  if [[ ! "${value}" =~ ^[0-9a-fA-F]{64}$ ]]; then
    echo "[error] Invalid sha256 value: ${value}" >&2
    exit 1
  fi
}

fetch_sha256_from_release() {
  local checksum_url="$1"
  local checksum

  if ! command -v curl >/dev/null 2>&1; then
    echo "[error] curl is required for --from-release." >&2
    exit 1
  fi

  if ! checksum="$(curl -fsSL "${checksum_url}" | awk 'NF {print $1; exit}')"; then
    echo "[error] Failed to fetch checksum from: ${checksum_url}" >&2
    exit 1
  fi

  echo "${checksum}"
}

check_release_asset_accessible() {
  local url="$1"

  if ! command -v curl >/dev/null 2>&1; then
    echo "[warn] curl not found; skipping URL accessibility check." >&2
    return 0
  fi

  if ! curl -fsIL "${url}" >/dev/null; then
    echo "[error] Release asset URL is not reachable: ${url}" >&2
    exit 1
  fi
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --tag)
        require_value "$1" "${2:-}"
        TAG="$2"
        shift 2
        ;;
      --sha256)
        require_value "$1" "${2:-}"
        SHA256="$2"
        shift 2
        ;;
      --sha256-file)
        require_value "$1" "${2:-}"
        SHA256_FILE="$2"
        shift 2
        ;;
      --from-release)
        FETCH_SHA_FROM_RELEASE=1
        shift
        ;;
      --release-repo)
        require_value "$1" "${2:-}"
        RELEASE_REPO="$2"
        shift 2
        ;;
      --skip-url-check)
        CHECK_ASSET_URL=0
        shift
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "[error] Unknown option: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done
}

main() {
  parse_args "$@"

  if [[ -z "${TAG}" ]]; then
    echo "[error] --tag is required." >&2
    usage >&2
    exit 1
  fi
  validate_tag "${TAG}"

  local source_count=0
  [[ -n "${SHA256}" ]] && source_count=$((source_count + 1))
  [[ -n "${SHA256_FILE}" ]] && source_count=$((source_count + 1))
  [[ "${FETCH_SHA_FROM_RELEASE}" -eq 1 ]] && source_count=$((source_count + 1))

  if [[ "${source_count}" -gt 1 ]]; then
    echo "[error] Use only one of: --sha256, --sha256-file, --from-release." >&2
    exit 1
  fi

  local asset checksum_asset url checksum_url
  asset="tabdump-homebrew-${TAG}.tar.gz"
  checksum_asset="${asset}.sha256"
  url="https://github.com/${RELEASE_REPO}/releases/download/${TAG}/${asset}"
  checksum_url="https://github.com/${RELEASE_REPO}/releases/download/${TAG}/${checksum_asset}"

  if [[ "${CHECK_ASSET_URL}" -eq 1 ]]; then
    check_release_asset_accessible "${url}"
  fi

  if [[ -n "${SHA256_FILE}" ]]; then
    SHA256_FILE="$(normalize_path "${SHA256_FILE}")"
    SHA256="$(read_sha256_from_file "${SHA256_FILE}")"
  elif [[ "${FETCH_SHA_FROM_RELEASE}" -eq 1 || -z "${SHA256}" ]]; then
    SHA256="$(fetch_sha256_from_release "${checksum_url}")"
  fi

  SHA256="$(echo "${SHA256}" | tr '[:upper:]' '[:lower:]')"
  validate_sha256 "${SHA256}"

  if [[ ! -f "${FORMULA_PATH}" ]]; then
    echo "[error] Formula file not found: ${FORMULA_PATH}" >&2
    exit 1
  fi

  local tmp_file
  tmp_file="$(mktemp "${TMPDIR:-/tmp}/tabdump-formula.XXXXXX")"

  FORMULA_PATH="${FORMULA_PATH}" NEW_URL="${url}" NEW_SHA="${SHA256}" python3 - <<'PY' > "${tmp_file}"
import os
import re
import sys

path = os.environ["FORMULA_PATH"]
new_url = os.environ["NEW_URL"]
new_sha = os.environ["NEW_SHA"]

text = open(path, "r", encoding="utf-8").read()

url_re = re.compile(r'^\s*url\s+"[^"]+"[ \t]*$', re.M)
sha_re = re.compile(r'^\s*sha256\s+"[0-9a-fA-F]{64}"[ \t]*$', re.M)

if not url_re.search(text):
    print("[error] Could not find url line in formula.", file=sys.stderr)
    sys.exit(1)
if not sha_re.search(text):
    print("[error] Could not find sha256 line in formula.", file=sys.stderr)
    sys.exit(1)

text = url_re.sub(f'  url "{new_url}"', text, count=1)
text = sha_re.sub(f'  sha256 "{new_sha}"', text, count=1)

sys.stdout.write(text)
PY

  if cmp -s "${FORMULA_PATH}" "${tmp_file}"; then
    rm -f "${tmp_file}"
    echo "[ok] Formula already up to date (${TAG})."
    echo "[ok] url=${url}"
    echo "[ok] sha256=${SHA256}"
    exit 0
  fi

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[info] Dry run: would update ${FORMULA_PATH}"
    diff -u "${FORMULA_PATH}" "${tmp_file}" || true
    rm -f "${tmp_file}"
    exit 0
  fi

  mv "${tmp_file}" "${FORMULA_PATH}"

  if ! ruby -c "${FORMULA_PATH}" >/dev/null; then
    echo "[error] Formula syntax check failed after update." >&2
    exit 1
  fi

  echo "[ok] Updated ${FORMULA_PATH}"
  echo "[ok] url=${url}"
  echo "[ok] sha256=${SHA256}"
}

main "$@"
