# Agent Prompt Design Decisions

Status: In progress (Q1-Q5 decided, Q6-Q8 pending finalization)

## Context

Design decisions for the three worker agent prompts (`codebase-locator`, `codebase-analyzer`, `codebase-pattern-finder`) established through design review, experiments, and research. These decisions also inform the concept-researcher and orchestrator prompts.

## Decisions

### Q1: PR Context Flowing to Workers

**Decision:** Minimum-viable context per invocation.

Workers receive the search query plus a focused file subset when relevant. The concept-researcher decides what context to forward per invocation.

- A locator searching for "all files that import RoostGuard" needs just the query -- the import exists regardless of the PR file list.
- An analyzer asked to "explain how NestConfig.validate() works" benefits from knowing which files are changed so it can note overlap with the diff.

Workers include a brief section: "You may receive additional context about which files are part of a code change. When present, use changed files as a starting point for your search, but do not limit yourself to only these files."

**Principle:** Workers receive the minimum context needed to orient their search. The caller decides what's relevant per invocation.

### Q2: Version Tracking

**Decision:** Simplified. No per-reference version tracking in V1.

The review tree's `HEAD` SHA field covers all primary repo references. Workers operate on whatever is checked out on disk. The concept-researcher (which has Bash access) handles version discovery and contextualizes worker findings.

Workers do not echo version references or annotate SHAs. Instead:
- The concept-researcher runs `git rev-parse HEAD` before spawning workers
- The researcher knows which version workers analyzed because it set up the context
- Version info lives at the researcher/tree level, not the worker level
- Workers flag unresolvable references with "could not resolve" (see Q3)

**Why not more:** The version ambiguity problem is mostly theoretical in V1. Most PRs are self-contained. External dependency analysis is a V1.2+ concern. The tree SHA covers the common case.

**Principle:** Version tracking lives at the orchestration layer, not the worker layer. Workers report what they find; callers contextualize it.

### Q3: Token Budget and Output Completeness

**Decision:** Structural guidance per agent, not hard token limits.

Workers can't count their own tokens reliably. Instead, each prompt includes behavioral guidance about what to include and what to omit.

**Per-agent rules:**

| Agent | Completeness Rule |
|---|---|
| Locator | List ALL matches. Always. Group and annotate when large, but never silently filter results. |
| Analyzer | Focus depth on what answers the question. Mention files read but not central; don't deep-analyze them. |
| Pattern-finder | Show 2-3 representative examples in detail. Report total count and list all instance locations. |

**Gap reporting:** All workers use a consistent pattern for unresolvable references:

> When you encounter a reference you cannot follow -- an import to external code, a path that doesn't exist, a class you can't locate -- note it explicitly. Use the phrase "could not resolve" followed by what you tried.

Example: `Guard.java:23 imports com.example.SecurityContext (could not resolve -- external dependency, not on disk)`

**Principle:** Constrain output structurally, not numerically. Gaps are findings too -- a worker that silently stops at a boundary is worse than one that says "I stopped here and here's why."

### Q4: Few-Shot Examples

**Decision:** Yes, one compact example per worker prompt.

Research consensus (Anthropic, OpenAI) recommends 1-2 examples for structured output tasks. Cost is ~150-250 tokens per prompt. This is the single highest-ROI investment for output consistency.

Examples will use Hawksbury bird-themed naming (consistent with test fixtures). Placeholder examples will be written initially, then updated once the test corpus is available.

**Action item:** Add a task to review and update prompt examples against the real test corpus.

**Principle:** One compact example is worth more than 500 words of format description. Show, don't tell.

### Q5: Reasoning Pause (Analysis-Synthesis Boundary)

**Decision:** Yes, one reasoning pause per worker, specific to the agent's job.

Placed at the transition between "I've gathered information" and "I'm structuring my response." This is where output quality is determined.

**Per-agent placement:**
- **Locator:** "Think carefully about whether your searches have been thorough enough. Have you tried alternative terms, checked multiple directories, and considered different naming conventions?"
- **Analyzer:** "Think deeply about how the pieces you've read connect to each other and to the broader question."
- **Pattern-finder:** "Think carefully about what unifies these examples. What is the essential structure of the pattern versus incidental variation?"

**Important design note:** Write these as natural-language instructions that work regardless of model. Do not depend on model-specific keywords or undocumented features. The instruction should produce better output on its own merit. If a specific model responds to certain keywords with deeper reasoning, that's an optional enhancement, not a dependency.

**Principle:** Deliberate reasoning pauses at the analysis-synthesis boundary improve output quality. Make them specific to the agent's job. Prefer robust instructions over model-specific techniques.

### Q6: Anti-Rationalization (Partially Decided)

**Direction:** Light enforcement. Research pending on effectiveness.

Keep the documentarian block (DO NOT suggest improvements / DO NOT critique / ONLY describe what exists). Add 2-3 thoroughness items per agent targeting their specific failure modes.

**Key insight from research:** Format constraints (output templates with required sections) have the strongest measured evidence for improving output quality -- stronger than DO NOT blocks (which are industry-standard but unmeasured). The output template does more behavioral work than the prohibition block.

**Proposed thoroughness items:**

Locator:
- If first search returns few results, try alternative terms before concluding
- Do not stop at the first cluster -- check multiple directories and naming conventions

Analyzer:
- If code references another file, read it rather than inferring behavior
- Do not skip error handling paths or conditional branches

Pattern-finder:
- If only one example found, search harder -- patterns have multiple instances
- Include variations and exceptions, not just clean examples

**Pending:** Commissioned research on behavioral control effectiveness. May adjust based on findings.

**Principle:** Separate "how to do the work" (thoroughness) from "how to report the work" (output format). These are different concerns and should not read as contradictory instructions.

### Q7: Tone (Proposed, Not Yet Confirmed)

**Proposed direction:** Purposeful/mission-driven.

Not casual-fun (RPI's "smart cookie", "handy dandy") and not coldly-professional. Instead, connect the agent to the meaningful outcome of its work:

> "Your findings shape how a human reviewer understands this codebase. Completeness matters -- a missed file is a blind spot in the review. Accuracy matters -- a wrong reference wastes the reviewer's time."

The reasoning: tone creates a default disposition. When an agent encounters an ambiguous situation not covered by the prompt, its disposition determines how it acts. A purposeful agent errs on the side of including potentially relevant information with appropriate qualification.

**Status:** Analysis complete, awaiting confirmation.

### Q8: Change Boundary Tracing (Proposed, Not Yet Confirmed)

**Proposed direction:** Split responsibility.

- **Analyzer:** Reports raw connections as part of describing "how the code works" (imports, callers, interfaces, tests). Includes a Connections section.
- **Concept-researcher:** Synthesizes connections from multiple workers into the Change Boundary section, which requires cross-file reasoning no single worker can do.

The analyzer should NOT produce a full change boundary. It reports what it found. The researcher synthesizes the boundary from multiple sources.

**Status:** Awaiting confirmation.

## Tool Access Decisions

| Agent | Tools | Model | Rationale |
|---|---|---|---|
| codebase-locator | Grep, Glob, LS | Sonnet | Find files without reading them. Mechanical role enforcement. |
| codebase-analyzer | Read, Grep, Glob, LS | Sonnet | Read and understand code. No Bash -- can't traverse repo boundaries. |
| codebase-pattern-finder | Grep, Glob, Read, LS | Sonnet | Find patterns with code examples. Same rationale as analyzer. |
| concept-researcher | Read, Grep, Glob, LS, Task, Bash | Sonnet | Spawns workers, discovers versions, checks repo state. Consider adding WebSearch/WebFetch. |
| coverage-checker | Grep, Glob, LS | Haiku | Mechanical file-matching. Cheapest capable model. |

**Key decision:** Workers stay restricted (no Bash). Mechanical enforcement via tool restriction is more reliable than prompt-based restriction. The concept-researcher is the version-discovery and routing layer.

## Experiments and Evidence

### Experiment: Instrumented Researcher on Local Code
- Agent with restricted tools (Grep/Glob/Read/LS) analyzed a large open-source repo
- 29 actions, 19 Read calls, deep implementation-level findings with file:line references
- 3 external references unresolvable (dependencies not on disk)
- **Finding:** Restricted tools work excellently on local code

### Experiment: Research Command on Remote Code
- Standard research command pointed at a repo not cloned locally
- 10 actions, zero worker involvement -- workers were never spawned
- Orchestrator pivoted to web search entirely
- **Finding:** Restricted workers are binary -- excellent on local code, completely useless for external. Routing decision must happen at researcher/orchestrator level.

### Research: Behavioral Control Effectiveness
- Format constraints (output templates) have the strongest measured evidence: 3x laziness reduction in one published study
- DO NOT blocks are industry-standard but have no published effectiveness metrics
- Tool restriction has ablation study support (environment-level, not prompt-level)
- Prompt placement (front-load + repeat at end) has academic backing from positional bias research
- Anti-rationalization tables have theoretical mechanism but no measurement
- Further research commissioned on this topic

## Principles Accumulated

1. Workers receive minimum-viable context per invocation
2. Workers produce universal output formats; callers translate
3. Gaps are findings -- report what you couldn't resolve
4. Constrain output structurally, not numerically
5. One compact example > 500 words of format description
6. Reasoning pauses at analysis-synthesis boundaries, specific to the agent's job
7. Anti-rationalization items must target the agent's actual failure modes
8. Purposeful tone creates intrinsic motivation
9. Mechanical enforcement (tool restriction) over prompt-based restriction
10. Format constraints are the strongest measured lever for output quality
11. Front-load critical constraints and repeat near the output template
12. Be honest about evidence levels: Quantified > Observed > Ablation > Folk knowledge > Theoretical
