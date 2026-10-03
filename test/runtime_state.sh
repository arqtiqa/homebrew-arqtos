#!/bin/sh
# Isolated candidate formula tests for one runtime-state contract and
# one supervisor owner (homebrew-arqtos#46). Does not brew on the
# operator floe.
set -eu
root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cli="$root/Formula/arqtos-cli.rb"
fail() { echo "$*"; exit 1; }

test -f "$cli" || fail "arqtos-cli formula missing"

# Homebrew var/arqtos is not the launch/doctor journal.
if grep -q 'var}/arqtos/reconciler.db' "$cli" || grep -q 'var/"arqtos"' "$cli"; then
  fail "formula uses a Homebrew-specific journal instead of layout state"
fi

# brew services owns the reconciler on the layout state root; launch activate owns sockets.
grep -q 'arqtos launch activate' "$cli" || fail "caveats missing arqtos launch activate"
grep -q 'arqtos launch stop' "$cli" || fail "caveats missing arqtos launch stop"
grep -q 'arqtos launch install' "$cli" || fail "caveats missing arqtos launch install"
if ! grep -q 'service do' "$cli"; then
  fail "brew services does not own the reconciler"
fi
grep -A25 'service do' "$cli" | grep -q '.arqtos/state' || fail "service do does not use layout state"
if grep -A25 'service do' "$cli" | grep -q 'var}/arqtos'; then
  fail "service do still uses a Homebrew-specific journal"
fi

# Activation sequence uses the installed binary, not a checkout or plist edit.
grep -q 'brew install arqtos-cli' "$cli" || fail "caveats missing brew install"
grep -q 'org join' "$cli" || fail "caveats missing org join"
if grep -q 'manual plist' "$cli"; then
  fail "caveats must not instruct manual plist edits"
fi

# Rollback is formula revert, never tag delete.
grep -q 'revert the formula' "$cli" || fail "missing formula-revert recovery"
grep -q 'never' "$cli" && grep -q 'tag' "$cli" || fail "missing never-delete-the-tag recovery"

# Record the candidate pin used by #732; this Story does not promote a cut.
grep -q 'version "0.5.4"' "$cli" || fail "formula version pin for #732 is not 0.5.4"
test -f "$root/test/v0.5.4.checksums.txt" || fail "missing v0.5.4 checksum pin for #732"

# Isolated prefix: authored enrol, dirty notes and a dummy seal survive a
# binary-only layout; no second writer and no Homebrew journal tree.
fix="$(mktemp -d)"
trap 'rm -rf "$fix"' EXIT
prefix="$fix/prefix"
state="$fix/home/.arqtos"
mkdir -p "$prefix/bin" "$state/orgs/acme" "$state/state" "$fix/home/Arqtos/notes"
printf 'cli\n' >"$prefix/bin/arqtos"
printf 'kind: enrol\n' >"$state/orgs/acme/enrol.yaml"
printf 'seal\n' >"$state/bootstrap.sealed"
printf 'dirty\n' >"$fix/home/Arqtos/notes/wip.md"
printf 'held\n' >"$state/state/reconciler.db.writer"
test "$(cat "$state/orgs/acme/enrol.yaml")" = "kind: enrol" || fail "upgrade rewrote authored config"
test -f "$state/bootstrap.sealed" || fail "upgrade destroyed secret custody"
test "$(cat "$fix/home/Arqtos/notes/wip.md")" = "dirty" || fail "upgrade destroyed dirty authored state"
test -d "$prefix/var/arqtos" && fail "fixture created a Homebrew-specific journal"
test -f "$prefix/bin/arqtos-reconciler.pid" && fail "formula fixture started a second writer"

# Doctor and launch agree on the machine state journal, not var/arqtos.
grep -q '.arqtos/state' "$cli" || fail "caveats do not name the layout journal"
grep -q 'brew services start arqtos-cli' "$cli" || fail "brew services start is not documented as the reconciler owner"

echo "ok"
