# typed: false
# frozen_string_literal: true

# Homebrew formula for the arqtos toolkit binary.
#
# arqtos is closed-source: the source repo (arqtiqa/arqtos-cli) is private.
# The *compiled binary* is published as a public release asset on this tap
# (arqtiqa/homebrew-arqtos), so `brew install arqtos` requires no GitHub
# token and no per-machine auth. The binary is inert without an arqtos
# environment (config + bergs); config and secrets are never distributed here.
#
# Install:
#   brew tap arqtiqa/arqtos
#   brew install arqtos-cli
#
# RENAMED from `arqtos` at 0.3.58 (formula_renames.json migrates existing
# installs on `brew upgrade`; binaries stay `arqtos` + `arqtosd`). The bare
# formula token is retired; the cask namespace `arqtos` is reserved for the
# future macOS app. Ruling: berg homebrew-formula-rename-evaluation
# (doc-arq-00093).

class ArqtosCli < Formula
  desc "Operating layer for specialised professional teams"
  homepage "https://arqtos.io"
  version "0.3.58"

  # Homebrew formulas cannot directly depend on casks (`depends_on cask:` is
  # rejected as "Unsupported special dependency"). The embedded Arqtos Dark/
  # Light Terminal.app profiles reference JetBrains Mono via a base64 NSFont
  # blob; floes without the font fall back to Menlo at first activation.
  # Operators install the font via a separate `brew install --cask` step;
  # caveats below surfaces the hint at install time.

  if OS.mac?
    if Hardware::CPU.arm?
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_darwin_arm64.tar.gz"
      sha256 "ecc698b8128e46c37bf4dc036e4b94871124d431fee39dd77b7542e9fc08a24f"
    else
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_darwin_amd64.tar.gz"
      sha256 "50bc7437c9692d44e3e410ffd5713b528f95aef6b041e8d66eb602d00703fa08"
    end
  elsif OS.linux?
    if Hardware::CPU.arm?
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_linux_arm64.tar.gz"
      sha256 "ab53c8a421c4cabc08b283494725b175a784756dd76b9f4381ea0049bc0b74b6"
    else
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_linux_amd64.tar.gz"
      sha256 "11662ebd3ccc4e15c7a5df86fc68d8cfcec46f3cbb3751cd6acdd673f0da82f3"
    end
  end

  def install
    bin.install "arqtos", "arqtosd"
  end

  # Homebrew-managed reconciler (arqtiqa/arqtos-cli#773): `brew services start
  # arqtos` runs the resident berg reconciler, and `brew upgrade` auto-restarts
  # it onto the new binary. The daemon self-resolves the floe + resolves `op` by
  # absolute path (cli#753), so no special env is needed here.
  service do
    run [opt_bin/"arqtos", "reconciler", "run"]
    keep_alive true
    run_at_load true
    log_path "#{ENV["HOME"]}/Library/Logs/arqtos/sync-engine.log"
    error_log_path "#{ENV["HOME"]}/Library/Logs/arqtos/sync-engine.log"
  end

  def caveats
    <<~EOS
      The Arqtos Dark and Arqtos Light Terminal.app profiles render with
      JetBrains Mono. To install the font on this floe (one-time, separate
      from this formula since Homebrew doesn't support cask deps from
      formulas):

        brew install --cask font-jetbrains-mono

      Without the font installed, Terminal.app falls back to Menlo at first
      `arqtos focus <igloo>` activation; everything else works.
    EOS
  end

  test do
    # Acceptance: version subcommand reports the formula version + build metadata.
    output = shell_output("#{bin}/arqtos version")
    assert_match "arqtos #{version}", output
    assert_match "commit:", output
    assert_match "build date:", output

    # Acceptance: the focus surface is wired + responds to --help (no live
    # ~/.arqtos or ~/Arqtos tree required in the test sandbox).
    focus_help = shell_output("#{bin}/arqtos focus --help")
    assert_match "focus", focus_help
    assert_match "--dry-run", focus_help
    assert_match "--show-path", focus_help
    assert_match "--exec", focus_help
    assert_match "--status", focus_help
    assert_match "--clear-overrides", focus_help

    # Acceptance: the floe parent exposes terminal-profile install.
    floe_help = shell_output("#{bin}/arqtos floe --help")
    assert_match "install-terminal-profiles", floe_help

    # Acceptance: the MCP-bridge plugin surface — install / list / uninstall / show.
    plugin_help = shell_output("#{bin}/arqtos plugin --help")
    assert_match "install", plugin_help
    assert_match "list", plugin_help
    assert_match "uninstall", plugin_help
    assert_match "show", plugin_help
  end
end
