#!/bin/sh
# Isolated candidate formula tests for credential-provider install
# (homebrew-arqtos#41). Does not brew on the operator floe.
set -eu
root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cli="$root/Formula/arqtos-cli.rb"
fail() { echo "$*"; exit 1; }

test -f "$cli" || fail "arqtos-cli formula missing"

grep -q 'libexec.install' "$cli" || fail "formula does not install the auxiliary provider under libexec"
grep -q 'onepassword' "$cli" || fail "formula does not name the pinned onepassword provider"

# No public command name for the provider.
if grep -E 'bin.install .*"onepassword"' "$cli"; then
  fail "formula publishes onepassword as a public command"
fi
grep -q 'bin.install "arqtos", "arqtos-broker", "arqtos-connectors", "arqtos-gateway", "arqtos-reconciler"' "$cli" \
  || fail "five public binaries must stay the only bin.install names"

# Discovery contract: onboarding does not require ARQTOS_CREDENTIAL_CONNECTOR;
# documented override remains.
grep -q 'ARQTOS_CREDENTIAL_CONNECTOR' "$cli" || fail "formula must document the explicit override"
grep -q 'libexec' "$cli" || fail "formula must name the libexec discovery location"

# Clean install / binary-only upgrade must not rewrite authored config or custody.
if grep -E 'mkpath|mkdir|system "git"' "$cli" | grep -q 'arqtos'; then
  fail "formula writes an arqtos state tree"
fi
if grep -E 'system .*services|system .*launchctl' "$cli"; then
  fail "install must not start services"
fi

# Isolated prefix: formula-shaped layout, not a developer checkout.
fix="$(mktemp -d)"
trap 'rm -rf "$fix"' EXIT
prefix="$fix/prefix"
mkdir -p "$prefix/bin" "$prefix/libexec"
printf 'cli\n' >"$prefix/bin/arqtos"
printf 'plugin\n' >"$prefix/libexec/onepassword"
chmod 755 "$prefix/bin/arqtos" "$prefix/libexec/onepassword"
test -f "$prefix/bin/onepassword" && fail "fixture published onepassword as a public command"
test -f "$prefix/libexec/onepassword" || fail "fixture missing libexec/onepassword"

# Authored config and a dummy seal survive a binary-only layout swap.
state="$fix/home/.arqtos"
mkdir -p "$state/orgs/acme"
printf 'kind: enrol\n' >"$state/orgs/acme/enrol.yaml"
printf 'seal\n' >"$state/bootstrap.sealed"
printf 'plugin-v2\n' >"$prefix/libexec/onepassword"
test "$(cat "$state/orgs/acme/enrol.yaml")" = "kind: enrol" || fail "upgrade rewrote authored config"
test -f "$state/bootstrap.sealed" || fail "upgrade destroyed secret custody"

# Missing provider is a named refusal, not a silent skip.
if grep -q 'if File.exist?(provider)' "$cli" || grep -q 'libexec.install provider if File.exist?' "$cli"; then
  fail "formula silently skips a missing advertised provider"
fi
missing="$fix/empty"
mkdir -p "$missing/bin" "$missing/libexec"
printf 'cli\n' >"$missing/bin/arqtos"
chmod 755 "$missing/bin/arqtos"
test -f "$missing/libexec/onepassword" && fail "empty prefix unexpectedly has a provider"

echo "ok"
