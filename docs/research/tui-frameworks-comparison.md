# TUI Framework Comparison for Agent-Driven Code Review

**Context:** Fowlcon V1.01 replaces the conversational walkthrough with a dedicated TUI. This research compares the leading frameworks.

## Candidates

| Framework | Lang | Stars | Architecture | Rendering |
|-----------|------|-------|-------------|-----------|
| **Ink** | JS/TS | 35k+ | React custom renderer | Virtual DOM → string |
| **Bubble Tea** | Go | 28k+ | Elm Architecture (MVU) | Model-View-Update |
| **Ratatui** | Rust | 18k+ | Immediate-mode | Double-buffered diff |
| **Textual** | Python | 18k+ | Async DOM + CSS | Retained-mode with TCSS |

## What Fowlcon's TUI Needs

- Tree visualization with status markers (pending/reviewed/accepted)
- Diff viewing with context
- Conversation panel (reviewer talks to agent)
- Quick response controls (single-key confirm, accept, navigate)
- Markdown rendering (agent explanations)
- File watching (auto-refresh when state files change)

## Framework Analysis

### Ink (React for Terminals)

**Architecture:** Custom React renderer targeting the terminal. Yoga (Flexbox) layout engine. All React features work -- hooks, state, effects, Suspense.

**Strengths for Fowlcon:**
- Claude Code is built on Ink -- the exact "agent streaming output in a TUI" pattern is proven
- `<Static>` component renders completed items permanently above the active UI (ideal for conversation history)
- React's component model maps to our tree (each node is a component with state)
- TypeScript-first, rich ecosystem (ink-markdown, ink-text-input, ink-select-input)

**Limitations:**
- No native scrolling (must implement windowing manually)
- No CSS Grid (Flexbox only)
- `<Text>` cannot contain `<Box>` elements
- Requires Node.js runtime

**Known users:** Claude Code, Gemini CLI, GitHub Copilot CLI, Vitest, Prisma, Vercel CLI

### Bubble Tea (Go Elm Architecture)

**Architecture:** Elm Architecture (MVU) -- single Model, Update processes messages, View renders strings. Commands handle side effects.

**Strengths for Fowlcon:**
- Single binary deployment (no runtime)
- Fast startup (<10ms)
- Go goroutines handle concurrent commands naturally
- Rich ecosystem: Lip Gloss (styling), Bubbles (components), Glamour (markdown rendering)
- `WithoutRenderer()` for headless/testing mode
- v2 Cursed Renderer for optimized rendering

**Limitations:**
- No layout engine -- manual positioning via Lip Gloss `Place`/`JoinHorizontal`/`JoinVertical`
- Nested components need explicit message routing boilerplate
- MVU learning curve for imperative Go programmers

**Known users:** Glow, Soft Serve, Mods, CockroachDB, AWS eks-node-viewer

### Ratatui (Rust Immediate-Mode)

**Architecture:** Immediate-mode rendering -- entire UI redrawn from state each frame. Double-buffered diff rendering writes only changed cells.

**Strengths for Fowlcon:**
- Sub-millisecond rendering, zero-cost abstractions
- Constraint-based layout (Cassowary algorithm)
- Rich built-in widgets: List, Table, Paragraph, Scrollbar, Tabs, Tree (community)
- Single binary, minimal overhead

**Limitations:**
- No built-in event handling (bring your own via crossterm/termion)
- No built-in application structure (design your own main loop)
- Steep learning curve (Rust ownership + immediate-mode + external event loop)
- Still on v0.x (no v1.0 announced)

**Known users:** Amazon Q CLI, Netflix bpftop, OpenAI Codex CLI, Helix editor

### Textual (Python Async TUI + Web)

**Architecture:** Retained-mode DOM tree with CSS engine, message passing, async event loop. Essentially web development patterns for the terminal.

**Strengths for Fowlcon:**
- Built-in Tree, Markdown, DataTable, TextArea widgets -- less to build from scratch
- CSS-based layout (Grid + Flexbox) -- easiest complex multi-panel layouts
- Web mode for free (`textual serve`) -- share reviews in a browser with zero code changes
- Fastest iteration speed (Python + live CSS editing)
- Workers (`@work`) for non-blocking I/O

**Limitations:**
- Python startup time (~200-500ms)
- Higher memory overhead (retained DOM + CSS engine)
- GIL limitations for true parallelism

**Known users:** DevOps monitoring tools, cybersecurity dashboards

## Key Pattern: beads_viewer

[beads_viewer](https://github.com/Dicklesworthstone/beads_viewer) (1.3k stars) is a Bubble Tea TUI built on top of the Beads issue tracker. It demonstrates patterns directly applicable to Fowlcon:

- **File watching + auto-refresh:** Watches `.beads/beads.jsonl` and refreshes all views when it changes. Maps to watching `review-tree.md`.
- **Robot mode API:** `--robot-*` flags expose a structured JSON API for agents. The TUI is both interactive AND programmable. Agents drive the UI via CLI flags.
- **Split view:** Left pane (tree/list with vim navigation) + right pane (details). Maps to our tree + diff layout.
- **Single-key interactions:** `j/k` navigation, `o/c/r` for filters, single key per view. Solves the "quick response" problem.
- **Two-phase computation:** Instant metrics shown immediately, heavy computation runs async. Keeps UI responsive.

The robot mode pattern is particularly relevant: file-based for persistence, robot mode for real-time agent-to-TUI communication.

## Recommendation

No framework is selected yet. The pluggable UI interface (design doc Section 6.2) ensures the choice is a front-end swap, not a rewrite. Evaluation criteria in priority order:

1. Can it render a tree with status markers and respond to single-key inputs?
2. Can it watch files for changes and auto-refresh?
3. How fast can we iterate during development?
4. Does it support a robot mode API pattern for agent control?

## Sources

- [Ink](https://github.com/vadimdemedes/ink) -- React renderer for terminals
- [Bubble Tea](https://github.com/charmbracelet/bubbletea) -- Go Elm Architecture TUI
- [Ratatui](https://ratatui.rs/) -- Rust immediate-mode TUI
- [Textual](https://textual.textualize.io/) -- Python async TUI + web
- [beads_viewer](https://github.com/Dicklesworthstone/beads_viewer) -- Graph-aware TUI for Beads
- [Lip Gloss](https://github.com/charmbracelet/lipgloss) -- Terminal styling for Bubble Tea
- [Glamour](https://github.com/charmbracelet/glamour) -- Markdown rendering for terminals
