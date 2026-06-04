# Agent Instructions

This repository contains reusable enforcement tooling for SwiftAnvil.

## Boundaries

- Put reusable scripts, hooks, and workflow templates here.
- Put policy, roadmap, package registry, and shared memory in `swiftanvil-meta`.
- Put product implementation in package repositories.

## Rules

- Enforcement scripts must be host-agnostic and run on macOS, Linux, and CI.
- Scripts must accept configurable roots and registry locations.
- Do not embed user-specific absolute paths.
- Prefer POSIX shell for lightweight validators unless a stronger typed implementation is justified.
- Every new enforcement must have a local command and a CI entry point.
- Agent adapters must scan `PATH` and configurable homes instead of relying on fixed install locations.
- Reviewer selection must be dynamic and must exclude the current builder agent.
- Review runners must emit machine-readable metadata next to human-readable output.
- CI must validate artifacts; local scripts may execute agents.
- Policy changes must keep `scripts/test-enforcement.sh` passing.
