#!/bin/sh
# Isolated formula service lifecycle against the Core layout state root
# (homebrew-arqtos#51). Does not brew on the operator floe.
set -eu
root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cli="$root/Formula/arqtos-cli.rb"
fail() { echo "$*"; exit 1; }

test -f "$cli" || fail "arqtos-cli formula missing"
grep -q 'service do' "$cli" || fail "formula missing service do"

block="$(awk '/service do/,/^  end$/' "$cli")"
echo "$block" | grep -q 'arqtos-reconciler' || fail "service do does not run arqtos-reconciler"
echo "$block" | grep -q -- '--resident' || fail "service do missing --resident"
echo "$block" | grep -q -- '--journal=' || fail "service do missing --journal"
echo "$block" | grep -q -- '--repo=' || fail "service do missing --repo"
echo "$block" | grep -q -- '--intake=' || fail "service do missing --intake"
echo "$block" | grep -q '.arqtos/state' || fail "service do does not use layout.Journal"
if echo "$block" | grep -q 'var}/arqtos'; then
  fail "service do still uses Homebrew var/arqtos"
fi
if echo "$block" | grep -E 'arqtos-gateway|arqtos-broker|arqtos-connectors'; then
  fail "service do started a socket-activated peer"
fi
if echo "$block" | grep -q -- '--socket='; then
  fail "reconciler service is socket-activated"
fi

fix="$(mktemp -d)"
trap 'rm -rf "$fix"' EXIT
home="$fix/home"
state="$home/.arqtos/state"
mkdir -p "$state/canonical" "$state/intake" "$home/.arqtos/orgs/acme" "$home/Arqtos/notes" "$fix/bin"
printf 'kind: enrol\n' >"$home/.arqtos/orgs/acme/enrol.yaml"
printf 'seal\n' >"$home/.arqtos/bootstrap.sealed"
printf 'dirty\n' >"$home/Arqtos/notes/wip.md"

cat >"$fix/bin/arqtos-reconciler" <<'STUB'
#!/bin/sh
receipt="${ARQTOS_QUALIFY_RECEIPT:-}"
printf '%s\n' "$0 $*" >>"$receipt"
printf 'ready\n'
trap 'printf stop\n >>"$receipt"; exit 0' TERM INT
while :; do
  sleep 0.05
done
STUB
chmod +x "$fix/bin/arqtos-reconciler"

receipt="$fix/receipt"
: >"$receipt"
journal="$state/reconciler.db"
repo="$state/canonical"
intake="$state/intake"
export ARQTOS_QUALIFY_RECEIPT="$receipt"
"$fix/bin/arqtos-reconciler" --resident --journal="$journal" --repo="$repo" --intake="$intake" >/dev/null 2>&1 &
pid=$!
sleep 0.1
kill -0 "$pid" || fail "isolated service start did not keep the reconciler resident"
kill -TERM "$pid"
wait "$pid" || true
"$fix/bin/arqtos-reconciler" --resident --journal="$journal" --repo="$repo" --intake="$intake" >/dev/null 2>&1 &
pid=$!
sleep 0.1
kill -TERM "$pid"
wait "$pid" || true

grep -q -- '--resident' "$receipt" || fail "lifecycle did not pass --resident"
grep -q -- "--journal=$journal" "$receipt" || fail "lifecycle did not pass layout journal"
grep -q -- "--repo=$repo" "$receipt" || fail "lifecycle did not pass layout repo"
grep -q -- "--intake=$intake" "$receipt" || fail "lifecycle did not pass layout intake"
starts="$(grep -c -- '--resident' "$receipt")"
test "$starts" -ge 2 || fail "restart did not start the reconciler again"
grep -q stop "$receipt" || fail "stop did not unload the reconciler"
test "$(cat "$home/.arqtos/orgs/acme/enrol.yaml")" = "kind: enrol" || fail "lifecycle rewrote authored config"
test -f "$home/.arqtos/bootstrap.sealed" || fail "lifecycle destroyed secret custody"
test "$(cat "$home/Arqtos/notes/wip.md")" = "dirty" || fail "lifecycle destroyed dirty authored state"
test -d "$fix/prefix/var/arqtos" && fail "lifecycle created a Homebrew-specific journal"
if grep -q var/arqtos "$receipt"; then
  fail "lifecycle pointed the writer at Homebrew var/arqtos"
fi

echo "ok"
