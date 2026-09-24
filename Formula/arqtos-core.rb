# typed: false
# frozen_string_literal: true

# Homebrew formula for the line-5 arqtos runtime.
#
# The line-4 formula `arqtos-cli` (arqtos + arqtosd) is unchanged: this token
# is a new install, not an in-place upgrade. The bare formula token `arqtos`
# stays reserved for the future macOS app cask
# (berg homebrew-formula-rename-evaluation, doc-arq-00093).
#
# Install:
#   brew tap arqtiqa/arqtos
#   brew install arqtos-core
#
# Service activation is a separate step (`brew services start arqtos-core`).
# The install hook does not start daemons, write LaunchAgents, or rewrite
# user configuration.

class ArqtosCore < Formula
  desc "Line-5 arqtos runtime"
  homepage "https://arqtos.io"
  version "0.5.0-alpha.0"

  if OS.mac?
    if Hardware::CPU.arm?
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos-core_#{version}_darwin_arm64.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    else
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos-core_#{version}_darwin_amd64.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
  elsif OS.linux?
    if Hardware::CPU.arm?
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos-core_#{version}_linux_arm64.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    else
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos-core_#{version}_linux_amd64.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
  end

  def install
    bin.install "arqtos", "arqtos-broker", "arqtos-connectors", "arqtos-gateway", "arqtos-reconciler"
    (pkgshare/"launchd").mkpath
    runtime = (var/"run")
    %w[gateway broker connectors].each do |member|
      (pkgshare/"launchd/io.arqtos.#{member}.plist").write socket_plist(member, runtime)
    end
    (pkgshare/"launchd/io.arqtos.reconciler.plist").write reconciler_plist
  end

  service do
    run [
      opt_bin/"arqtos-reconciler",
      "--resident",
    ]
    keep_alive true
    require_root false
    environment_variables PATH: std_service_path_env
  end

  def caveats
    <<~EOS
      arqtos-core is the line-5 runtime. It does not replace arqtos-cli.

      Legacy-to-line-5 transition (explicit; install does not do this):

        brew services stop arqtos-cli
        # stop a leftover arqtosd if it is still running
        brew services start arqtos-core

      Never run arqtosd and arqtos-reconciler against one state root.
      Two writers on one state root is an incompatible state: stop the
      legacy daemon before starting the line-5 reconciler.

      A failed upgrade: revert the formula (version and sha256) to the last
      good release; never delete the tag.

      Content pins (the adopted Seed pin) are not changed by brew upgrade.

        brew services start arqtos-core

      starts the reconciler only. Gateway, broker and connectors are
      socket-activated from the plists in #{opt_pkgshare}/launchd;
      loading them is a separate launchctl step, not part of install.
    EOS
  end

  test do
    %w[arqtos arqtos-broker arqtos-connectors arqtos-gateway arqtos-reconciler].each do |name|
      assert_predicate bin/name, :exist?
      assert_predicate bin/name, :executable?
      output = shell_output("#{bin}/#{name} version")
      assert_match name, output
    end
    help = shell_output("#{bin}/arqtos --help")
    assert_match "arqtos", help
  end

  def reconciler_plist
    <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>io.arqtos.reconciler</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{opt_bin}/arqtos-reconciler</string>
          <string>--resident</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <true/>
        <key>ThrottleInterval</key>
        <integer>10</integer>
      </dict>
      </plist>
    EOS
  end

  def socket_plist(member, runtime)
    sock = runtime/"#{member}.sock"
    <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>io.arqtos.#{member}</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{opt_bin}/arqtos-#{member}</string>
          <string>--socket=#{sock}</string>
        </array>
        <key>ThrottleInterval</key>
        <integer>10</integer>
        <key>inetdCompatibility</key>
        <dict>
          <key>Wait</key>
          <true/>
        </dict>
        <key>Sockets</key>
        <dict>
          <key>Listeners</key>
          <dict>
            <key>SockPathName</key>
            <string>#{sock}</string>
            <key>SockPathMode</key>
            <integer>384</integer>
          </dict>
        </dict>
      </dict>
      </plist>
    EOS
  end
end
