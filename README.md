# homebrew-arqtos

Homebrew tap for the **arqtos** toolkit — the operating layer for specialised
professional teams. The tap is public and `brew install` needs **no GitHub
token** and no per-machine auth.

## Quick start

```bash
# 1. Tap + install (no auth required)
brew tap arqtiqa/arqtos
brew install arqtos

# 2. Verify
arqtos version

# 3. Bootstrap this floe — creates ~/Arqtos, seeds operator.yml + floe.yml
arqtos init --operator-name "<your name>" --operator-role human --floe-class station
#    joining an existing org?  add:  --join-org <org-slug>

# 4. Register the floe's identity
arqtos floe register

# 5. Import the bergs you can access, then focus an igloo
arqtos igloo new --import-existing <gh-org>/<berg-repo>
arqtos focus <igloo>
```

`arqtos focus <igloo>` activates the context: it resolves the config cascade,
switches the Terminal.app profile, and wires the MCP gateway for Claude Code.
Run `arqtos doctor` any time to preflight a floe.

## Upgrade

```bash
brew update
brew upgrade arqtos
```

## Terminal font (optional)

The bundled Arqtos Dark / Light Terminal.app profiles render with JetBrains
Mono (Homebrew can't pull a cask as a formula dependency, so it's a separate
one-time step):

```bash
brew install --cask font-jetbrains-mono
```

Without the font, Terminal.app falls back to Menlo at first `arqtos focus`
activation; everything else works.

## How distribution works

`arqtos` is closed-source — the source repo is private. The **compiled binary**
is published as a public release asset on this tap, so installs and upgrades
need no GitHub token. The binary is inert without an arqtos environment
(config + bergs); configuration and secrets are never distributed here —
the formula and the binary are all this tap carries.
