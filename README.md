# homebrew-arqtos

Homebrew tap for the **arqtos** toolkit — the operating layer for specialised
professional teams. The tap is public and `brew install` needs **no GitHub
token** — just a one-time `brew trust` for the tap (a Homebrew 6.0+ requirement
for *any* third-party tap; no credentials involved).

## Quick start

```bash
# 1. Tap, trust, install — no GitHub token needed
brew tap arqtiqa/arqtos
brew trust arqtiqa/arqtos       # one-time: Homebrew 6.0+ requires trusting any third-party tap
brew install arqtos-cli

# 2. Verify
arqtos version

# 3. Prepare this machine, then join an org and focus a workspace
arqtos init --plan
arqtos org join --plan
arqtos focus --plan
```

`arqtos focus` selects a workspace and converges to it. Run `arqtos doctor`
any time to preflight a floe.

> **Renamed at 0.3.58**: the formula was `arqtos` and is now **`arqtos-cli`**
> (`formula_renames.json` is permanent). The bare token `arqtos` is reserved
> for the future macOS app cask.
>
> **From 0.5.0** `arqtos-cli` ships the Line-5 runtime: `arqtos`,
> `arqtos-broker`, `arqtos-connectors`, `arqtos-gateway`,
> `arqtos-reconciler`. It does not install `arqtosd`. `brew install
> arqtos-core` is not a user-facing token.

## Upgrade

```bash
brew services stop arqtos-cli     # drop leftover writers; two writers on one state root is refused
brew update
brew upgrade arqtos-cli           # pre-0.3.58 installs: `brew upgrade arqtos` still works via the rename mapping
arqtos launch activate            # reload the launch-plan supervisor
```

The reconciler supervisor is `arqtos launch activate`. Journal, repository
and intake live under `~/.arqtos/state` — the same layout contract `arqtos
doctor` and `arqtos launch plan` use. `brew services start` must not start
a second writer. Gateway, broker and connectors ride the same activate
step and are not started by install.

`brew upgrade arqtos-cli` does not rewrite user configuration, worktrees, or
the adopted Seed pin. A failed upgrade is recovered by reverting
`Formula/arqtos-cli.rb` — never by deleting the tag.

## How distribution works

`arqtos` is closed-source — the source repo is private. The **compiled binary**
is published as a public release asset on this tap, so installs and upgrades
need no GitHub token. (Homebrew 6.0+ separately requires a one-time
`brew trust arqtiqa/arqtos` for *any* non-official tap — a Homebrew policy, not
an arqtos credential step.) The binary is inert without an arqtos environment
(config + bergs); configuration and secrets are never distributed here —
the formula and the binary are all this tap carries.
