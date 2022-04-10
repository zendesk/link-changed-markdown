# link-changed-markdown

![Latest Release](https://img.shields.io/github/v/release/zendesk/link-changed-markdown?label=Latest%20Release)
![Tests](https://github.com/zendesk/link-changed-markdown/workflows/Test/badge.svg?branch=main)

A custom Github Action for use on pull requests. The action:

 * looks for added / changed / removed markdown files (`*.md`)
 * creates (or updates, if it's already there) a comment on the PR, linking
   to the rendered forms of the affected files

## Inputs

See `inputs` in [action.yml](https://github.com/zendesk/link-changed-markdown/blob/main/action.yml).

## Output

This action has no outputs.

## Usage of the Github action

```yaml
---
name: Link changed markdown
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  link-changed-markdown:
    runs-on: [ubuntu-latest]
    name: Link changed markdown
    steps:
      - uses: zendesk/link-changed-markdown@VERSION
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
```

where VERSION is the version you wish you use, e.g. `v1.1.0` (or a branch, or a commit hash).
Check the top of this readme to find the latest release.
