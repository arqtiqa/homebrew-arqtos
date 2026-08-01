# Denylist for the private-content firewall

This directory holds **only the denylist**. The scanning logic is no longer vendored here — the workflow calls a shared composite action, so there is one copy of the logic instead of one per repository.

## ⚠️ The denylist stays here on purpose

Sharing the *logic* is safe. Sharing the *data* is not, and centralising it would be actively wrong: it would force the union of every repository's list, and a denylist is a list of the things it protects. So the logic is shared and each repository keeps its own list, scoped to who can read that repository.

**This repository is public.** Its list therefore holds only generic secret-shape and private-network patterns — a token format, an address range, and the like.

⚠️ **It deliberately omits patterns that would identify a person, a machine, or an organisation.** Committing such a pattern here would publish the very identifier it exists to guard, because the pattern *is* a description of the thing. Those remain enforced where the audience already knows them.

**So: do not sync patterns down into this file to "keep it in step".** The difference is the design.

| change | belongs here? |
|---|---|
| a new secret-shape pattern (a service's token format) | ✅ yes — those are generic and belong everywhere |
| anything naming or describing a person, host, or organisation | ❌ **no** |

## Exit codes

The scan distinguishes three outcomes, and the third is the one that matters:

| exit | meaning |
|---|---|
| `0` | clean |
| `1` | a pattern matched (`file:line` on stderr) |
| **`2`** | **misconfiguration — a missing denylist among them** |

⚠️ A missing denylist must **never** read as clean: a scan with nothing to scan against passes every file, which looks like a pass and is worse than not running.
