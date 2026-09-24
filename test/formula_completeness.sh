#!/bin/sh
# Formula completeness for arqtos-core (homebrew-arqtos#30).
set -e
root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
core="$root/Formula/arqtos-core.rb"
cli="$root/Formula/arqtos-cli.rb"

test -f "$core"
test -f "$cli"

for name in arqtos arqtos-broker arqtos-connectors arqtos-gateway arqtos-reconciler; do
  grep -q "\"$name\"" "$core" || { echo "arqtos-core missing quoted $name"; exit 1; }
done

grep -q 'bin.install "arqtos", "arqtosd"' "$cli" || { echo "arqtos-cli was rewritten"; exit 1; }
grep -q arqtos-broker "$cli" && { echo "arqtos-cli now installs line-5 binaries"; exit 1; }

grep -q 'service do' "$core" && { echo "arqtos-core must not register a brew service"; exit 1; }
grep -q 'brew services .*arqtos-core' "$core" && { echo "brew services must not use arqtos-core"; exit 1; }
grep -q 'brew services start arqtos-cli' "$core" || { echo "brew services start must use arqtos-cli"; exit 1; }
grep -q 'brew services stop arqtos-cli' "$core" || { echo "brew services stop must use arqtos-cli"; exit 1; }
grep -q 'brew services restart arqtos-cli' "$core" || { echo "brew services restart must use arqtos-cli"; exit 1; }
grep -q 'service do' "$cli" || { echo "arqtos-cli must keep the brew service"; exit 1; }
if grep -E 'system .*services|system .*launchctl' "$core"; then
  echo "install must not start services"
  exit 1
fi
grep -q '~/.arqtos' "$core" && { echo "formula rewrites user configuration"; exit 1; }
grep -q 'io.arqtos.reconciler' "$core" || { echo "missing reconciler service asset"; exit 1; }
grep -q 'SockPathMode' "$core" || { echo "missing socket ownership"; exit 1; }

echo "ok"
