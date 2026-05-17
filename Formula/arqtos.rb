# typed: false
# frozen_string_literal: true

# Homebrew formula for the arqtos toolkit binary.
#
# Closed-source distribution per Constitution §"Closed-Binary Distribution
# Discipline". The arqtos-cli repo is private; downloading release archives
# requires HOMEBREW_GITHUB_API_TOKEN to be set in the operator's environment.
#
# Install:
#   export HOMEBREW_GITHUB_API_TOKEN=ghp_xxx
#   brew tap arqtiqa/arqtos
#   brew install arqtos

require "download_strategy"
require "json"

# GitHubPrivateRepositoryReleaseDownloadStrategy authenticates the release
# asset fetch via the GitHub API. Necessary because direct
# https://github.com/<org>/<repo>/releases/download/... URLs return 404 for
# private repos without auth — and curl needs the Authorization header.
class GitHubPrivateRepositoryReleaseDownloadStrategy < CurlDownloadStrategy
  def initialize(url, name, version, **meta)
    super
    parse_url_pattern
    set_github_token
  end

  def parse_url_pattern
    pattern = %r{https://github\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/(\S+)}
    unless @url =~ pattern
      raise CurlDownloadStrategyError, "Invalid GitHub release URL: #{@url}"
    end

    _, @owner, @repo, @tag, @filename = *@url.match(pattern)
  end

  def set_github_token
    @github_token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", "")
    if @github_token.empty?
      raise CurlDownloadStrategyError,
            "HOMEBREW_GITHUB_API_TOKEN is required to install arqtos from the private tap"
    end
  end

  def _fetch(url:, resolved_url:, timeout:)
    asset_id = resolve_asset_id
    asset_url = "https://api.github.com/repos/#{@owner}/#{@repo}/releases/assets/#{asset_id}"
    curl_download asset_url,
                  "--header", "Accept: application/octet-stream",
                  "--header", "Authorization: token #{@github_token}",
                  to: temporary_path
  end

  def resolve_asset_id
    metadata = fetch_release_metadata
    asset = metadata["assets"].find { |a| a["name"] == @filename }
    raise CurlDownloadStrategyError, "Asset #{@filename} not found in release #{@tag}" if asset.nil?

    asset["id"]
  end

  def fetch_release_metadata
    release_url = "https://api.github.com/repos/#{@owner}/#{@repo}/releases/tags/#{@tag}"
    output, _, _ = curl_output(
      "--header", "Accept: application/vnd.github+json",
      "--header", "Authorization: token #{@github_token}",
      release_url,
    )
    JSON.parse(output)
  end
end

class Arqtos < Formula
  desc "Operating layer for specialised professional teams"
  homepage "https://github.com/arqtiqa/arqtos"
  version "0.3.5"

  # Homebrew formulas cannot directly depend on casks (`depends_on cask:` is
  # rejected as "Unsupported special dependency"). The embedded Arqtos Dark/
  # Light Terminal.app profiles reference JetBrains Mono via a base64 NSFont
  # blob; floes without the font fall back to Menlo at first activation.
  # Operators install the font via a separate `brew install --cask` step;
  # caveats below surfaces the hint at install time.

  if OS.mac?
    if Hardware::CPU.arm?
      url "https://github.com/arqtiqa/arqtos-cli/releases/download/v#{version}/arqtos_#{version}_darwin_arm64.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "033755228c74bbd297da84e98bce65ee91c98c5d76e42c66711bb84fb1388fd8"
    else
      url "https://github.com/arqtiqa/arqtos-cli/releases/download/v#{version}/arqtos_#{version}_darwin_amd64.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "e837c1f6d92dcff9ed4eab9453ac7c64839f71396f5b3b6c0786e9336570f3eb"
    end
  elsif OS.linux?
    if Hardware::CPU.arm?
      url "https://github.com/arqtiqa/arqtos-cli/releases/download/v#{version}/arqtos_#{version}_linux_arm64.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "a56139cdcc9e4c359c6a42f753d271d3fb79875d1488f0a0a05d8ae255dd5992"
    else
      url "https://github.com/arqtiqa/arqtos-cli/releases/download/v#{version}/arqtos_#{version}_linux_amd64.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "1675d30b2b1aa93c9713f030243e88cb6ae7f99cc0de0799d84b15b6b18c7fed"
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

    # Acceptance (v0.2.0+): arqtos index regenerate subcommand is wired + responds to --help.
    # Smoke-tests the new Story #10 capability without requiring filesystem state.
    index_help = shell_output("#{bin}/arqtos index regenerate --help")
    assert_match "regenerate", index_help
    assert_match "--check", index_help

    # Acceptance (v0.3.0+): arqtos focus subcommand is wired + responds to --help.
    # Smoke-tests the Story arqtos-cli#21 + #102 capabilities without requiring
    # a populated ~/.arqtos and ~/Arqtos tree (which the test env won't have).
    focus_help = shell_output("#{bin}/arqtos focus --help")
    assert_match "focus", focus_help
    assert_match "--dry-run", focus_help
    assert_match "--emit-env", focus_help

    # Acceptance (v0.3.1+): the 6 Stories under Feature arqtiqa/arqtos#40 ship
    # the full focus surface — --show-path / --exec / --status / --clear-overrides
    # on the focus subcommand, plus a new `arqtos floe` parent for terminal-profile
    # install. Smoke-test via --help only (no live filesystem state required).
    assert_match "--show-path", focus_help
    assert_match "--exec", focus_help
    assert_match "--status", focus_help
    assert_match "--clear-overrides", focus_help

    floe_help = shell_output("#{bin}/arqtos floe --help")
    assert_match "install-terminal-profiles", floe_help
  end
end
