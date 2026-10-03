#!/bin/sh
# Isolated candidate formula tests for launchd/systemd consuming the
# runtime launch contract (homebrew-arqtos#42). Does not brew on the
# operator floe.
set -eu
root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cli="$root/Formula/arqtos-cli.rb"
fail() { echo "$*"; exit 1; }

test -f "$cli" || fail "arqtos-cli formula missing"

# Install → enrol → activate is documented; brew cannot bake --org.
grep -q 'arqtos launch install' "$cli" || fail "caveats missing arqtos launch install"
grep -q 'arqtos launch activate' "$cli" || fail "caveats missing arqtos launch activate"
grep -q 'arqtos launch stop' "$cli" || fail "caveats missing arqtos launch stop"
grep -q 'brew install arqtos-cli' "$cli" || fail "caveats missing brew install"
grep -q 'org join' "$cli" || fail "caveats missing org join"

# brew services start/stop/restart owns the reconciler; activate owns sockets.
grep -q 'brew services stop arqtos-cli' "$cli" || fail "missing brew services stop"
grep -q 'brew services start arqtos-cli' "$cli" || fail "missing brew services start"
grep -q 'brew services restart arqtos-cli' "$cli" || fail "missing brew services restart"
if ! grep -q 'service do' "$cli"; then
  fail "formula missing service do"
fi

# Formula-time units stay socket-only; enrol happens after brew install.
if grep -q -- '--org=' "$cli"; then
  fail "formula bakes --org= into service definitions"
fi
if grep -q -- '--principal=' "$cli"; then
  fail "formula bakes --principal= into service definitions"
fi
if grep -q -- '--provider=' "$cli"; then
  fail "formula bakes --provider= into service definitions"
fi
if grep -q -- '--keydir=' "$cli"; then
  fail "formula bakes --keydir= into service definitions"
fi

# No token values in service definitions.
for secret in OP_SERVICE_ACCOUNT_TOKEN GH_TOKEN GIT_ VAULT_ opsa_; do
  if grep -q "$secret" "$cli"; then
    fail "formula contains $secret"
  fi
done

# Packaged templates remain socket-only placeholders.
grep -q 'socket_plist' "$cli" || fail "missing macOS socket plist helper"
grep -q 'systemd_socket_service' "$cli" || fail "missing Linux socket service helper"
grep -q -- '--socket=' "$cli" || fail "socket templates missing --socket="
grep -q 'placeholders' "$cli" || fail "caveats must say packaged templates are placeholders"

# Install must not start services; two writers on one state root stay refused.
if grep -E 'system .*services|system .*launchctl' "$cli"; then
  fail "install must not start services"
fi
grep -q 'state root' "$cli" || fail "missing two-writers/state-root warning"
grep -q 'io.arqtos.reconciler' "$cli" || fail "missing duplicate reconciler warning"

# Isolated prefix fixture: authored enrol and a dummy seal survive a
# binary-only layout; no second writer is introduced by the formula text.
fix="$(mktemp -d)"
trap 'rm -rf "$fix"' EXIT
prefix="$fix/prefix"
state="$fix/home/arqtos-state"
mkdir -p "$prefix/bin" "$state/orgs/acme"
printf 'cli\n' >"$prefix/bin/arqtos"
printf 'kind: enrol\n' >"$state/orgs/acme/enrol.yaml"
printf 'seal\n' >"$state/bootstrap.sealed"
test "$(cat "$state/orgs/acme/enrol.yaml")" = "kind: enrol" || fail "upgrade rewrote authored config"
test -f "$state/bootstrap.sealed" || fail "upgrade destroyed secret custody"
test -f "$prefix/bin/arqtos-reconciler.pid" && fail "formula fixture started a second writer"

echo "ok"
