#!/bin/sh
# Homebrew upgrade and legacy-runtime replacement (homebrew-arqtos#35).
set -eu
root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cli="$root/Formula/arqtos-cli.rb"
core="$root/Formula/arqtos-core.rb"
fail() { echo "$*"; exit 1; }

test -f "$cli" || fail "arqtos-cli formula must exist"

# Clean install: Line-5 ships through arqtos-cli, not a second token.
grep -q 'bin.install "arqtos", "arqtos-broker", "arqtos-connectors", "arqtos-gateway", "arqtos-reconciler"' "$cli" \
  || fail "clean install missing five line-5 binaries"
grep -q 'bin.install "arqtos", "arqtosd"' "$cli" && fail "legacy arqtosd install still present"

# arqtos-core is not a user-facing brew token.
if test -f "$core"; then
  grep -q 'disable!' "$core" || fail "arqtos-core.rb is still brew-installable"
  grep -q 'bin.install' "$core" && fail "transitional arqtos-core still installs binaries"
fi

# Supported upgrade does not rewrite user config or worktrees.
if grep -E 'mkpath|mkdir|system "git"' "$cli" | grep -q 'arqtos'; then
  fail "arqtos-cli install writes an arqtos state tree"
fi
if grep -E 'system .*services|system .*launchctl' "$cli"; then
  fail "upgrade must not start services in the install hook"
fi

# Legacy-to-line-5: brew services owns the reconciler; launch activate owns sockets.
grep -q 'brew services stop arqtos-cli' "$cli" || fail "missing brew services stop arqtos-cli"
grep -q 'arqtos launch activate' "$cli" || fail "missing launch activate supervisor"
grep -q 'brew services .*arqtos-core' "$cli" && fail "brew services must not use arqtos-core"
if ! grep -q 'service do' "$cli"; then
  fail "arqtos-cli missing brew service for the reconciler"
fi
grep -q 'state root' "$cli" || fail "missing two-writers/state-root warning"

# Failed upgrade recovery: revert the formula, never the tag.
grep -q 'revert the formula' "$cli" || fail "missing formula-revert recovery"
grep -q 'never' "$cli" && grep -q 'tag' "$cli" || fail "missing never-delete-the-tag recovery"

# Content pins are not a brew-upgrade side effect.
grep -q 'content pin' "$cli" || grep -q 'Seed pin' "$cli" || fail "missing content-pin independence"

# Disposable fixture: two writers on one state root are refused; pins and trees survive.
fix="$(mktemp -d)"
trap 'rm -rf "$fix"' EXIT
state="$fix/state"
mkdir -p "$state/worktree" "$state/.arqtos"
printf 'seed-abc\n' >"$state/.arqtos/accepted.json"
printf 'dirty\n' >"$state/worktree/notes.md"
printf '111\n' >"$state/arqtosd.pid"
printf '222\n' >"$state/arqtos-reconciler.pid"

two_writers() {
  if test -f "$1/arqtosd.pid" && test -f "$1/arqtos-reconciler.pid"; then
    echo "conflicting legacy daemon and line-5 reconciler on $1" >&2
    return 1
  fi
  return 0
}
two_writers "$state" >/dev/null 2>&1 && fail "two writers on one state root were accepted"

# Recovery path: drop the new writer, keep pin and worktree, leave the tag.
rm -f "$state/arqtos-reconciler.pid"
two_writers "$state" || fail "legacy-only daemon should be a single writer"
test "$(cat "$state/.arqtos/accepted.json")" = "seed-abc" || fail "recovery moved the Seed pin"
test -f "$state/worktree/notes.md" || fail "recovery destroyed a dirty worktree"
grep -q 'version "' "$cli" || fail "formula version (the tag stand-in) was deleted"

# Transitional arqtos-core install is refused without destroying user data.
test -f "$state/.arqtos/accepted.json" || fail "transitional cleanup destroyed user data"

echo "ok"
