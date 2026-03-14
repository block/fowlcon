# Agentic Restart Patterns (Ralph Wiggum Loop)

**Context:** Fowlcon's fresh-start mode wipes per-PR state and restarts with distilled learnings. This is an instance of the "write → evaluate → restart with learnings" pattern.

## The Pattern

An agent produces output, evaluates it (or has it evaluated), determines it's inadequate, and restarts carrying forward what it learned. The key design question: how are learnings carried between iterations?

## Three Approaches

### 1. In-Context Accumulation (Self-Refine)

Prior outputs, critiques, and revisions stay in the same conversation. The model sees everything.

**Academic basis:** Self-Refine (Madaan et al., NeurIPS 2023)

**Works for:** Short tasks where the full history is useful to the refiner.

**Breaks down:** Context rot degrades quality as context fills up, even well within token limits. A Chroma study found all 18 tested LLMs showed degradation. Models advertised at 200K tokens became unreliable around 130K.

### 2. Distilled Verbal Reflection (Reflexion)

Failures are summarized into natural-language lessons stored in a bounded memory buffer (1-3 entries). The full trajectory is discarded; only the distilled lesson is carried forward.

**Academic basis:** Reflexion (Shinn et al., NeurIPS 2023) -- 91% pass@1 on HumanEval vs 80% GPT-4 baseline.

**Works for:** Tasks with clear success/failure criteria. The reflection captures why the attempt failed, not the full attempt.

**Breaks down:** Lossy by design. Nuance in the failed trajectory may be lost in the summary.

### 3. External State (Ralph Loop / Filesystem)

State lives entirely outside the LLM: git history, markdown files, JSON task trackers. Each iteration spawns a fresh context that reads external state. No context rot.

**Origins:** Coined by Geoffrey Huntley and Ryan Carson in the Claude Code community. Named after Ralph Wiggum ("iterating repeatedly and not giving up").

**Works for:** Long-running tasks where context rot is the enemy. Each iteration gets maximum cognitive clarity.

**How it works:**
- A loop repeatedly invokes a fresh agent with the same prompt
- State lives on the filesystem (git commits, progress files, hint files)
- Each iteration reads world state from files rather than remembering it
- Failed attempts leave traces via git history and accumulated hints

## Critical Finding: Self-Correction Requires External Feedback

Huang et al. (ICLR 2024) showed that **intrinsic self-correction** (the model critiquing itself without external feedback) does not improve and often degrades performance. The methods that work (Reflexion, CRITIC, Ralph Loop) all depend on external signals: test results, tool output, or human feedback.

**Implication for Fowlcon:** The customer is the external evaluation signal in Fowlcon's restart loop. Their feedback ("the config section grouping was confusing") is what makes the fresh start meaningful. Without external feedback, restarting just repeats the same mistakes.

## How Fowlcon Uses This

Fowlcon's fresh-start mode is approach #3 (External State):

- `fresh-start-context.md` carries distilled learnings from the previous attempt
- Per-PR cache gets wiped (the failed state is discarded)
- The orchestrator restarts with a clean context window
- The hints inform but don't constrain the new analysis

The customer triggers fresh start explicitly. The orchestrator generates the context file (with customer approval) before wiping.

## Related Patterns

- **AlphaCodium** (Ridnik et al., 2024): Test-anchored iteration -- passing tests become fixed anchors, preventing regression. Similar to Fowlcon's "reviewed nodes survive fresh start as hints."
- **LATS** (Zhou et al., ICML 2024): Tree-structured restart -- backtrack to best-known state and try a different path. More sophisticated than linear restart.
- **Context rot** as a named phenomenon: LLM performance degrades as context fills. The Ralph Loop is partly a solution -- restart fresh, externalize state.

## Sources

- [Reflexion: Language Agents with Verbal Reinforcement Learning](https://arxiv.org/abs/2303.11366) (Shinn et al., NeurIPS 2023)
- [Self-Refine: Iterative Refinement with Self-Feedback](https://arxiv.org/abs/2303.17651) (Madaan et al., NeurIPS 2023)
- [Large Language Models Cannot Self-Correct Reasoning Yet](https://arxiv.org/abs/2310.01798) (Huang et al., ICLR 2024)
- [CRITIC: LLMs Can Self-Correct with Tool-Interactive Critiquing](https://arxiv.org/abs/2305.11738) (Gou et al., ICLR 2024)
- [Language Agent Tree Search](https://arxiv.org/abs/2310.04406) (Zhou et al., ICML 2024)
- [Code Generation with AlphaCodium](https://arxiv.org/abs/2401.08500) (Ridnik et al., 2024)
- [From ReAct to Ralph Loop](https://www.alibabacloud.com/blog/from-react-to-ralph-loop-a-continuous-iteration-paradigm-for-ai-agents_602799) (Alibaba Cloud)
- [Self-Improving Coding Agents](https://addyosmani.com/blog/self-improving-agents/) (Addy Osmani)
- [Context Engineering for AI Agents](https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus) (Manus)
