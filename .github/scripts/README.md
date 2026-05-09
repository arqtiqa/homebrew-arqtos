# Vendored scripts

These scripts are vendored from `arqtiqa/arqtos` to enable per-repo CI
(GitHub Actions can't checkout other private repos with default
GITHUB_TOKEN; vendoring sidesteps the cross-repo permission problem).

| File | Canonical source |
|---|---|
| `check-private-content.sh` | `arqtiqa/arqtos:scripts/check-private-content.sh` |
| `private-content-denylist.txt` | `arqtiqa/arqtos:scripts/private-content-denylist.txt` |

**Sync expectation:** when the canonical source changes (firewall
patterns), update each vendored copy. Drift surfaces through divergent
CI behaviour; periodic audit lives in Phase 6 of the arqtos-full
refactor.
