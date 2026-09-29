#!/bin/sh
# Formula completeness for Line-5 arqtos-cli (homebrew-arqtos#38).
set -e
root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cli="$root/Formula/arqtos-cli.rb"
core="$root/Formula/arqtos-core.rb"
sums="$root/test/v0.5.1.checksums.txt"

fail() { echo "$*"; exit 1; }

test -f "$cli" || fail "arqtos-cli formula missing"

# Mutation: a formula that still installs arqtosd fails five-now completeness.
grep -q 'bin.install "arqtos", "arqtosd"' "$cli" && fail "arqtos-cli still installs arqtosd"

grep -q 'version "0.5.1"' "$cli" || fail "arqtos-cli version is not 0.5.1"

grep -q 'bin.install "arqtos", "arqtos-broker", "arqtos-connectors", "arqtos-gateway", "arqtos-reconciler"' "$cli" \
  || fail "arqtos-cli missing five line-5 binaries"

# Four published sums, compared by filename, not by eye.
test -f "$sums" || fail "missing published checksums fixture"
for name in arqtos_0.5.1_darwin_arm64.tar.gz arqtos_0.5.1_darwin_amd64.tar.gz \
            arqtos_0.5.1_linux_arm64.tar.gz arqtos_0.5.1_linux_amd64.tar.gz; do
  want="$(awk -v n="$name" '$2==n {print $1}' "$sums")"
  test -n "$want" || fail "checksums fixture missing $name"
  grep -q "$want" "$cli" || fail "arqtos-cli sha256 for $name does not match checksums.txt"
done

# brew services stays the arqtos-cli token and starts the Line-5 reconciler
# with resolved journal/repository/intake. Bare --resident is insufficient.
grep -q 'service do' "$cli" || fail "arqtos-cli must keep the brew service"
grep -q 'arqtos-reconciler' "$cli" || fail "brew services must start arqtos-reconciler"
grep -q -- '--journal=' "$cli" || fail "reconciler missing --journal="
grep -q -- '--repo=' "$cli" || fail "reconciler missing --repo="
grep -q -- '--intake=' "$cli" || fail "reconciler missing --intake="
if grep -q -- '--resident' "$cli" && ! grep -q -- '--journal=' "$cli"; then
  fail "bare --resident is insufficient"
fi
grep -q 'brew services .*arqtos-core' "$cli" && fail "brew services must not use arqtos-core"

# Socket-activated members: macOS launchd and Linux systemd, separately.
grep -q 'OS.mac?' "$cli" || fail "missing macOS unit path"
grep -q 'OS.linux?' "$cli" || fail "missing Linux unit path"
grep -q 'SockPathMode' "$cli" || fail "missing macOS socket ownership"
grep -q 'ListenStream=' "$cli" || fail "missing Linux socket unit"
grep -q 'SocketMode=0600' "$cli" || fail "missing Linux socket mode"
grep -q 'pkgshare/"launchd"' "$cli" || fail "missing macOS launchd pkgshare"
grep -q 'pkgshare/"systemd"' "$cli" || fail "missing Linux systemd pkgshare"
grep -A8 'elsif OS.linux?' "$cli" | grep -q plist && fail "Linux path installs macOS plists"

# Formula/arqtos-core.rb is not a formula users can brew install.
if test -f "$core"; then
  grep -q 'disable!' "$core" || fail "arqtos-core.rb is still brew-installable"
  grep -q 'bin.install' "$core" && fail "disabled arqtos-core.rb still installs binaries"
  grep -q 'service do' "$core" && fail "arqtos-core must not register a brew service"
fi

grep -q '~/.arqtos' "$cli" && fail "formula rewrites user configuration"
if grep -E 'system .*services|system .*launchctl' "$cli"; then
  fail "install must not start services"
fi

echo "ok"
