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
set +eu
receipt="${ARQTOS_QUALIFY_RECEIPT:-}"
test -n "$receipt" || exit 1
printf '%s\n' "$0 $*" >>"$receipt"
printf 'ready\n'
trap 'printf "%s\n" stop >>"$receipt"; exit 0' TERM INT
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

await_starts() {
  want=$1
  n=0
  while test "$n" -lt 50; do
    have=0
    if test -s "$receipt"; then
      have=$(grep -c -- '--resident' "$receipt" || true)
    fi
    if test "$have" -ge "$want"; then
      return 0
    fi
    sleep 0.05
    n=$((n + 1))
  done
  return 1
}

start_stub() {
  want=$1
  "$fix/bin/arqtos-reconciler" --resident --journal="$journal" --repo="$repo" --intake="$intake" >/dev/null 2>&1 &
  pid=$!
  n=0
  while test "$n" -lt 20; do
    kill -0 "$pid" 2>/dev/null && break
    sleep 0.05
    n=$((n + 1))
  done
  kill -0 "$pid" 2>/dev/null || fail "isolated service start did not keep the reconciler resident"
  await_starts "$want" || fail "isolated service start did not record layout argv"
}

stop_stub() {
  kill -TERM "$pid"
  wait "$pid" 2>/dev/null || true
}

start_stub 1
stop_stub
start_stub 2
stop_stub

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
