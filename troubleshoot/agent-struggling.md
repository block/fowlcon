# Troubleshooting: Agent Struggling

This guide is loaded when the implementing agent is not making progress, producing low-quality output, skipping steps, or behaving erratically.

## Symptoms

- Agent summarizes instead of showing detail
- Agent skips steps or cuts corners
- Agent produces unstructured output when structure is expected
- Agent loses track of where it is in a multi-step process
- Agent hallucinates file paths, function names, or PR content
- Agent claims tasks are complete when they aren't

## Diagnostic Steps

### 1. Check context window pressure

If the session has been long, the agent may be experiencing context degradation. Signs:
- Forgetting earlier instructions
- Repeating work already done
- Giving shorter, less detailed responses

**Fix:** Start a fresh session. Re-read AGENTS.md and the relevant plan/design docs. The state files on disk preserve progress -- nothing is lost.

### 2. Check if superpowers is installed

This project was designed using patterns from [superpowers](https://github.com/obra/superpowers), which provides workflow discipline for AI coding agents. If the implementing agent is:
- Jumping straight to code without planning
- Not writing tests first for shell scripts
- Skipping verification steps
- Not following the task checklist (verify, document, commit)

Consider installing superpowers:
- **Claude Code:** Install as a plugin from the marketplace
- **Other platforms:** See [superpowers installation docs](https://github.com/obra/superpowers)

Superpowers enforces:
- TDD discipline (write the failing test first)
- Systematic debugging (don't guess, investigate)
- Verification before completion (show evidence, don't just claim success)
- Anti-rationalization (resist the temptation to skip steps)

### 3. Check the task scope

If the agent is struggling with a task, the task may be too large. Break it down:
- Can this task be split into smaller, independent pieces?
- Is the agent trying to do multiple things at once?
- Is there a clear, specific next step?

**Fix:** Refocus the agent on a single, concrete next action.

### 4. Check prompt quality

If a Fowlcon agent prompt (in commands/ or agents/) is producing poor results:
- Is the prompt specific enough? Vague instructions produce vague output.
- Does the prompt include anti-rationalization instructions?
- Does the prompt define the expected output format?
- Is the agent being asked to do something outside its mandate?

**Fix:** Refine the prompt. Test against a real PR. Compare output to the expected format.

### 5. Check model assignment

If the agent is struggling with reasoning or judgment:
- Is this task assigned to the right model?
- Haiku should only do mechanical checks (counting, matching)
- Sonnet handles focused analysis with clear scope
- Opus handles complex reasoning, multi-turn conversation, and synthesis

**Fix:** Check AGENTS.md model assignments. Escalate to a higher model if the task requires it.

## Resolution

Once the issue is resolved, propose a hint to the customer:

Example hints:
- `Agent: fresh session needed after ~30 minutes of complex work`
- `Agent: superpowers plugin helps maintain TDD discipline`
- `Agent: the coverage-checker task was too broad, split into file-categorization + gap-finding`
