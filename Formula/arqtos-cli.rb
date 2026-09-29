# typed: false
# frozen_string_literal: true

# Homebrew formula for the arqtos toolkit binary.
#
# arqtos is closed-source: compiled binaries are published as public
# release assets on this tap (arqtiqa/homebrew-arqtos). `brew install
# arqtos-cli` requires no GitHub token. The binary is inert without an
# arqtos environment (config + bergs); config and secrets are never
# distributed here.
#
# Install:
#   brew tap arqtiqa/arqtos
#   brew install arqtos-cli
#
# The formula token is arqtos-cli (renamed from arqtos at 0.3.58;
# formula_renames.json is permanent). From 0.5.0 it ships the Line-5
# runtime (arqtos-core). The installed CLI name stays arqtos. The bare
# token arqtos is reserved for the macOS app cask (doc-arq-00093).
# Operator ruling 2026-09-24: do not brew install arqtos-core.

class ArqtosCli < Formula
  desc "Operating layer for specialised professional teams"
  homepage "https://arqtos.io"
  version "0.5.1"

  if OS.mac?
    if Hardware::CPU.arm?
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_darwin_arm64.tar.gz"
      sha256 "babb34c9ffb57c8c8e07e8d67a7fd6a0c3ae479a8d0457d362a282a659d7dad3"
    else
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_darwin_amd64.tar.gz"
      sha256 "eed94d51de50230eae6a547a221dbbef80bedaab87242aa5890848525aa53bb6"
    end
  elsif OS.linux?
    if Hardware::CPU.arm?
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_linux_arm64.tar.gz"
      sha256 "0730ff17660c4ba583d75e940cadaee69ad10d45cd83ad76cd46b4ed3be78b8c"
    else
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_linux_amd64.tar.gz"
      sha256 "cf688c231468594d808a92bbe3967406edd75fff88d0bed305c1b4d7271ff321"
    end
  end

  def install
    bin.install "arqtos", "arqtos-broker", "arqtos-connectors", "arqtos-gateway", "arqtos-reconciler"
    state = var/"arqtos"
    (state/"intake").mkpath
    canonical = state/"canonical"
    canonical.mkpath
    system "git", "-C", canonical, "init", "--quiet" unless (canonical/".git").exist?
    runtime = var/"run"
    if OS.mac?
      (pkgshare/"launchd").mkpath
      %w[gateway broker connectors].each do |member|
        (pkgshare/"launchd/io.arqtos.#{member}.plist").write socket_plist(member, runtime)
      end
    elsif OS.linux?
      (pkgshare/"systemd").mkpath
      %w[gateway broker connectors].each do |member|
        (pkgshare/"systemd/arqtos-#{member}.socket").write systemd_socket(member, runtime)
        (pkgshare/"systemd/arqtos-#{member}.service").write systemd_socket_service(member)
      end
    end
  end

  service do
    run [
      opt_bin/"arqtos-reconciler",
      "--resident",
      "--journal=#{var}/arqtos/reconciler.db",
      "--repo=#{var}/arqtos/canonical",
      "--intake=#{var}/arqtos/intake",
    ]
    keep_alive true
    run_at_load true
    working_dir var/"arqtos"
    log_path var/"log/arqtos-reconciler.log"
    error_log_path var/"log/arqtos-reconciler.log"
  end

  def caveats
    <<~EOS
      Line-5 ships through arqtos-cli. Do not brew install arqtos-core.

      brew services always uses the arqtos-cli token:

        brew services stop arqtos-cli
        brew services start arqtos-cli
        brew services restart arqtos-cli

      That service starts arqtos-reconciler with journal, repository and
      intake under #{var}/arqtos. Readiness is the process printing
      "ready" on stdout (captured in the service log). Bare --resident
      is not a complete argv.

      Stop leftover arqtosd with brew services stop arqtos-cli before
      two writers share one state root. Never run arqtosd and
      arqtos-reconciler against one state root.

      Gateway, broker and connectors are socket-activated, not brew
      services, and are not started by install:
        macOS: #{opt_pkgshare}/launchd (launchctl)
        Linux: #{opt_pkgshare}/systemd (systemd --user)

      A failed upgrade: revert the formula (version and sha256) to the
      last good release; never delete the tag.

      Content pins (the adopted Seed pin) are not changed by brew upgrade.
    EOS
  end

  test do
    %w[arqtos arqtos-broker arqtos-connectors arqtos-gateway arqtos-reconciler].each do |name|
      assert_predicate bin/name, :exist?
      assert_predicate bin/name, :executable?
    end
    refute_predicate bin/"arqtosd", :exist?

    output = shell_output("#{bin}/arqtos version")
    assert_match "arqtos v#{version}", output

    help = shell_output("#{bin}/arqtos --help")
    assert_match "focus", help
    assert_match "org join", help
    assert_match "doctor", help
    refute_match "install-terminal-profiles", help

    focus_help = shell_output("#{bin}/arqtos focus --help")
    assert_match "--json", focus_help
    refute_match "--dry-run", focus_help

    # Fail-closed without a focused org: exit 7, not a silent skip.
    assert_match "precondition", shell_output("#{bin}/arqtos org join --json 2>&1", 7)

    rec = shell_output("#{bin}/arqtos-reconciler 2>&1")
    assert_match "--journal=<path> --repo=<dir> --intake=<dir>", rec
  end

  def systemd_socket(member, runtime)
    sock = runtime/"arqtos/#{member}.sock"
    <<~EOS
      [Socket]
      ListenStream=#{sock}
      SocketMode=0600
      DirectoryMode=0700
      Accept=no

      [Install]
      WantedBy=sockets.target
    EOS
  end

  def systemd_socket_service(member)
    <<~EOS
      [Unit]
      Description=arqtos #{member}

      [Service]
      Type=simple
      ExecStart=#{opt_bin}/arqtos-#{member} --socket=#{var}/run/arqtos/#{member}.sock
      Restart=on-failure
      RestartSec=10
      MemoryMax=256M
    EOS
  end

  def socket_plist(member, runtime)
    sock = runtime/"arqtos/#{member}.sock"
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
