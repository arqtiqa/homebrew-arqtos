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
  version "0.3.41"

  # Homebrew formulas cannot directly depend on casks (`depends_on cask:` is
  # rejected as "Unsupported special dependency"). The embedded Arqtos Dark/
  # Light Terminal.app profiles reference JetBrains Mono via a base64 NSFont
  # blob; floes without the font fall back to Menlo at first activation.
  # Operators install the font via a separate `brew install --cask` step;
  # caveats below surfaces the hint at install time.

  if OS.mac?
    if Hardware::CPU.arm?
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_darwin_arm64.tar.gz"
      sha256 "e20cd2a6d1f70dab409b6db49aa05f4e9d6890df2cc1fb24f0b1f27eec057bcb"
    else
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_darwin_amd64.tar.gz"
      sha256 "87705febe5ab2a496f99cd26c75135ab2954e6feff52b26622a97757e43ce304"
    end
  elsif OS.linux?
    if Hardware::CPU.arm?
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_linux_arm64.tar.gz"
      sha256 "f8c3cdccf30f0a07d02823ed8e26e40634f410cc8c9eb7b791b2753902be34d7"
    else
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_linux_amd64.tar.gz"
      sha256 "743b0ce9c068734d67f4a1af3e5903fea85c092bc0d66e293c6397d6841d1897"
    end
  end

  def install
    bin.install "arqtos", "arqtosd"
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
