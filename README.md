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
    secrets: inherit
```

If `swiftanvil-meta` remains private, configure an organization secret named `SWIFTANVIL_META_TOKEN` with read access to that repository.
