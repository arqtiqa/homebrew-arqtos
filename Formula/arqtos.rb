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
class Arqtos < Formula
  desc "Operating layer for specialised professional teams"
  homepage "https://github.com/arqtiqa/arqtos"
  version "0.0.0-rc1"

  if OS.mac?
    if Hardware::CPU.arm?
      url "https://github.com/arqtiqa/arqtos-cli/releases/download/v#{version}/arqtos_#{version}_darwin_arm64.tar.gz"
      sha256 "a1cef98edccb5a7572056c5b4596a3ace1191562ea75fa9c4534fcfc169166d5"
    else
      url "https://github.com/arqtiqa/arqtos-cli/releases/download/v#{version}/arqtos_#{version}_darwin_amd64.tar.gz"
      sha256 "a458adbe429514c3085d18a535feb53b926d24cf524e88510897405bf16db9b5"
    end
  elsif OS.linux?
    if Hardware::CPU.arm?
      url "https://github.com/arqtiqa/arqtos-cli/releases/download/v#{version}/arqtos_#{version}_linux_arm64.tar.gz"
      sha256 "7a9c9220ee1cb29e9b532f5f41d277f22e967f9174d00190cef313af5f844f9b"
    else
      url "https://github.com/arqtiqa/arqtos-cli/releases/download/v#{version}/arqtos_#{version}_linux_amd64.tar.gz"
      sha256 "c75c28315245da895506fe64cc2340c05d2b033fc0bc1e2c3ac032484e290019"
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
