# Contributing to Fowlcon

Thank you for your interest in contributing to Fowlcon! Please read [Block's general contributing guidelines](https://github.com/block/.github/blob/main/CONTRIBUTING.md) first -- they cover forking, branching, commit conventions, PR process, CLA/DCO, and code of conduct.

This document covers **Fowlcon-specific** guidance.

## What This Project Is

Fowlcon is an agentic code review tool. Most of the "code" is **markdown prompt files** and **shell scripts**, not a traditional application. Contributing here means writing prompts, refining agent behavior, and building reliable state management scripts.

## Prerequisites

- A CLI that supports agent commands (Claude Code, Amp, Cursor, or similar)
- `bash` (for shell scripts)
- `bats-core` (for shell script tests): `brew install bats-core` or see [bats-core installation](https://bats-core.readthedocs.io/en/stable/installation.html)
- `gh` CLI (for testing against real PRs): `brew install gh`

## Installation

```bash
git clone https://github.com/block/fowlcon.git
cd fowlcon
./script/install
```

## Testing

```bash
# Run all shell script tests
bats tests/scripts/

# Run a specific test file
bats tests/scripts/test-update-node-status.bats
```

## Fowlcon-Specific Conventions

### Shell Scripts

- TDD with bats-core. Write the failing test first.
- All writes are atomic: temp file + `mv`.
- Single-writer assumption must be maintained.

### Agent Prompts

- Prompts can't be TDD'd conventionally. Instead: test against a real PR, verify output structure and coverage, document results in the PR description.
- Agents are documentarians -- they describe, never critique.
- Keep each agent focused on one thing.

### Every Change Must

1. **Verify** -- tests pass, or manual testing is documented
2. **Document** -- update AGENTS.md or README.md if behavior changes
3. **Align with principles** -- read the 10 core principles in README.md

### Areas Where Help is Welcome

- Shell script improvements (reliability, edge cases, portability)
- Agent prompt refinement (better tree construction, clearer explanations)
- Testing against diverse PRs (different languages, sizes, patterns)
- Documentation and examples
- TUI exploration (see README for context)

## Questions?

Open an issue or reach out to the maintainers listed in [CODEOWNERS](./CODEOWNERS).
