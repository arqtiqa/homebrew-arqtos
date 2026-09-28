# typed: false
# frozen_string_literal: true

# arqtos-core is not a user-facing Homebrew token. The Line-5 runtime
# ships as Formula/arqtos-cli.rb (operator ruling 2026-09-24). brew
# install arqtos-core is refused; this file exists so the old token
# names the replacement instead of 404ing.

class ArqtosCore < Formula
  desc "Not installable; the Line-5 runtime is arqtos-cli"
  homepage "https://arqtos.io"
  url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v0.5.0/arqtos_0.5.0_darwin_arm64.tar.gz"
  sha256 "0ba027b4e0f5fa0e8550318f0133ccecc105356833103e9489afa87e47c141ab"
  version "0.5.0"
  disable! date: "2026-09-27", because: "the Line-5 runtime ships as arqtos-cli"

  def install
    odie "install arqtos-cli; arqtos-core is not a brew token"
  end
end
