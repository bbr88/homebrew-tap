class Tabdump < Formula
  desc "TabDump runtime installer and CLI bootstrap"
  homepage "https://github.com/bbr88/tabdump"
  license "MIT"

  # Pin url/sha256 to the latest tabdump-homebrew-vX.Y.Z.tar.gz release asset.
  url "https://github.com/bbr88/tabdump/releases/download/v0.0.5-test/tabdump-homebrew-v0.0.5-test.tar.gz"
  sha256 "a555f48b614715d23eeaba901211205a836e4701e52fc27903030070a6f3fc23"

  depends_on :macos

  def install
    libexec.install Dir["*"]

    (bin/"tabdump-install").write <<~EOS
      #!/usr/bin/env bash
      set -euo pipefail
      archive="$(find "#{libexec}/dist" -maxdepth 1 -type f -name 'tabdump-app-v*.tar.gz' | head -n 1 || true)"
      if [[ -z "${archive}" ]]; then
        echo "[error] prebuilt app archive not found under #{libexec}/dist" >&2
        exit 1
      fi
      exec "#{libexec}/scripts/install.sh" --app-archive "${archive}" "$@"
    EOS
    chmod 0755, bin/"tabdump-install"

    (bin/"tabdump-uninstall").write <<~EOS
      #!/usr/bin/env bash
      set -euo pipefail
      exec "#{libexec}/scripts/uninstall.sh" "$@"
    EOS
    chmod 0755, bin/"tabdump-uninstall"
  end

  def caveats
    <<~EOS
      Bootstrap formula only. Replace url/sha256 with the latest release package.

      Install TabDump runtime into your user profile:
        tabdump-install --yes --vault-inbox ~/obsidian/Inbox/

      Uninstall runtime:
        tabdump-uninstall --yes
    EOS
  end

  test do
    assert_match "Usage:", shell_output("#{bin}/tabdump-install --help")
    assert_match "Usage:", shell_output("#{bin}/tabdump-uninstall --help")
  end
end
