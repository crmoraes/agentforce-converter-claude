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
