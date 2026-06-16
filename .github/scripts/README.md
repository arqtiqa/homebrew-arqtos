# Vendored scripts

These scripts are vendored from `arqtiqa/arqtos` to enable per-repo CI
(GitHub Actions can't checkout other private repos with default
GITHUB_TOKEN; vendoring sidesteps the cross-repo permission problem).

| File | Canonical source |
|---|---|
| `check-private-content.sh` | `arqtiqa/arqtos:scripts/check-private-content.sh` (verbatim) |
| `private-content-denylist.txt` | `arqtiqa/arqtos:scripts/private-content-denylist.txt` (**public-safe subset**) |

**`check-private-content.sh`** tracks the canonical source verbatim — when the
canonical script changes, update this copy.

**`private-content-denylist.txt` is intentionally NOT verbatim.** This repo is
public, so the denylist here is a deliberate subset: it keeps only the generic
secret / private-network patterns and OMITS the canonical denylist's
identifier patterns (operator real name, personal email, affiliated org
domains, hostname scheme). Committing those literal patterns to a public repo
would itself leak the identifiers they guard. The omitted patterns remain
enforced on the private `arqtiqa/*` repos by the canonical denylist; do **not**
sync them down into this public copy.
