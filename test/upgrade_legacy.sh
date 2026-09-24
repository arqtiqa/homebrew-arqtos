#!/bin/sh
# Homebrew upgrade and legacy-runtime replacement (homebrew-arqtos#31).
set -eu
root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
core="$root/Formula/arqtos-core.rb"
cli="$root/Formula/arqtos-cli.rb"
fail() { echo "$*"; exit 1; }

test -f "$core" && test -f "$cli" || fail "both formulas must exist"

# Clean install: line-5 formula is additive; line-4 stays.
grep -q 'bin.install "arqtos", "arqtos-broker"' "$core" \
  || grep -q 'bin.install "arqtos", "arqtos-broker", "arqtos-connectors", "arqtos-gateway", "arqtos-reconciler"' "$core" \
  || fail "clean install missing five line-5 binaries"
grep -q 'bin.install "arqtos", "arqtosd"' "$cli" || fail "legacy formula rewritten"
grep -q arqtos-broker "$cli" && fail "legacy formula now ships line-5 binaries"

# Supported upgrade does not rewrite user config or worktrees.
grep -q '~/.arqtos' "$core" && fail "arqtos-core install rewrites user configuration"
grep -q 'worktree' "$core" && fail "arqtos-core install touches worktrees"
if grep -E 'system .*services|system .*launchctl' "$core"; then
  fail "upgrade must not start services in the install hook"
fi

# Legacy-to-line-5 transition is explicit: stop arqtosd, never two writers.
grep -q 'arqtosd' "$core" || fail "missing legacy daemon stop procedure"
grep -q 'brew services stop arqtos-cli' "$core" || fail "missing brew services stop arqtos-cli"
grep -q 'brew services start arqtos-cli' "$core" || fail "missing brew services start arqtos-cli"
grep -q 'brew services restart arqtos-cli' "$core" || fail "missing brew services restart arqtos-cli"
grep -q 'brew services .*arqtos-core' "$core" && fail "brew services must not use arqtos-core"
grep -q 'service do' "$core" && fail "arqtos-core must not register a brew service"
grep -q 'state root' "$core" || fail "missing two-writers/state-root warning"

# Failed upgrade recovery: revert the formula, never the tag.
grep -q 'revert the formula' "$core" || fail "missing formula-revert recovery"
grep -q 'never' "$core" && grep -q 'tag' "$core" || fail "missing never-delete-the-tag recovery"

# Content pins are not a brew-upgrade side effect.
grep -q 'content pin' "$core" || grep -q 'Seed pin' "$core" || fail "missing content-pin independence"

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
grep -q 'version "' "$core" || fail "formula version (the tag stand-in) was deleted"

echo "ok"
