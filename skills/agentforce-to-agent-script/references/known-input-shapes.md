# Known Input Shapes

Three shapes of legacy Agentforce JSON the skill recognizes. Identify which one the input matches before doing anything else.

## Shape A — Agentforce plugins (most common)

**Discriminator:** `input.plugins` is a non-empty array, and at least one entry has `pluginType === "TOPIC"`.

**Top-level fields that matter:**
- `name`, `label`, `description` — agent identity
- `plannerRole`, `plannerCompany`, `plannerToneType` — persona; merge into `system.instructions`
- `locale`, `additionalLocales[]` — `language:` block
- `welcomeMessage` — `system.messages.welcome`
- `plugins[]` — each plugin with `pluginType === "TOPIC"` becomes a `topic <name>:` block
- `plugins[].functions[]` — each function becomes an action under that topic
- `plugins[].instructionDefinitions[]` — merged into the topic's `reasoning.instructions`
- `variables[]` — candidate variables (only emitted if referenced)

**Canonical example:** `examples/01-plugin-agent/`

**Watch out for:**
- Plugins with `pluginType !== "TOPIC"` (e.g. `"FLOW"`, `"APEX"`) — flag, don't auto-map.
- Functions with no `target` — emit a placeholder `target:` and flag it in Notes.
- `instructionDefinitions[]` containing scoping text vs. behavior text — both end up in `reasoning.instructions`, concatenated in the order they appear.

---

## Shape B — Simple topics

**Discriminator:** `input.topics` is a non-empty array at the root, and either (a) no `plugins` wrapper, or (b) `plugins` is empty/absent.

**Top-level fields that matter:**
- Same identity / locale / variables fields as Shape A.
- `topics[]` — each becomes a `topic <name>:` block directly (no plugin wrapper).
- `topics[].actions[]` — each becomes an action under that topic.
- `topics[].instructions` — `reasoning.instructions`.

**Canonical example:** `examples/02-simple-topics/`

**Watch out for:**
- Topics with the same name (rare) — sanitize by appending an index and flag.

---

## Shape C — Generic / minimal

**Discriminator:** Neither `plugins[]` nor `topics[]` exists. Has only top-level identity fields, possibly `variables[]`, possibly `welcomeMessage`.

**Result:** A minimal `.agent` with `system`, `config`, `language`, and a single empty placeholder `start_agent topic_selector:` topic. Flag prominently that no topics were derivable from the input.

**Canonical example:** none seeded — rare in practice. If you encounter one, ask the user whether they want to keep going or go back and provide a richer export.

---

## Disambiguation rules

If the input matches **both** Shape A and Shape B (it has `plugins[]` AND `topics[]` at root): treat as **Shape A**. The `plugins[]` array drives topic creation; root `topics[]` is ignored unless it adds new topics not represented in plugins.

If `plugins[]` exists but no entry has `pluginType === "TOPIC"`: treat as Shape C and flag every plugin as "ignored — non-TOPIC plugin type."

## Other variations

- **YAML input** — the spec accepts YAML-formatted Agentforce exports. Parse as YAML, then apply the same shape detection on the parsed object.
- **Wrapped in metadata envelope** — some exports wrap the agent in `{ "Agent": { ... } }` or `{ "metadata": { ... } }`. Unwrap to get the actual agent object before shape detection.

---

## Shape D — CLI-assembled (retrieved from org via retrieve-legacy-agent.sh)

**Discriminator:** `input.plugins[]` exists with `pluginType === "TOPIC"` entries (same as
Shape A), **and** one or more fields contain the string `"TODO_REPLACE"`.

**Source:** JSON produced by `scripts/assemble_legacy_agent.py` from retrieved
`GenAiPlugin` and `GenAiFunction` XML metadata. Structurally identical to Shape A — use
the same conversion path. The `TODO_REPLACE` sentinels require special handling.

**Fields that commonly carry `TODO_REPLACE`:**

| Field | Why it's missing | What to do |
|---|---|---|
| `plannerRole` | Not stored in GenAiPlugin XML; lives in Bot runtime config | Ask the user for the agent's persona/role description |
| `plannerCompany` | Same — not in retrieved XML | Ask the user for the company context |
| `function.invocationTarget` | Function XML not found in org (may be deleted or from a managed package) | Emit `flow://<name>_REPLACE_ME` and flag in Notes |

**Plugin name suffixes:** Plugin `name` fields end with a Salesforce record ID
(`Order_Status_16jKc0000004Cqw`). Use `localDevName` (already stripped by the assembler)
as the topic key, not `name`. If `localDevName` is absent, strip the trailing
`_[A-Za-z0-9]{15,18}` pattern from `name`.

**Canonical example:** `examples/06-retrieved-legacy-agent/`

**Conversion rules specific to Shape D:**

1. Every `TODO_REPLACE` value must be flagged in the Notes output — never silently
   substitute a default. The deploying engineer must fill these in before the agent
   is live.
2. A `TODO_REPLACE` in `plannerRole` / `plannerCompany` → carry the sentinel into
   `system.instructions` inside a comment bracket so it's visible in the output YAML:
   `"[TODO_REPLACE: insert agent persona and company context here]"`.
3. An `escalation` topic with `canEscalate: true` and a `TODO_REPLACE_*` function
   → replace the function with `@utils.escalate` in the topic's instructions. This is
   the correct resolution for escalation topics whose backing Flow XML wasn't retrieved.
4. Empty `variables[]` is normal for CLI-assembled input — GenAiPlugin XML rarely
   carries variable declarations. Flag this in Notes: the user must check the org's Bot
   runtime config and add variables manually if the original agent used them.
