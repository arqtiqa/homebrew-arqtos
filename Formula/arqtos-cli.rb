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
  version "0.5.3"

  if OS.mac?
    if Hardware::CPU.arm?
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_darwin_arm64.tar.gz"
      sha256 "78a903c2808ac091005a4de4d9ccb1ef25871c01f2eab2f18449496f97585d44"
    else
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_darwin_amd64.tar.gz"
      sha256 "fbb9353dd0a5d5f78f9a17acff7a17d77df029a2bfa2df48e0cda3007019f089"
    end
  elsif OS.linux?
    if Hardware::CPU.arm?
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_linux_arm64.tar.gz"
      sha256 "6596a19b59de642504595d258b4e54e82442f020790032ac5c87c824d7cb98ba"
    else
      url "https://github.com/arqtiqa/homebrew-arqtos/releases/download/v#{version}/arqtos_#{version}_linux_amd64.tar.gz"
      sha256 "740632699cf758c70dc6f128340248b8052d9cdc93f004d632fb3275cdb90ba3"
    end
  end

  def install
    bin.install "arqtos", "arqtos-broker", "arqtos-connectors", "arqtos-gateway", "arqtos-reconciler"
    provider = "libexec/onepassword"
    libexec.install provider if File.exist?(provider)
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
      services, and are not started by install. The sequence is
      install, then enrol, then activate:

        brew install arqtos-cli
        arqtos init --machine <id> --principal <id>
        arqtos org join --home <control-repo> --inventory <file> --bootstrap=prompt
        arqtos launch install
        brew services start arqtos-cli

      arqtos launch install writes user launchd/systemd units from the
      enrolled launch plan (nonsecret flags only). Zero-org omits
      broker and connectors so they cannot retry before enrol.
      brew services start|stop|restart arqtos-cli is the reconciler.
      After launch install, load socket units with launchctl (macOS)
      or systemctl --user (Linux). Do not load io.arqtos.reconciler
      and the brew service against one state root.

      Packaged #{opt_pkgshare}/launchd and #{opt_pkgshare}/systemd
      templates stay socket-only placeholders; they cannot bake an
      org because brew install precedes enrolment.

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
    if (libexec/"onepassword").exist?
      assert_predicate libexec/"onepassword", :executable?
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
