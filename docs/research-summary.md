# Research Summary: Building an Agentic Code Review Tool

A summary of findings from research conducted to inform the design of Fowlcon. This document covers the evidence base behind the architecture, agent design patterns, and prompt engineering principles.

---

## 1. The Problem Space

AI coding agents are flooding review queues with PRs that are larger, more frequent, and structurally different from human-authored work. A single agent session can produce changes spanning hundreds of files -- mixing mechanical changes (the same pattern applied repetitively) with novel logic requiring genuine human judgment.

**Key statistics:**
- 82 million monthly code pushes on GitHub (Octoverse 2025)
- 41% of new code is AI-assisted
- PRs are growing 18% larger with AI; incidents per PR up 24%
- Review is now the rate limiter, not code generation

**No existing tool solves this.** Current AI code review tools (CodeRabbit, GitHub Copilot review, Graphite Agent) find bugs and post inline comments. None organize changes into logical concepts, collapse repetitive patterns, or provide interactive walkthroughs. Fowlcon fills a gap the academic community has identified but not solved -- a [February 2026 survey of 99 code review papers](https://arxiv.org/abs/2602.13377) found that change decomposition tasks have nearly vanished in the LLM era (14 datasets pre-LLM, only 1 in the LLM era).

---

## 2. Multi-Agent Orchestration

### Agent-as-Tool, Not Agent-as-Peer

2024-2025 evidence converges strongly on the **agent-as-tool** model for orchestration. Sub-agents receive a typed task, do their work in an isolated context window, and return structured output. The orchestrator never sees their internal reasoning.

Anthropic's ["Building Effective Agents"](https://www.anthropic.com/research/building-effective-agents) guide explicitly recommends structured output from sub-agents over conversational output. The peer model causes context window catastrophe -- a 10-turn investigation between orchestrator and researcher can consume 40k tokens just in message history.

**Frameworks compared:**
- [LangGraph](https://langchain-ai.github.io/langgraph/): Graph-based supervisor with state reducers per key
- [CrewAI](https://docs.crewai.com/): Role-based hierarchical with isolated workers
- [AutoGen/AG2](https://arxiv.org/abs/2308.08155): Conversational message bus (Microsoft Research)
- [OpenAI Swarm](https://github.com/openai/swarm): Lateral handoffs, experimental

All converge on the same pattern for reliability: orchestrator dispatches, workers return structured results, orchestrator synthesizes.

### Single-Writer State Management

The most robust pattern for shared state is **single-writer with atomic transitions**: one process (the orchestrator) is the sole entity that commits writes. Sub-agents return proposed deltas; they never write directly. This maps to distributed systems fundamentals (Lamport) and is the approach used by LangGraph's state reducers.

### Supervisor Mode for Parallel Agents

When spawning multiple agents, use **supervisor mode**: failures captured as data, not exceptions. If 2 of 3 agents succeed, their findings are independently valuable. [Structured concurrency research](https://vorpus.org/blog/notes-on-structured-concurrency-or-go-statement-considered-harmful/) (Trio, Kotlin, Swift TaskGroup) provides the theoretical foundation; the [MASFT taxonomy](https://arxiv.org/abs/2502.xxxxx) maps failure modes specific to multi-agent LLM systems.

**Key references:**
- [MemGPT](https://arxiv.org/abs/2310.08560) -- context-as-memory paging system
- [MetaGPT](https://arxiv.org/abs/2308.00352) -- SOPs as agent coordination primitive
- [Lilian Weng, "LLM-Powered Autonomous Agents"](https://lilianweng.github.io/posts/2023-06-23-agent/) -- best survey of memory/tool/orchestration patterns

---

## 3. LLM Diff Comprehension

### Unified Diff Is the Best Format

The [Diff-XYZ benchmark](https://arxiv.org/abs/2510.12487) (Oct 2025) -- the first dedicated benchmark for LLM diff understanding -- tested three tasks (Apply, Anti-Apply, Diff Generation) across multiple models and formats.

**Key findings:**
- Unified diff is the best format for Apply and Anti-Apply tasks
- Claude Sonnet and GPT-4.1 achieved highest performance
- Smaller models benefit from adapted formats (explicit ADD/DEL tags)
- No universal solution -- format selection should match model capability

### Omit Line Numbers from Hunk Headers

[Aider's research](https://aider.chat/docs/unified-diffs.html) found that **unified diffs make GPT-4 Turbo 3x less lazy** (score 20% → 61%, lazy instances 12 → 4). Critical design principles:

1. **Omit line numbers** from hunk headers -- agents perform poorly with explicit line numbers
2. **Chunk by semantic unit** (function/class), not minimal hunk
3. **Include context lines** for matching anchors
4. **Apply flexibly** -- disabling flexible application caused 9x increase in editing errors

### Implications

When passing diff context to agents, use unified diff format, strip hunk header line numbers, include surrounding context lines, and chunk by semantic unit rather than minimal hunk.

---

## 4. Cognitive Load and Tree Structure

### Working Memory Bounds

Miller's 7±2 (1956) is the strategic capacity with rehearsal and chunking. [Cowan's 4±1](https://doi.org/10.1017/S0140525X01003922) (2001) is the raw capacity when strategies are blocked. For labeled, on-screen tree nodes, 5-7 is defensible at the top level because labels provide scaffolding.

### Hierarchy Depth

Decades of depth-breadth research (Miller 1981, Kiger 1984, Larson & Czerwinski 1998, Zaphiris 2000) converge: **2 levels is optimal, 3 is acceptable, 4+ consistently degrades performance**.

### Children Per Node

The optimal sub-items-per-concept ratio is **3-5**. A node with 1 child is structural waste (collapse it). A node with 8+ children exceeds both raw and strategic working memory.

### Practical Limits for Review Trees

| Parameter | Preferred | Acceptable | Never |
|-----------|-----------|------------|-------|
| Top-level concepts | 5-6 | up to 7 | 8+ |
| Tree depth | 2-3 levels | 3 levels | 4+ |
| Children per node | 3-5 | 2-7 | 1 or 8+ |
| Node labels | Descriptive functional names | Short phrases | "Other", "Misc" |

### Code Review Specific

The [Cisco code review study](https://smartbear.com/learn/code-review/best-practices-for-peer-code-review/) found 200-400 LOC is optimal per review session, with a cliff effect beyond that threshold. Microsoft research found more files = less useful feedback, with a quality shift at 600+ LOC. This validates organizing large PRs into bounded, reviewable units.

---

## 5. Human Factors in AI-Assisted Review

### Trust Is Asymmetric

84% of developers adopt AI tools but only 33% trust them. Trust is asymmetric: one bad AI suggestion erodes trust more than many good ones build it. Senior developers are the most skeptical (20% "highly distrust").

### Automation Bias

AI suggestions are accepted 60-80% of the time. 59% of developers use AI code they don't fully understand. Paradoxically, **higher AI quality increases complacency** -- 2.5x more likely to merge without review.

The "documentarian" agent pattern (facts, not recommendations) is an anti-automation-bias design. When the tool organizes and explains rather than judges, the reviewer must engage their own judgment.

### Alert Fatigue

Tools get ignored when developers override >30% of flags. The best-in-class tools achieve <3% false positive rates. [Graphite](https://graphite.dev/) reduced false positives from 9:1 to 1:1 by switching from free-text to function-calling output format -- constraining the model's output space was more effective than instructing it to be careful.

**Key finding:** Precision beats recall when humans are in the loop. A tool catching 45% of bugs with high trust outperforms one catching 50% that gets ignored.

### Interactive vs. Batch Review

Working memory holds 2-4 concurrent chunks. Comment dumps exceed this immediately. Progressive disclosure (show summary, let user drill into detail) improves 3/5 usability components (NNG research). Amazon Q explicitly adopted the interactive model.

The ideal pattern: summary first → structured navigation → detail on demand → conversation capability.

---

## 6. Behavioral Controls in Agent Prompts

### Format Constraints Are the Strongest Control

The single most effective behavioral control is **constraining output format**. Measured results:

| Technique | Measured Effect | Source |
|-----------|----------------|--------|
| Edit format switch (SEARCH/REPLACE → unified diff) | 3x laziness reduction | [Aider benchmarks](https://aider.chat/docs/unified-diffs.html) |
| Free-text → function calling | 9:1 → 1:1 false positive ratio | Graphite engineering blog |
| Required JSON schema | Eliminates format errors | [OpenAI structured outputs](https://platform.openai.com/docs/guides/structured-outputs) |

When an agent must fill required sections of a template, it cannot skip them. Format constraints convert behavioral requirements into structural requirements.

### Negative Constraints

The "documentarian mandate" (six DO NOT rules + one ONLY rule) is the most reliable behavioral control observed in production agent tools. Pure negative instructions are unreliable alone -- pair them with positive alternatives. The effectiveness comes from targeting specific failure modes rather than making vague positive requests.

### Named Anti-Patterns

Naming specific rationalizations an agent might use ("This is simple enough to skip") paired with corrections ("Build the tree anyway") is theoretically grounded in [inoculation theory](https://en.wikipedia.org/wiki/Inoculation_theory) (McGuire, 1961). A named anti-pattern is harder to use than an unnamed one.

### Prompt Placement

[Liu et al. (2023)](https://arxiv.org/abs/2307.03172) "Lost in the Middle" established the U-shaped attention curve. Place critical constraints at both the beginning (primacy) and end (recency) of prompts. [Microsoft Research (2025)](https://arxiv.org/abs/2502.xxxxx) found 39% average degradation in multi-turn conversations with 112% increase in unreliability.

### The Practical Hierarchy

From strongest to weakest behavioral control:

1. **Constrain output structure** (schemas, templates, required sections)
2. **Optimize placement** (primacy + recency positioning)
3. **Provide positive examples** (few-shot with correct output)
4. **Name failure patterns** (anti-rationalization tables)
5. **Use negative instructions** (paired with positive alternatives)

---

## 7. Context Window Management

### Context Degradation Is Real

Even with perfect retrieval, performance degrades 13.9%-85% as context grows. The "Lost in the Middle" effect creates a U-shaped attention curve: beginning and end are attended to; middle content is lost.

**Multi-turn degradation:** Microsoft Research found 39% average degradation in long conversations, decomposed into 16% aptitude loss and 112% unreliability increase. Critically, **batching context into a fresh call restored 90%+ accuracy**.

### The Fresh Start Pattern

State lives on the filesystem (markdown files), not in the LLM's context window. Each session reads world state from files. Failed attempts leave traces. This is the [Reflexion pattern](https://arxiv.org/abs/2303.11366) (Shinn et al., NeurIPS 2023) applied to agentic code review.

### Context Budget Discipline

Treat context as a finite resource:
- Static content (format specs, instructions): cache across calls
- Sub-agent results: commit to disk, then drop from context
- Coverage status: check via script output, not accumulated findings
- Walkthrough: fresh context at phase boundaries

[Factory.ai's research](https://factory.ai/news/context-window-problem) on scaling agents recommends: structured repository overviews at session start, targeted file operations (specific line ranges, not full files), and hierarchical memory layers.

---

## 8. Error Recovery

### Four Failure Archetypes

Research identifies four recurring failure patterns in multi-agent LLM systems:

1. **Premature action without grounding** -- acting before reading enough context
2. **Over-helpfulness** -- substituting missing entities with hallucinated ones
3. **Distractor-induced context pollution** -- irrelevant context degrading reasoning
4. **Fragile execution under load** -- performance degrading with large inputs

Source: [AgentErrorTaxonomy](https://arxiv.org/abs/2512.07497), [AgentDebug framework](https://arxiv.org/abs/2509.25370)

### Graceful Degradation

When non-critical agents fail, proceed with available results. Mark failed areas in the review tree as `[pending]`. The coverage checker catches gaps mechanically. The reviewer sees what was and wasn't analyzed.

### Anti-Hallucination Through Tool Verification

Every claim must be verifiable by a tool call. The coverage checker can double as a grounding verifier -- given findings with file:line claims, it reads those lines and confirms the claims match reality. This is the [CRITIC pattern](https://arxiv.org/abs/2305.11738) (Gou et al., ICLR 2024) applied to code review.

---

## 9. Security Considerations

### Prompt Injection in Code Review

PR diffs, descriptions, and code are untrusted input. [OWASP ranks prompt injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/) as the #1 critical vulnerability for LLM applications (2025).

### Defense-in-Depth

1. **Privilege minimization**: agents get read-only access (`Read, Grep, Glob` -- no `Write`, no `Bash`)
2. **Data/instruction separation**: diff content passed as data within structured delimiters, not as instructions
3. **Output validation**: verify file paths reference real files, line numbers are within bounds
4. **The strongest defense**: the agent never recommends approve/reject. Even if an attacker manipulates the agent's understanding, the human reviewer sees actual code during walkthrough.

---

## 10. Cost Optimization

### Model Tiering

| Role | Model | Why |
|------|-------|-----|
| Orchestrator | Opus | Complex reasoning, multi-turn, synthesis |
| Concept researchers | Sonnet | Focused analysis, good quality/cost ratio |
| Coverage checker | Haiku | Mechanical verification, fast and cheap |

### Key Optimization Levers

- **Prompt caching**: 90% savings on repeated content (format specs, agent instructions)
- **Model tiering**: route 90% of work to cheaper models (cascading pattern saves 60-87%)
- **Batch API**: 50% discount for non-interactive analysis phases
- **Context minimization**: send relevant hunks, not full files; drop findings after committing to disk

### Estimated Cost

~$2-3 per review for a 50-file PR. Larger PRs (390 files) cost proportionally more due to additional research agents.

---

## 11. The Competitive Landscape

### Existing AI Code Review Tools

| Tool | Approach | Catch Rate (Greptile benchmark) |
|------|----------|------|
| [Greptile](https://www.greptile.com/) | Deep codebase-aware review | 82% |
| [GitHub Copilot](https://github.com/features/copilot) | PR review as Copilot extension | ~55% |
| [CodeRabbit](https://coderabbit.ai/) | Automatic inline comments | 44% |
| [Graphite Agent](https://graphite.dev/) | Stacked PRs + AI review | 6% (workflow-focused) |
| [Qodo PR-Agent](https://github.com/qodo-ai/pr-agent) | Open source, layered architecture | -- |

### What Makes Fowlcon Different

No existing tool does what Fowlcon does:
1. **Concept tree decomposition** of arbitrary PRs
2. **Pattern collapse** (194 identical changes → 1 example + 193 `{repeat}`)
3. **Interactive walkthrough** with explicit reviewer confirmations
4. **Coverage guarantee** (every changed line mapped)
5. **PR description verification** against actual diff
6. **Structured pushback** on overly complex PRs (not "too big" but "here are the 7 concepts and why they interleave")

Fowlcon is a **comprehension tool**, not a bug finder. It helps reviewers understand what's there so they can decide what's wrong themselves.

---

## 12. Open Source Agents -- Converging Patterns

Analysis of SWE-agent, OpenHands, Aider, Plandex, Mentat, Devika, and Devin reveals 8 patterns converging across the ecosystem:

1. **Orchestrator-worker split** (universal)
2. **Repository maps beat iterative search** ([Aider's PageRank approach](https://aider.chat/docs/repomap.html): 4-6% context utilization vs 54-70% for iterative search)
3. **Context condensation is critical** (SWE-agent, OpenHands, Plandex all implement it)
4. **Sandboxed state separate from source** (Plandex, Devin, SWE-agent)
5. **Documentation as load-bearing infrastructure** (CLAUDE.md, AGENTS.md trend)
6. **Confidence-based filtering** (reduce noise by scoring finding confidence)
7. **Event sourcing for agent state** (OpenHands V1)
8. **Standardized protocols** (MCP, A2A)

**Devin insight** (from Cognition's 18-month performance review): "senior-level at codebase understanding, junior at execution." Since code review is primarily an understanding task, this validates the agent-assisted review approach.

---

## Sources

### Academic Papers
- [Diff-XYZ: A Benchmark for Evaluating Diff Understanding](https://arxiv.org/abs/2510.12487) (Oct 2025)
- [A Survey of Code Review Benchmarks in Pre-LLM and LLM Era](https://arxiv.org/abs/2602.13377) (Feb 2026)
- [Lost in the Middle: How Language Models Use Long Contexts](https://arxiv.org/abs/2307.03172) (Liu et al., 2023)
- [Reflexion: Language Agents with Verbal Reinforcement Learning](https://arxiv.org/abs/2303.11366) (NeurIPS 2023)
- [AutoGen: Enabling Next-Gen LLM Applications via Multi-Agent Conversation](https://arxiv.org/abs/2308.08155)
- [MemGPT: Towards LLMs as Operating Systems](https://arxiv.org/abs/2310.08560)
- [MetaGPT: Meta Programming for Multi-Agent Collaborative Framework](https://arxiv.org/abs/2308.00352)
- [CRITIC: Large Language Models Can Self-Correct with Tool-Interactive Critiquing](https://arxiv.org/abs/2305.11738) (ICLR 2024)
- [The Effects of Change Decomposition on Code Review](https://peerj.com/articles/cs-193/) (PeerJ)

### Industry and Engineering Sources
- [Anthropic: Building Effective Agents](https://www.anthropic.com/research/building-effective-agents) (2024)
- [Aider: Unified Diffs Make GPT-4 Turbo 3x Less Lazy](https://aider.chat/docs/unified-diffs.html) (2024)
- [Aider: Repository Map](https://aider.chat/docs/repomap.html)
- [Lilian Weng: LLM-Powered Autonomous Agents](https://lilianweng.github.io/posts/2023-06-23-agent/) (2023/2024)
- [Factory.ai: The Context Window Problem](https://factory.ai/news/context-window-problem)
- [OWASP Top 10 for LLM Applications](https://genai.owasp.org/llmrisk/llm01-prompt-injection/) (2025)
- [State of AI Code Review Tools 2025](https://www.devtoolsacademy.com/blog/state-of-ai-code-review-tools-2025/)
- [Greptile AI Code Review Benchmarks](https://www.greptile.com/benchmarks)
- [Smashing Magazine: Designing for Agentic AI](https://www.smashingmagazine.com/2026/02/designing-agentic-ai-practical-ux-patterns/) (Feb 2026)
- [Claude Agent SDK Overview](https://platform.claude.com/docs/en/agent-sdk/overview)
- [Anthropic: Skill Authoring Best Practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)

### Open Source Tools Studied
- [SWE-agent](https://github.com/SWE-agent/SWE-agent) -- Agent-Computer Interface for code
- [mini-swe-agent](https://github.com/SWE-agent/mini-swe-agent) -- 100-line agent, 74%+ SWE-bench
- [OpenHands](https://github.com/OpenHands/OpenHands) -- CodeAct architecture
- [Aider](https://github.com/Aider-AI/aider) -- Repository map + edit format research
- [Qodo PR-Agent](https://github.com/qodo-ai/pr-agent) -- Open source code review agent
