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

Run the enforcement self-tests before changing policy scripts:

```sh
scripts/test-enforcement.sh
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
    uses: swiftanvil/swiftanvil-enforcement/.github/workflows/document-registry-policy.yml@v1
```

The default registry repository is public, so no private token is required for standard SwiftAnvil repositories.
The workflow also checks out enforcement scripts at `enforcement_ref`, which defaults to `v1`, so pinned callers do not accidentally run unreleased `main` scripts.

## Independent Review Runner

Some agent hosts run with a sandboxed `HOME`, which can make authenticated reviewer CLIs look unauthenticated even when they work in a normal terminal. Use enforcement tooling instead of calling reviewer CLIs directly.

Discover local agents:

```sh
scripts/discover-agents.sh --probe --format markdown
```

Select an independent reviewer dynamically:

```sh
scripts/select-reviewer.sh --current codex
```

Run a review with automatic reviewer selection:

```sh
scripts/run-agent-review.sh \
  --agent auto \
  --builder codex \
  --request ../swiftanvil-meta/Reviews/request.md \
  --output ../swiftanvil-meta/Reviews/review-claude.md
```

The runner writes both the review output and a sidecar metadata file:

```text
review-claude.md
review-claude.md.review.yml
```

The script resolves the login home directory by default. Override it with `SWIFTANVIL_AGENT_HOME` if a reviewer tool stores credentials elsewhere.
`--builder` is required so enforcement can prove the review was performed by a different agent than the implementer.

Prefer a reviewer order without hardcoding it into a repository:

```sh
SWIFTANVIL_REVIEWER_PREFERENCE=claude,kimi,gemini \
  scripts/run-agent-review.sh --agent auto --builder codex --request request.md --output review.md
```

## Review Artifact Enforcement

Validate review artifacts locally:

```sh
scripts/validate-review-artifacts.sh --root ../swiftanvil-meta
```

The validator requires:

- every review request to have at least one successful review metadata file
- successful reviews to contain a valid verdict
- successful reviews to record both the reviewer and builder agents
- reviewer and builder to differ
- output files referenced by metadata to exist

## Local Enforcement Without GitHub Minutes

Run the same local checks directly:

```sh
scripts/enforce-local.sh \
  --registry-root ../swiftanvil-meta \
  --root ../swiftanvil-meta
```

Run the local GitHub Actions workflow when `act` is installed:

```sh
scripts/run-local-actions.sh --root ../swiftanvil-meta
```

If `act` is not installed, the script falls back to `enforce-local.sh`.
