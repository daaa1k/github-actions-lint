# github-actions-lint

Composite Action that installs [actionlint](https://github.com/rhysd/actionlint), [ghalint](https://github.com/suzuki-shunsuke/ghalint), and [zizmor](https://github.com/woodruffw/zizmor) with [mise](https://mise.jdx.dev/) and runs them against your repository. Tool versions are defined in this repository’s [`mise.toml`](mise.toml); **you do not need a `mise.toml` in the calling repository.**

## Why no `mise.toml` in the caller?

When you use a composite action with `uses: owner/repo@ref`, GitHub extracts that action into **`github.action_path`**, which always contains this repo’s `mise.toml`. [jdx/mise-action](https://github.com/jdx/mise-action) runs `mise install` there (with caching enabled by default). The linters then run in your checked-out repo via `mise exec -C "${{ github.workspace }}"`, so paths like `.github/workflows` resolve in **your** project.

## Usage

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: YOUR_ORG/github-actions-lint@v1 # or @main / a commit SHA
```

Pinning to a **tag** (for example `v1`) or a **full commit SHA** is recommended for supply-chain stability.

### Inputs

| Name | Description | Default |
|------|-------------|---------|
| `working-directory` | Directory relative to the repository root where the linters run (useful in monorepos). | `.` |

Example for a package under `packages/app`:

```yaml
- uses: YOUR_ORG/github-actions-lint@v1
  with:
    working-directory: packages/app
```

### Notes

- This action pins [jdx/mise-action](https://github.com/jdx/mise-action) to a full commit SHA in [`action.yml`](action.yml). When upgrading the action, resolve a new tag to a SHA (for example `git ls-remote https://github.com/jdx/mise-action.git refs/tags/v4`) and update the `uses:` reference.
- [jdx/mise-action](https://github.com/jdx/mise-action) v4 runs `mise install` by default and enables caching by default; you normally do not need an extra `mise install` step.
- If GitHub API rate limits affect tool installs, `mise-action` passes `github.token` by default; override only if you hit limits in custom setups.
- Local development: run `mise install` and `mise run github-actions-lint` in this repository. The same shell script ([`scripts/run-github-actions-lint.sh`](scripts/run-github-actions-lint.sh)) runs in CI via `mise exec`.
