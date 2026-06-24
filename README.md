# GitHub Bump and Tag

A GitHub Action that increments a SemVer version number and pushes the new tag.

## Usage
```yaml
jobs:
  deploy:
    steps:
      - name: Bump And Tag
        id: tag_version
        uses: lydianpay/github-bump-and-tag@v1
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs
| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `token` | Yes | — | GitHub token for pushing tags |
| `bump` | No | `patch` | Version segment to bump: `major`, `minor`, or `patch` |

## Outputs
| Output | Description |
|--------|-------------|
| `currentVersion` | The current highest version tag |
| `newVersion` | The newly calculated version |

```yaml
${{ steps.tag_version.outputs.currentVersion }}
${{ steps.tag_version.outputs.newVersion }}
```

## Concurrency

This action is not safe to run concurrently. If two workflows compute the same
version, the second `git push` will fail. Use a GitHub Actions
[concurrency group](https://docs.github.com/en/actions/using-jobs/using-concurrency)
to ensure only one instance runs at a time:

```yaml
concurrency:
  group: bump-and-tag
```

## Version Format

This action matches tags in the format `v1.2.3` or `1.2.3` (plain SemVer).
Pre-release tags (e.g., `v2.0.0-beta.1`) and build metadata tags
(e.g., `v1.0.0+build.42`) are ignored.
