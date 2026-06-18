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
#   brew install arqtos

class Arqtos < Formula
  desc "Operating layer for specialised professional teams"
  homepage "https://arqtos.io"
  version "0.3.40"

  # Homebrew formulas cannot directly depend on casks (`depends_on cask:` is
  # rejected as "Unsupported special dependency"). The embedded Arqtos Dark/
  # Light Terminal.app profiles reference JetBrains Mono via a base64 NSFont
  # blob; floes without the font fall back to Menlo at first activation.
  # Operators install the font via a separate `brew install --cask` step;
  # caveats below surfaces the hint at install time.

  if OS.mac?
    if Hardware::CPU.arm?
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_darwin_arm64.tar.gz"
      sha256 "176b73519d4d9be3b5cfd8fddd560b89519daa3d5e9b7ebf19bcd3e6391afd53"
    else
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_darwin_amd64.tar.gz"
      sha256 "07de3a6958106d69312e0b1b6df77b5678bb27a08ff4bb2b77e409f4d647f8f9"
    end
  elsif OS.linux?
    if Hardware::CPU.arm?
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_linux_arm64.tar.gz"
      sha256 "d020ae5d3a6038397fd2fb2fcdc4c1773bf55611f7f506cc0358a4a58eb23cea"
    else
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_linux_amd64.tar.gz"
      sha256 "3efa89c9625bb77ac6a2d137ed7e389f20973750a6fd04b711612435fec9cc49"
    end
  end

  def install
    bin.install "arqtos"
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

    # Acceptance: seed pack catalogue is embedded and listable.
    pack_list = shell_output("#{bin}/arqtos pack list")
    assert_match "daily-flow-pack", pack_list
    assert_match "go-builder-pack", pack_list

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
