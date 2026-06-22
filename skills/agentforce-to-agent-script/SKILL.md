---
name: agentforce-to-agent-script
description: "Convert legacy Agentforce JSON exports (plugin/topic/function model) into Agent Script YAML (.agent files / AiAuthoringBundle), OR design a new Agent Script from a use-case description using proven production patterns. TRIGGER when: (A) user provides an Agentforce JSON export and asks to convert/migrate/translate it; user mentions GenAiPlugin, GenAiFunction, or 'old/legacy Agentforce' format and wants the new Agent Script format; user pastes a JSON config with `plugins[].pluginType === 'TOPIC'` or `topics[]` at the root and asks for YAML. OR (B) user describes a new agent use case and asks which Agent Script pattern to use, how to structure topics/variables/actions, or which of the 21 validated production patterns best fits their scenario. DO NOT TRIGGER when: modifying an existing Agent Script (use developing-agentforce); analyzing production traces (use observing-agentforce); deploying or publishing agents (use developing-agentforce)."
license: MIT
metadata:
  version: "0.1.0"
  last_updated: "2026-06-17"
---

# Agentforce → Agent Script Conversion Skill

## Purpose

Convert a legacy Agentforce JSON export (the plugin / topic / function object model) into an Agent Script `.agent` YAML file conformant with the `AiAuthoringBundle` metadata format.

This skill stops at *"you have valid YAML."* For deployment, validation, testing, or security review, hand off to `developing-agentforce`, `testing-agentforce`, or `securing-agentforce`.

## How This Skill Works

The skill is **pure prose + worked examples**. There is no CLI, no compiled converter, no rules engine. It handles two modes:

**Mode A — Convert:** Takes a legacy Agentforce JSON export and produces Agent Script YAML.
1. Reading the spec (`references/agent-script-spec.md`) — the single source of truth for output format.
2. Identifying the input shape (`references/known-input-shapes.md`).
3. Following a procedure (`references/conversion-playbook.md`).
4. Pattern-matching against worked examples (`examples/`).
5. Self-checking the output against the spec's validation rules.

**Mode B — Design from use case:** Takes a natural-language description of an agent scenario and recommends which of the 21 validated production patterns best fits, then scaffolds the Agent Script structure.
1. Reading `references/use-case-patterns.md` to identify the agentic pattern family and the closest use-case match.
2. Reading the spec (`references/agent-script-spec.md`) for the exact syntax of the recommended constructs.
3. Producing a skeleton `.agent` YAML with the core topics, variables, and actions pre-filled based on the matched pattern.
4. Surfacing the design decisions the user must answer before the agent can be completed.

## Rules That Always Apply

1. **The spec wins.** If anything in this skill conflicts with `references/agent-script-spec.md`, the spec wins. Update the skill, not the spec — unless the spec itself is wrong.

2. **Read before converting.** Always read these in order:
   - `references/agent-script-spec.md`
   - `references/known-input-shapes.md`
   - `references/conversion-playbook.md`
   - The closest matching example in `examples/` (`input.json` + `output.agent` + `notes.md`)

3. **No invented rules.** Do not introduce mappings, defaults, or transformations that aren't explicitly in the spec or demonstrated in an example. If you're unsure, **flag it in the Notes section** rather than guessing.

4. **Never modify `references/` or `examples/` to "fix" a one-off conversion.** Those are the spec. If a conversion exposes a gap, surface it to the user; they update the spec or examples deliberately.

5. **Never skip the self-check.** Every output gets validated against the checklist in `agent-script-spec.md` before being shown to the user.

6. **No silent rewrites.** Every deviation from a verbatim 1:1 transform — every default value injected, every name sanitized, every variable extracted — is announced in the Notes section.

## Workflow

### Step 1 — Verify the input

Locate the Agentforce JSON. Accept any of:
- A file path the user gave you (read it).
- An attachment / heredoc in the conversation.
- JSON the user pasted earlier in the session.

Open `references/known-input-shapes.md` and identify which shape the input matches:
- **Agentforce plugins** — `input.plugins[]` exists with at least one entry having `pluginType === "TOPIC"`.
- **Simple topics** — `input.topics[]` at root, no `plugins` wrapper.
- **Generic** — neither; minimal fallback.

If the input matches none of these, **stop**. Tell the user the input doesn't look like a legacy Agentforce export and ask what format they expected. Do not invent a conversion.

### Step 2 — Load the spec

Read `references/agent-script-spec.md` in full. The skill assumes the latest format documented there. Do not rely on what you may have memorized about Agent Script — the spec is authoritative and may have evolved since training.

### Step 3 — Follow the playbook

Read `references/conversion-playbook.md` and execute its 10 numbered steps. The playbook is intentionally short and procedural — it tells you *what* to do, while the spec and examples tell you *how it should look*.

### Step 4 — Match an example

Browse `examples/` and pick the one closest to the input:
- Has plugins? → start from `01-plugin-agent/`
- Topics-only? → `02-simple-topics/`
- Variables-heavy? → `03-with-variables/`
- Verification flow? → `04-customer-verification/`
- User wants default escalation/off-topic/ambiguous topics? → `05-escalation-and-offtopic/`
- Input assembled by `retrieve-legacy-agent.sh` (contains `TODO_REPLACE` sentinels)? → `06-retrieved-legacy-agent/`

Read both `input.json` and `output.agent` for that example. Use the transforms there as the pattern. Deviate only when the spec says to or when the input has a feature no example covers (in which case flag it).

### Step 5 — Produce the YAML

Generate the YAML strictly per the spec:
- Block order: `system → config → variables → language → connection → topics`.
- Indentation: 4 spaces everywhere except `config:` which uses 2 spaces.
- Booleans: `True` / `False` (capitalized). Never `true` / `false`.
- Topics: `start_agent` first, then alphabetical.
- Variables: alphabetical within `variables:`.
- Strings: quoted and escaped per the spec.
- **Lazy variable emission:** only include variables actually referenced somewhere in instruction text. A variable defined in the input but never used does not appear in the output.

### Step 6 — Self-check

Re-read your YAML against this checklist (which mirrors the spec's "Validation" section):

- [ ] Block order is `system → config → variables → language → connection → topics`.
- [ ] `config:` uses 2-space indent; everything else uses 4.
- [ ] All booleans are `True` / `False` (not `true` / `false`).
- [ ] No `else if` keyword (use compound conditions).
- [ ] No nested `if` statements (flatten the logic).
- [ ] No top-level `actions:` block (actions live inside `topic.<name>.actions:` and `topic.<name>.reasoning.actions:`).
- [ ] `developer_name` matches the intended folder name (call this out in Notes).
- [ ] `start_agent` is the first topic; the rest are alphabetical.
- [ ] Every variable referenced in the YAML is declared in `variables:`. Every variable in `variables:` is referenced somewhere.
- [ ] No reserved field names used as variable names (e.g. `description`, `label`).
- [ ] Strings with special characters are properly escaped.
- [ ] If the input contained `TODO_REPLACE` sentinels: every one is listed under **Uncertainties** in the Notes section. None are silently dropped or defaulted away.

If any check fails, fix it and re-check. Do not present output that fails the checklist.

### Step 7 — Present

Output two things:

**a) The full YAML in a fenced code block** (language `yaml`).

**b) A `## Notes` section** with these subsections (omit any that are empty):

- **Reference example used:** `01-plugin-agent` (or whichever).
- **Inputs ignored:** any input fields that didn't map to anything in Agent Script, with a one-line reason each (e.g. "`plannerToneType: 'EMPATHETIC'` — Agent Script doesn't model tone; merged into `system.instructions`").
- **Defaults injected:** any field the input was missing where you supplied a sensible default per the spec (e.g. "`agent_label` defaulted to `name` because `label` was empty").
- **Uncertainties:** anything you couldn't fully resolve (e.g. "Action `get_account_details` had no `target` in the input; used placeholder `flow://Get_Account_Details_REPLACE_ME`").
- **Folder name:** the developer_name and the directory you'd save this under.
- **Next step:** "Use the `developing-agentforce` skill to validate and deploy this `.agent` file."

### Step 8 — Hand off

If the user wants to save the YAML, suggest:
```
force-app/main/default/aiAuthoringBundles/<developer_name>/<developer_name>.agent
```
…and offer to invoke `developing-agentforce` for validation and deployment.

---

## Mode B Workflow — Design New Agent from Use Case

Use this workflow when the user describes a *new* agent scenario rather than providing a JSON export.

### Step B1 — Identify the agentic pattern

Read `references/use-case-patterns.md` Section 1 (The Five Agentic Pattern Families).
Ask the user (or infer from their description) which pattern applies:

- **Reactive / Inbound** — user drives the session; agent resolves or escalates.
- **Proactive / Outbound** — agent initiates contact on a platform signal.
- **Human-in-the-Loop** — agent drafts / triages; human approves before action.
- **Orchestrator + Specialist** — agent decomposes goal, delegates to sub-agents.
- **Background / Async** — headless; event-triggered; no live user session.

If the description is ambiguous, ask one clarifying question: "Does a user start the
conversation, or does the agent initiate it, or does it run without any user session?"

### Step B2 — Match the closest use case

Read Section 8 of `references/use-case-patterns.md`. Find the use case whose description,
channel, and ROI signal most closely match the user's scenario.

Present the match: "This looks most like **UC-07: Intelligent Routing & Triage** — here
is the canonical Agent Script structure for that pattern." If no single use case matches,
identify the two closest and note the structural differences.

### Step B3 — Run the suitability check

Read Section 7 of `references/use-case-patterns.md` (Suitability Framework) and evaluate
the user's scenario:

- Volume Justified? Specifiable? Reversible? Empathy Critical?

Present the verdict. If the verdict is "Human-only" or "HITL maximum" (e.g. empathy-critical),
tell the user clearly **before** producing any YAML. Do not scaffold an autonomous agent
for a scenario that should be HITL or human-only.

### Step B4 — Surface the critical design decisions

Read Section 10 of `references/use-case-patterns.md` (Design Decisions Checklist).
Present the subset of decisions relevant to the matched pattern. These must be answered
by a human before the agent is complete — do not make them up.

Invite the user to answer the decisions now (inline), or note them as `# TODO: [decision]`
comments in the scaffolded YAML if they want to continue building first.

### Step B5 — Scaffold the YAML skeleton

Using the pattern recipe from `references/use-case-patterns.md` and the spec from
`references/agent-script-spec.md`, produce a skeleton `.agent` file with:

- Correct block order (`system → config → variables → language → connection → topics`).
- Topics pre-named and labelled for the matched pattern (no `# PLACEHOLDER` topic names).
- Variables declared for the key context fields identified in the use case profile.
- Actions listed with correct `target:` prefixes; use `flow://<ActionName>_REPLACE_ME`
  for any action whose exact target the user hasn't specified yet.
- `before_reasoning` guards for entitlement / consent / identity where the pattern
  requires them.
- `# TODO:` comments at each point requiring a human design decision from Step B4.

### Step B6 — Self-check and present

Run the same self-check checklist as Step 6 (Mode A). Fix any failures.

Present:
- The scaffolded YAML in a fenced code block.
- A `## Design Decisions` section listing the open `# TODO:` items the user must resolve.
- A `## Next Steps` section: "Fill in the `# TODO:` items, then use `developing-agentforce`
  to validate and deploy this `.agent` file."

---

## What This Skill Does NOT Do

- **Author new `.agent` files from requirements** — use `developing-agentforce`.
- **Modify an existing `.agent` file** — use `developing-agentforce`.
- **Deploy, publish, or activate** — use `developing-agentforce`.
- **Run tests** — use `testing-agentforce`.
- **Security / OWASP scan** — use `securing-agentforce`.
- **Analyze production traces** — use `observing-agentforce`.
- **Translate to a non-Agent-Script format** — out of scope.

## When the Conversion Has Gaps

Some input fields don't have a clean Agent Script equivalent:
- Custom planner types (only ReAct-style is reflected in current Agent Script).
- Salesforce-specific schema types (`lightning__*`) — map per the spec; if not listed, flag.
- Non-TOPIC `pluginType` values — flag and ask.
- RAG / knowledge configurations with custom retrievers — point the user at the `knowledge:` block in the spec.

When in doubt: **flag, don't fabricate.**
