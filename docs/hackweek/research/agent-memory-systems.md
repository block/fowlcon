# Agent Memory Systems for Code Review State

**Context:** Fowlcon V1.01 evaluates structured backing stores for the review tree. V1.0 uses markdown files; V1.01 may adopt a graph-based system.

## The Problem

Fowlcon's review tree is a hierarchical graph: concepts with children, statuses, file mappings, and comments. V1.0 stores this as a markdown file with embedded checkboxes, managed by shell scripts. This works but lacks structured queries ("show me all pending nodes") and graph operations ("what's the subtree under concept 3?").

## Beads (steveyegge/beads)

[Beads](https://github.com/steveyegge/beads) (17k+ stars) is a distributed, git-backed graph issue tracker purpose-built as persistent memory for AI coding agents.

**What maps to Fowlcon's needs:**
- Parent/child hierarchy with dotted IDs (`bd-a3f8.1.1`)
- `bd ready --json` -- "show me unblocked/pending work"
- Git-backed persistence across sessions
- Agent-friendly JSON output
- Hash-based IDs prevent merge conflicts

**What doesn't map:**
- Fixed status enums (`open`, `in_progress`, `closed`) -- Fowlcon needs `pending`, `reviewed`, `accepted`
- Issue tracker vocabulary (epics, sprints, messaging) -- Fowlcon needs review tree vocabulary
- Designed for task tracking, not code review state

**Implementations:**

| Implementation | Language | Storage | Sync | Status Extensible |
|---|---|---|---|---|
| Go Beads (`bd`) | Go | Dolt (version-controlled SQL) | Automatic (Dolt push/pull) | No (hardcoded) |
| beads_rust (`br`) | Rust | SQLite + JSONL | Manual (`br sync`) | No (4 fixed statuses) |
| beads-rs | Rust | Pure git refs (CRDT) | Automatic (daemon) | No (3 fixed statuses) |

**Key finding:** Neither Rust implementation supports custom statuses. Both have hardcoded enums that don't match Fowlcon's states (pending/reviewed/accepted). Using Beads would require either a fork, labels-as-statuses workaround, or a custom thin layer.

## Alternatives Evaluated

### Claude Code Tasks
- Built-in to Claude Code, zero install
- Session-scoped by default -- no cross-session persistence keyed by PR
- Too limited for persistent review state

### Flux (MCP Kanban)
- Team-level visibility with web dashboard
- Kanban columns don't map to hierarchical tree structure
- Wrong abstraction for our use case

### "ticket" (minimal bash alternative)
- Single bash script, flat files, graph dependencies
- Aligns with our "thin shell scripts" philosophy
- Too flat for nested concept trees

## Complementary Layers Pattern

The ecosystem converges on complementary layers, not one-size-fits-all:

```
Superpowers   -- HOW to work (process discipline)
Claude Tasks  -- WHAT to do (session-level)
Beads         -- WHAT to do (project-level)
Flux          -- WHAT to do (team-level)
```

Fowlcon's review tree is a new layer: WHAT WAS REVIEWED (PR-level, cross-session).

## Recommendation for Fowlcon

- **V1.0:** Markdown tree + shell scripts. Simple, no dependencies, proven in Phase 1.
- **V1.01:** Evaluate Beads as backing store. The graph structure and query API are worth the dependency if the status mismatch can be resolved (fork or labels workaround).
- **Fallback:** Custom lightweight solution -- `git2` + `serde` in Rust with our own status enum. More work but zero dependency mismatch.

## Sources

- [Beads](https://github.com/steveyegge/beads) -- Git-backed issue tracker for AI agents
- [beads_rust](https://github.com/Dicklesworthstone/beads_rust) -- Rust port (SQLite)
- [beads-rs](https://github.com/delightful-ai/beads-rs) -- Rust port (CRDT, pure git)
- [beads_viewer](https://github.com/Dicklesworthstone/beads_viewer) -- Graph-aware TUI
- [Introducing Beads](https://steve-yegge.medium.com/introducing-beads-a-coding-agent-memory-system-637d7d92514a) -- Steve Yegge's introduction
