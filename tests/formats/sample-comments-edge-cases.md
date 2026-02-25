# Review Comments: Edge Case Test Fixture

| Field       | Value |
|-------------|-------|
| PR          | hawksbury/hawksbury#99 |
| HEAD        | deadbeefdeadbeefdeadbeefdeadbeefdeadbeef |

## Comments

### C1
node: 1.1
type: inline
status: active
source: reviewer
file: hawksbury/core/src/main/java/com/hawksbury/legacy/RoostGuard.java
lines: L19-40
side: right
tree_rev: 1
created: 2026-02-25T10:00:00Z

Emoji test: This looks good 👍 but the error handling needs work 🔥
The ✅ approved pattern should use ❌ rejection instead.
Unicode arrows: → ← ↑ ↓ and bullets: • ◦ ▪

### C2
node: 1.2
type: inline
status: active
source: reviewer
file: hawksbury/core/src/main/java/com/hawksbury/legacy/RoostMode.java
lines: L1-7
side: right
tree_rev: 1
created: 2026-02-25T10:05:00Z

Code block in comment body:
```java
if (mode == RoostMode.BLOCK) {
    throw new UnsupportedOperationException("blocked");
}
```
The above should use `RoostMode.CHIRP` first for gradual rollout.

### C3
node: root
type: top-level
status: active
source: reviewer
tree_rev: 1
created: 2026-02-25T10:10:00Z

Markdown formatting test:
- **Bold** and *italic* and ~~strikethrough~~
- [Link text](https://example.com/path?query=value&other=123#fragment)
- `inline code` with special chars: `$HOME/.config`

#### This is an h4 heading in the body

> Blockquote with a note about the PR

| Column A | Column B |
|----------|----------|
| value 1  | value 2  |

### C4
node: 2.1
type: inline
status: active
source: reviewer
file: service/src/main/java/com/hawksbury/sanctuary/v2/CloseNestAppApi.java
lines: L38-38
side: right
tree_rev: 1
created: 2026-02-25T10:15:00Z

Body with metadata-like lines (these should NOT be parsed as metadata):

node: 9.9.9
type: something
file: /etc/passwd
lines: L1-999
side: left
status: deleted
created: 1999-01-01T00:00:00Z

The above lines look like metadata but they're in the body (after the blank
line separator). A correct parser should not be confused by them.

### C5
node: 3.1
type: inline
status: active
source: reviewer
file: service/src/main/java/com/hawksbury/sanctuary/v2/GetFlockProfileAppApi.java
lines: L11-11
side: right
tree_rev: 1
created: 2026-02-25T10:20:00Z

Non-ASCII text: café résumé naïve über straße
CJK: 这是一个测试 テスト 테스트
Arabic: مرحبا
Empty lines in body are fine:

Like this one above.

And trailing whitespace should not matter.
