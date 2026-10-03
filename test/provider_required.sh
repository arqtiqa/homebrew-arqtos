#!/bin/sh
# Isolated candidate formula tests for advertised auxiliary providers
# (homebrew-arqtos#47). Does not brew on the operator floe.
set -eu
root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cli="$root/Formula/arqtos-cli.rb"
inv="$root/test/provider_inventory.yaml"
fail() { echo "$*"; exit 1; }

test -f "$cli" || fail "arqtos-cli formula missing"

# Named gap: an archive missing libexec/onepassword must fail install/test.
if grep -q 'if File.exist?(provider)' "$cli" || grep -q 'libexec.install provider if File.exist?' "$cli"; then
  fail "formula silently skips a missing advertised provider"
fi
if grep -q 'if (libexec/"onepassword").exist?' "$cli"; then
  fail "formula test treats a missing provider as passing"
fi

# Advertised inventory for the candidate, pinned by archive SHA.
test -f "$inv" || fail "missing advertised provider inventory"
grep -q 'libexec/onepassword' "$inv" || fail "inventory does not advertise libexec/onepassword"
grep -q '0.5.5' "$inv" || fail "inventory is not pinned to candidate 0.5.5"
grep -q 'darwin' "$inv" || fail "inventory missing darwin candidate"
grep -q 'linux' "$inv" || fail "inventory missing linux candidate"
grep -q 'v0.5.5.checksums.txt' "$inv" || fail "inventory does not pin archive checksums"
grep -q 'version "0.5.5"' "$cli" || fail "formula version pin for #732 is not 0.5.5"
test -f "$root/test/v0.5.5.checksums.txt" || fail "missing v0.5.5 checksum pin for #732"

# Install requires the advertised path; discovery is libexec, not an env workaround.
grep -q 'libexec.install provider' "$cli" || grep -q 'libexec.install "libexec/onepassword"' "$cli" \
  || fail "formula does not install the advertised provider under libexec"
awk '/def install/,/^  def /' "$cli" | grep -q 'ARQTOS_CREDENTIAL_CONNECTOR' \
  && fail "install requires ARQTOS_CREDENTIAL_CONNECTOR in the normal journey"
grep -q 'ARQTOS_CREDENTIAL_CONNECTOR' "$cli" || fail "caveats must keep ARQTOS_CREDENTIAL_CONNECTOR as an override"
grep -q 'does not require' "$cli" || fail "caveats must say normal onboarding does not require the override"

# Formula test exercises handshake and Darwin seal recovery; other profiles omit.
grep -q 'handshake' "$cli" || fail "formula test missing provider handshake"
grep -q 'omit' "$cli" || fail "unavailable profiles must be omitted, not marked passing"
grep -q 'seal' "$cli" || fail "formula test missing native seal recovery"

# No token acquisition during package build/test metadata checks.
for secret in OP_SERVICE_ACCOUNT_TOKEN GH_TOKEN GIT_ VAULT_ opsa_; do
  if grep -q "$secret" "$cli"; then
    fail "formula contains $secret"
  fi
done

# Provider stays private; source is not exported.
if grep -E 'bin.install .*"onepassword"' "$cli"; then
  fail "formula publishes onepassword as a public command"
fi
grep -q 'go.mod' "$cli" && fail "formula exports private source"

# Isolated prefix: missing provider is a named refusal; authored state survives.
fix="$(mktemp -d)"
trap 'rm -rf "$fix"' EXIT
prefix="$fix/prefix"
state="$fix/home/.arqtos"
mkdir -p "$prefix/bin" "$prefix/libexec" "$state/orgs/acme"
printf 'cli\n' >"$prefix/bin/arqtos"
chmod 755 "$prefix/bin/arqtos"
test -f "$prefix/libexec/onepassword" && fail "empty prefix unexpectedly has a provider"
printf 'kind: enrol\n' >"$state/orgs/acme/enrol.yaml"
printf 'seal\n' >"$state/bootstrap.sealed"
test "$(cat "$state/orgs/acme/enrol.yaml")" = "kind: enrol" || fail "upgrade rewrote authored config"
test -f "$state/bootstrap.sealed" || fail "upgrade destroyed secret custody"
printf 'plugin\n' >"$prefix/libexec/onepassword"
chmod 755 "$prefix/libexec/onepassword"
test -f "$prefix/bin/onepassword" && fail "fixture published onepassword as a public command"

echo "ok"
