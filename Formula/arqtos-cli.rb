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
  version "0.5.6"

  if OS.mac?
    if Hardware::CPU.arm?
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_darwin_arm64.tar.gz"
      sha256 "bcca2ce9a746abc4b1dd92e2e6b82902f6be2cc07c3dbabfe4dd57db598b8b9d"
    else
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_darwin_amd64.tar.gz"
      sha256 "8880bbfed36b9393303147b32e206cc76f3d8e4fd40fb5802b5990c1ee64a287"
    end
  elsif OS.linux?
    if Hardware::CPU.arm?
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_linux_arm64.tar.gz"
      sha256 "02688bcaf7ba611a5bebf46496537d5325f291ea91859b089ffc002be5f656fb"
    else
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_linux_amd64.tar.gz"
      sha256 "ef372f907b48c0aa9b137a2fd02900d8d4b44d791bb6cce12c7625eab19cf453"
    end
  end

  def install
    bin.install "arqtos", "arqtos-broker", "arqtos-connectors", "arqtos-gateway", "arqtos-reconciler"
    provider = "libexec/onepassword"
    File.exist?(provider) || raise("advertised credential provider #{provider} is missing from the archive")
    libexec.install provider
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
      "--journal=#{Dir.home}/.arqtos/state/reconciler.db",
      "--repo=#{Dir.home}/.arqtos/state/canonical",
      "--intake=#{Dir.home}/.arqtos/state/intake",
    ]
    keep_alive true
    run_at_load true
    working_dir "#{Dir.home}/.arqtos/state"
  end

  def caveats
    <<~EOS
      Line-5 ships through arqtos-cli. Do not brew install arqtos-core.

      brew services start/stop/restart arqtos-cli owns the reconciler.
      Journal, repository and intake are ~/.arqtos/state (layout.Journal),
      the same paths doctor and launch plan probe. arqtos launch activate
      owns the socket-activated peers (gateway, broker, connectors).

      Never run arqtosd and arqtos-reconciler against one state root.
      Never load io.arqtos.reconciler and a brew service against one
      state root.

      Install does not start services. The sequence is install, enrol,
      then start the reconciler and the socket peers:

        brew install arqtos-cli
        arqtos init --machine <id> --principal <id>
        arqtos org join --home <control-repo> --inventory <file> --bootstrap=prompt
        brew services start arqtos-cli
        arqtos launch install
        arqtos launch activate

      Restart the reconciler with brew services restart arqtos-cli.
      Stop it with brew services stop arqtos-cli. Socket peers restart
      with arqtos launch activate and stop with arqtos launch stop.
      arqtos doctor reports initialized through runtime-ready against
      ~/.arqtos/state. Do not edit launchd plists by hand.

      Packaged #{opt_pkgshare}/launchd and #{opt_pkgshare}/systemd
      templates stay socket-only placeholders; they cannot bake an
      org because brew install precedes enrolment. Do not load them
      in place of launch install.

      The credential provider is installed at #{opt_libexec}/onepassword
      and is not a public command. Normal onboarding does not require
      setting ARQTOS_CREDENTIAL_CONNECTOR; that variable remains an
      explicit override. A missing or incompatible provider fails closed.

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
    refute_predicate bin/"onepassword", :exist?
    assert_predicate libexec/"onepassword", :exist?
    assert_predicate libexec/"onepassword", :executable?

    if OS.mac?
      require "open3"
      require "timeout"
      env = ENV.to_h.reject { |k, _| k.match?(/TOKEN|SECRET|VAULT/i) || k.include?("CREDENTIAL_CONNECTOR") }
      out = ""
      begin
        Timeout.timeout(5) do
          o, e, = Open3.capture3(env, (libexec/"onepassword").to_s)
          out = "#{o}#{e}"
        end
      rescue Timeout::Error
        flunk "credential provider handshake timed out"
      end
      refute_match(/service_account|gho_|github_pat_/i, out)
      if out.match?(/--socket/i) && out.match?(/--config/i)
        flunk "socket/config host cannot pass as the credential-provider plugin"
      end
      unless out.match?(/plugin|handshake|protocol/i)
        flunk "incompatible handshake"
      end
    elsif !OS.linux?
      omit "native provider handshake and seal recovery are Darwin-qualified"
    end

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
