class Tabdump < Formula
  desc "Runtime installer and CLI bootstrap for browser tab dumps"
  homepage "https://github.com/bbr88/tabdump"

  # Pin url/sha256 to the latest tabdump-homebrew-vX.Y.Z.tar.gz release asset.
  url "https://github.com/bbr88/tabdump/releases/download/v0.1.2/tabdump-homebrew-v0.1.2.tar.gz"
  sha256 "d33422b4aced1156915404544bf7607f50bf81350e952c2b0e0cd862b6e7375d"
  license "MIT"

  depends_on :macos

  def install
    libexec.install Dir["*"]

    (bin/"tabdump").write <<~EOS
      #!/usr/bin/env bash
      set -euo pipefail

      INSTALL_SCRIPT="#{libexec}/scripts/install.sh"
      UNINSTALL_SCRIPT="#{libexec}/scripts/uninstall.sh"
      USER_TABDUMP="${HOME}/.local/bin/tabdump"

      usage() {
        cat <<'USAGE'
      Usage:
        tabdump init [install-options]
        tabdump uninstall [uninstall-options]
        tabdump [status|logs|mode|config|count|now|permissions|run|open|help] [args...]

      Bootstrap:
        init        Install TabDump runtime into your user profile.
        uninstall   Remove TabDump runtime from your user profile.

      After initialization, non-bootstrap subcommands are delegated to:
        ~/.local/bin/tabdump

      Examples:
        tabdump init --yes --vault-inbox ~/obsidian/Inbox/
        tabdump status
        tabdump now --close
        tabdump uninstall --yes
      USAGE
      }

      find_archive() {
        if [[ -f "#{libexec}/dist/tabdump-app.tar.gz" ]]; then
          echo "#{libexec}/dist/tabdump-app.tar.gz"
          return
        fi
        find "#{libexec}/dist" -maxdepth 1 -type f -name 'tabdump-app-v*.tar.gz' | LC_ALL=C sort | tail -n 1 || true
      }

      cmd="${1:-help}"

      case "${cmd}" in
        init)
          shift || true
          archive="$(find_archive)"
          if [[ -z "${archive}" ]]; then
            echo "[error] prebuilt app archive not found under #{libexec}/dist" >&2
            exit 1
          fi
          exec "${INSTALL_SCRIPT}" --app-archive "${archive}" "$@"
          ;;
        uninstall)
          shift || true
          exec "${UNINSTALL_SCRIPT}" "$@"
          ;;
        help|-h|--help)
          usage
          ;;
        *)
          if [[ -x "${USER_TABDUMP}" ]]; then
            exec "${USER_TABDUMP}" "${cmd}" "$@"
          fi
          echo "[error] TabDump is not initialized yet." >&2
          echo "[hint] Run: tabdump init --yes --vault-inbox ~/obsidian/Inbox/" >&2
          exit 1
          ;;
      esac
    EOS
    chmod 0755, bin/"tabdump"
  end

  def caveats
    <<~EOS
      Formula is pinned to a specific signed release artifact.
      Upgrade to newer versions with: brew update && brew upgrade tabdump

      Initialize TabDump runtime in your user profile (LLM-enabled default):
        tabdump init --yes --vault-inbox ~/obsidian/Inbox --enable-llm true --key-mode keychain

      Optional no-LLM initialization:
        tabdump init --yes --vault-inbox ~/obsidian/Inbox

      Runtime paths (fixed contract):
        App: ~/Applications/TabDump.app
        App Support: ~/Library/Application Support/TabDump/
        Launch agent: ~/Library/LaunchAgents/io.orc-visioner.tabdump.monitor.plist

      Logs:
        tabdump logs
        Files: ~/Library/Application Support/TabDump/logs/monitor.out.log
               ~/Library/Application Support/TabDump/logs/monitor.err.log

      Is it running?
        tabdump status

      Uninstall runtime:
        tabdump uninstall --yes
    EOS
  end

  test do
    help_output = shell_output("#{bin}/tabdump --help")

    assert_match "tabdump init", help_output
    assert_match "tabdump [status|logs|mode|config|count|now|permissions|run|open|help]",
                 help_output
    assert_match "not initialized", shell_output("#{bin}/tabdump status 2>&1", 1)
  end
end
