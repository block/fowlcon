# Agent Prompt Design Guide

A practical guide for writing and maintaining Fowlcon's agent prompts. Captures design decisions, principles, and hard-learned lessons from research and experimentation.

This document serves two audiences:
- **Prompt authors** writing new agent prompts or modifying existing ones
- **Future maintainers** who need to understand WHY prompts are structured the way they are

---

## Principles

### 1. Mechanical enforcement over prompt-based restriction

Tool restriction via YAML frontmatter (`tools: Grep, Glob, LS`) is the strongest role enforcement mechanism available. When a worker has no `Read` tool, it physically cannot read files -- no amount of context pressure or rationalization can override this.

Prompt-based restrictions ("only use Bash for git queries") are weaker. Under context pressure, agents rationalize around soft constraints. If you need a hard boundary, remove the tool.

**Applies to:** Tool selection in frontmatter. When choosing between giving an agent a tool with prompt restrictions vs. not giving it the tool at all, prefer not giving it.

**Evidence:** SWE-agent's ablation studies show structural constraints (linter gates, viewport limits) provide quantifiable gains. The MASFT taxonomy identifies "role drift" as a primary multi-agent failure mode -- tool restriction prevents it mechanically.

### 2. Format constraints are the strongest quality lever

The single most effective technique for improving agent output quality is prescribing the output format precisely. This includes required sections, structural templates, and few-shot examples.

A template with required sections (## Findings, ## Not Resolved, ## Connections) forces the agent to address each section. The agent can't skip "Not Resolved" if the template requires it.

**Evidence:** Aider's switch to SEARCH/REPLACE format reduced GPT-4 Turbo "laziness" by 3x (12 lazy outputs to 4) and improved scores from 20% to 61%. This is the strongest quantified result across all tools in our research.

### 3. Workers receive minimum-viable context

When spawning a worker, provide the search query plus only the context needed to orient the search. Don't forward the full PR context, the review tree state, or information the worker doesn't need.

Every unnecessary token degrades performance. Workers are focused tools -- they work best with focused inputs.

**Applies to:** The concept-researcher deciding what to include in a worker's Task prompt.

### 4. Workers produce universal output; callers translate

Workers use standard `file:line` reference format. They don't need to know about the review tree's `L<start>-<end> (+N/-M)` format. The concept-researcher handles translation to domain-specific formats.

This keeps workers general-purpose (usable outside the review context) and avoids coupling them to the tree format specification.

### 5. Gaps are findings -- report what you couldn't resolve

When a worker encounters a reference it cannot follow (external import, missing file, unresolvable dependency), it reports this explicitly using "could not resolve" language rather than silently stopping.

Example: `Guard.java:23 imports com.example.okhttp.OkHttpClient (could not resolve -- external dependency, not on disk)`

This gives the concept-researcher actionable information: it can dispatch a web search, investigate further, or pass the gap through to the Uncertainties section.

### 6. The documentarian mandate

All worker agents share an identical behavioral block that prevents editorial drift:

```
DO NOT suggest improvements or changes
DO NOT perform root cause analysis
DO NOT propose future enhancements
DO NOT critique the implementation
DO NOT comment on code quality, architecture decisions, or best practices
ONLY describe what exists, where it exists, and how components are organized
```

This block is placed at the top of every worker prompt (primacy bias) and addresses editorial behavior. It does not address thoroughness -- that requires separate controls (see Principle 7).

**Evidence:** Anthropic's prompt engineering research indicates LLMs follow negative constraints ("DO NOT") more reliably than positive-only instructions. The identical block across all tiers prevents inconsistent editorial behavior.

### 7. Light enforcement for thoroughness

The documentarian mandate prevents critique but doesn't prevent lazy searching. Workers can satisfice -- find 3 results when there are 15 and conclude they're done. Add 2-3 targeted anti-rationalization items per agent addressing thoroughness:

- Locator: "If your first search returns few results, try alternative terms before concluding there are few matches"
- Analyzer: "If code references another file, read that file rather than inferring its behavior"
- Pattern-finder: "If you find only one example, search harder -- patterns have multiple instances"

These are specific to each agent's failure modes, not generic warnings. Keep them tight -- walls of constraints dilute signal.

**Separate work discipline from output discipline.** "Be thorough in your investigation" and "be concise in your report" are not contradictory -- they apply to different phases. Make this distinction explicit in the prompt structure.

### 8. Purposeful tone creates investment in output quality

Neither casual ("you're a smart cookie!") nor coldly professional ("execute the following"). Purposeful: connect the agent to the meaningful outcome of its work.

Instead of: "You're a file finder, documenting the codebase as it exists."

Write: "Your findings shape how a reviewer understands a codebase. Completeness matters -- a missed file is a blind spot in the review. Accuracy matters -- a wrong reference wastes the reviewer's time."

Tone creates the agent's default disposition. When it encounters an ambiguous situation not covered by the prompt, a purposeful agent errs toward including potentially relevant information with qualification. A casual agent under-explores. A cold agent under-reports.

### 9. One reasoning pause at the analysis-synthesis boundary

Place one deliberate reasoning checkpoint per agent between "I've gathered information" and "I'm structuring my output." This is where output quality is determined.

Make it specific to the agent's job:
- Locator: "Think carefully about whether your searches have been thorough enough. Have you tried alternative terms?"
- Analyzer: "Think deeply about how the pieces you've read connect to each other and to the broader question."
- Pattern-finder: "Think carefully about what unifies these examples. What is the essential structure versus incidental variation?"

**Important:** Write this as a natural-language instruction that works on its own merit, not as a model-specific keyword trigger. The instruction should improve output quality regardless of which model executes it. Model-specific optimizations (like extended thinking triggers) can be layered on top, but the base instruction must be robust.

**Brittleness note:** Some models respond to specific keywords (like thinking-depth signals) with measurably different behavior. These effects are undocumented and may change with model updates. Build on solid foundations (clear natural-language instructions) with optional model-specific enhancements. If you rely on a keyword and a model update changes its effect, your prompt should still work -- just without the bonus.

### 10. Version context lives at the researcher level, not the worker level

For V1, workers don't track file versions. The review tree header records the PR HEAD SHA. Workers operate on whatever is checked out on disk. The concept-researcher (which has Bash access) verifies the checkout state and manages version context.

Workers report `file:line` references. The researcher knows the SHA because it set up the environment. No echo-back protocol needed -- "a function trusts the values it passed to a subroutine."

When workers encounter external code (other repos, dependencies), they flag it with "could not resolve." The researcher decides whether to investigate (web search, ask orchestrator to clone) or pass through to Uncertainties.

---

## How-To: Writing a Worker Prompt

### Structure

```yaml
---
name: <agent-name>
description: <triggering conditions -- WHEN to use, not WHAT it does>
tools: <comma-separated tool list>
model: sonnet
---
```

The `description` field is a selection protocol for the orchestrator/researcher. It should teach the caller when to choose this agent over alternatives.

**Evidence:** When descriptions summarized workflow, agents abbreviated behavior. When changed to triggering conditions only, agents read the full skill and followed all steps. This is the only behavioral pattern in our research with a documented before/after observation.

### Prompt sections (in order)

1. **Role and purpose** (2-3 sentences). Purposeful tone. What this agent does and why it matters.

2. **Documentarian mandate** (the DO NOT block). Identical across all workers. Placed first for primacy bias.

3. **Core responsibilities** (3-5 items). What the agent actually does.

4. **How to do the work** (process). Search strategy, analysis steps, what to try when stuck. Includes the 2-3 thoroughness items. Ends with the reasoning pause.

5. **PR context guidance** (2-3 sentences). "You may receive additional context about which files are part of a code change. Use changed files as a starting point, not a boundary."

6. **Output format** (structural template). Required sections with clear headers. This is the load-bearing section -- format constraints are the strongest quality lever.

7. **Few-shot example** (~150-250 tokens). One compact example showing the exact output format, `file:line` style, and "could not resolve" pattern.

8. **What NOT to do** (agent-specific). Supplements the documentarian mandate with role-specific prohibitions.

### Front-loading and repetition

Place the most important behavioral constraints at the beginning of the prompt (primacy bias) AND near the output template at the end (recency bias). The middle of the context is the danger zone for constraint compliance.

**Evidence:** Liu et al. (2023) "Lost in the Middle" demonstrates positional bias in long contexts. Critical constraints placed only in the middle are the most likely to be ignored.

### Output template design

Every worker output template should include:

- **A findings section** with `file:line` references for every claim
- **A "not resolved" section** for gaps (external deps, missing files, unresolvable references)
- **Structural grouping** appropriate to the agent (by purpose for locator, by component for analyzer, by pattern for pattern-finder)

The locator specifically must list ALL matching files -- never filter. Completeness is critical because the review tree needs every diff hunk mapped.

The analyzer and pattern-finder can focus depth: analyze what answers the question, mention peripheral findings briefly, don't deep-analyze everything touched.

### Few-shot examples

Include one compact example per worker prompt. The example demonstrates:
- The exact output structure
- The `file:line` reference style
- The "could not resolve" gap-reporting pattern
- Appropriate detail level

Source examples from the test corpus when available. Use placeholder examples initially, tagged with a comment for future update.

---

## How-To: External Dependencies

When a worker encounters code that isn't available locally (external imports, other repos):

1. **Worker reports the gap.** "Guard.java:23 imports com.example.OkHttpClient (could not resolve -- external dependency, not on disk)." Worker moves on.

2. **Concept-researcher decides next step.** Three options:
   - **Note and move on** (90% case). Include in Uncertainties. The reviewer sees "external dep, not analyzed."
   - **Web search.** Researcher dispatches web search for API-level understanding. Sufficient for most review contexts.
   - **Escalate to orchestrator.** "I couldn't fully analyze concept X because dependency Y isn't available locally." The orchestrator can ask the customer whether to clone it.

3. **Never auto-clone.** Cloning repos is expensive (disk, time, tokens) and potentially risky. The orchestrator is the customer relationship holder -- cloning decisions go through it.

---

## How-To: Handling the Three-Tier Hierarchy

### Who does what

| Capability | Worker | Researcher | Orchestrator |
|---|---|---|---|
| Search/read local code | Yes | Yes | Yes |
| Run git commands | No | Yes (Bash) | Yes |
| Spawn sub-agents | No | Yes (Task) | Yes |
| Web search | No | Yes | Yes |
| Manage version context | No | Yes | Yes |
| Build/modify review tree | No | No | Yes |
| Customer interaction | No | No | Yes |

### Researcher as routing layer

The concept-researcher is the intelligence layer between the orchestrator and workers. It:
- Runs `git rev-parse HEAD` to discover version context
- Checks repo existence and working tree cleanliness via Bash
- Decides whether to dispatch workers, web search, or both
- Translates worker `file:line` output to review-tree format
- Synthesizes multiple worker outputs into a coherent answer
- Reports gaps, uncertainties, and external references in structured sections

### When the orchestrator calls workers directly

For simple mechanical tasks: "find where this function is called," "read this file." No conceptual investigation needed. The orchestrator provides the query and receives the result directly.

---

## Research Context

These principles are informed by analysis of:

- **Anthropic's** "Building Effective Agents," "Effective Context Engineering," and "Writing Tools for Agents"
- **OpenAI's** Agents SDK and "Practical Guide to Building Agents"
- **LangChain/LangGraph** plan-and-execute and multi-agent patterns
- **Aider's** edit format benchmarks (the source of the 3x laziness reduction finding)
- **SWE-agent's** ablation studies on structural constraints
- **OpenHands'** Agent-Computer Interface design
- **obra/superpowers** anti-rationalization and behavioral enforcement patterns
- **Academic research**: Liu et al. "Lost in the Middle" (2023), MASFT multi-agent failure taxonomy, Codified Context (arxiv:2602.20478)
- **Instrumented experiments** running research agents against real codebases (local and remote) to observe tool usage patterns and limitation boundaries

Key finding from experiments: workers with restricted tools (Grep/Glob/Read/LS) are excellent on local code (29 deep actions with precise file:line results) and completely useless for external code (0 worker actions -- orchestrator pivoted entirely to web search). This binary characteristic drives the design: workers are local-code specialists, external resolution is a researcher/orchestrator concern.

---

## Decision Log

Decisions made during prompt design, with rationale. Future maintainers should understand these before changing them.

| Decision | Rationale | Revisit when... |
|---|---|---|
| Workers have no Bash access | Mechanical enforcement > prompt restriction. Prevents role creep. | A use case emerges where workers genuinely need shell access AND tool restriction can't solve it |
| No version echo-back in V1 | The researcher knows the SHA because it set up the context. Echo-back solves a coordination problem that doesn't exist in V1's architecture. | Multi-repo analysis becomes a real feature (V1.2+) |
| No formal evidence typing in V1 | Premature abstraction. Let real researcher output emerge before formalizing categories. | Patterns in researcher output stabilize across 10+ real reviews |
| Locator lists ALL matches | Review tree needs every diff hunk mapped. A filtered locator creates coverage gaps that cascade. | A performance issue arises from very large result sets |
| Format constraints prioritized over behavioral blocks | Aider's 3x laziness reduction is the strongest measured effect. Templates force completeness mechanically. | New research shows behavioral blocks have comparable measured effects |
| Reasoning pause as natural language, not model-specific keyword | Model-specific triggers are undocumented and may change. Natural language works across models. | A model provides a documented, stable API for reasoning depth control |
| Light anti-rationalization (2-3 items) vs. full table | Workers have focused queries, restricted tools, short context. Full tables are for orchestrators under context pressure. | Workers are given broader mandates or longer-running tasks |
| Concept-researcher gets WebSearch/WebFetch | Avoids spawning a sub-agent for simple lookups. Deep web research still goes through Task. | Token budget shows web search results are too large for researcher context |
