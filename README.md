# homebrew-arqtos

Homebrew tap for the **arqtos** toolkit binary.

## Install

`arqtos` is distributed via private GitHub Releases. Installation requires a GitHub Personal Access Token with `repo` scope.

```bash
# 1. Set the token (one-time; or export from your secrets manager)
export HOMEBREW_GITHUB_API_TOKEN=ghp_xxx

# 2. Tap + install
brew tap arqtiqa/arqtos
brew install arqtos

# 3. Verify
arqtos version
```

The formula uses an inline `GitHubPrivateRepositoryReleaseDownloadStrategy` that resolves the release asset via the GitHub API + `Authorization: token` header — necessary because direct release URLs return 404 on private repos without auth.

## Upgrade

```bash
brew update
brew upgrade arqtos
```

## Status

| Channel | Version |
|---|---|
| stable | tracked in `Formula/arqtos.rb` |

Bumps land when a new tagged release ships in the binary source repo. The formula's `version` + `sha256` values match the matching release's `checksums.txt`.

## See also

- [`arqtiqa/arqtos-cli`](https://github.com/arqtiqa/arqtos-cli) — binary source (private; access via PAT)
- [`arqtiqa/arqtos-skills`](https://github.com/arqtiqa/arqtos-skills) — public skill + pack marketplace consumed by arqtos at runtime
