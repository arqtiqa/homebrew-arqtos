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
  version "0.1.1"

  if OS.mac?
    if Hardware::CPU.arm?
      url "https://github.com/arqtiqa/arqtos-cli/releases/download/v#{version}/arqtos_#{version}_darwin_arm64.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "d6b7b1e28e3dc377feb3db86534a8f6f9d7361073acb141656883c182e61fd1a"
    else
      url "https://github.com/arqtiqa/arqtos-cli/releases/download/v#{version}/arqtos_#{version}_darwin_amd64.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "907034d412029241edc1cc39bf7b292c4c933f35edc083ee48f363966983f524"
    end
  elsif OS.linux?
    if Hardware::CPU.arm?
      url "https://github.com/arqtiqa/arqtos-cli/releases/download/v#{version}/arqtos_#{version}_linux_arm64.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "858434c9f7e2fc84bc0dbc9a57789c04df8387368809c56be8b929ba1c7b74f8"
    else
      url "https://github.com/arqtiqa/arqtos-cli/releases/download/v#{version}/arqtos_#{version}_linux_amd64.tar.gz",
          using: GitHubPrivateRepositoryReleaseDownloadStrategy
      sha256 "a73a1bd46e66277a3c144baaba38addd0a7afdeff519295a2f9a5cb816ae3622"
    end
  end

  def install
    bin.install "arqtos"
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
  end
end
