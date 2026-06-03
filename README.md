# SwiftAnvil Enforcement

Reusable validation scripts, Git hooks, and GitHub Actions workflows for SwiftAnvil repositories.

This repository owns enforcement tooling. Policy and shared memory live in `swiftanvil-meta`; product code lives in the package repositories.

## Responsibilities

| Area | Responsibility |
|------|----------------|
| Document registry policy | Prevent hardcoded references to registered document paths |
| Local Git hooks | Install fast pre-commit checks in cloned SwiftAnvil repos |
| GitHub Actions | Provide reusable workflows for CI enforcement |
| LLM instructions | Validate that agent-facing instructions resolve through registries |

## Document Registry Enforcement

Run the validator against a repository:

```sh
scripts/validate-document-registry.sh \
  --registry-root ../swiftanvil-meta \
  --root ../swiftanvil-meta
```

Install the pre-commit hook across local SwiftAnvil repos:

```sh
scripts/install-git-hooks.sh
```

Repositories may add `.swiftanvil-registry-ignore` for immutable archives or generated docs that should not be rewritten, for example:

```text
Children/*
Composed/*
Documentation/Fragments/*
Phase-Summaries/*
```

## GitHub Actions

Product repositories can call the reusable workflow:

```yaml
name: Document Registry Policy

on:
  pull_request:
  push:
    branches: [main]

jobs:
  document-registry-policy:
    uses: swiftanvil/swiftanvil-enforcement/.github/workflows/document-registry-policy.yml@main
```

The default registry repository is public, so no private token is required for standard SwiftAnvil repositories.

## Independent Review Runner

Some agent hosts run with a sandboxed `HOME`, which can make authenticated reviewer CLIs look unauthenticated even when they work in a normal terminal. Use the review runner instead of calling reviewer CLIs directly:

```sh
scripts/run-agent-review.sh \
  --agent claude \
  --request ../swiftanvil-meta/Reviews/request.md \
  --output ../swiftanvil-meta/Reviews/review-claude.md
```

The script resolves the login home directory by default. Override it with `SWIFTANVIL_AGENT_HOME` if a reviewer tool stores credentials elsewhere.
