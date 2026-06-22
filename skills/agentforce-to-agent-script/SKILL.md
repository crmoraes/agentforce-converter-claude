---
name: agentforce-to-agent-script
description: "Convert legacy Agentforce JSON exports (plugin/topic/function model) into Agent Script YAML (.agent files / AiAuthoringBundle). TRIGGER when: user provides an Agentforce JSON export and asks to convert/migrate/translate it; user mentions GenAiPlugin, GenAiFunction, or 'old/legacy Agentforce' format and wants the new Agent Script format; user pastes a JSON config with `plugins[].pluginType === 'TOPIC'` or `topics[]` at the root and asks for YAML. DO NOT TRIGGER when: authoring a new .agent from requirements (use developing-agentforce); modifying an existing Agent Script (use developing-agentforce); analyzing production traces (use observing-agentforce)."
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

The skill is **pure prose + worked examples**. There is no CLI, no compiled converter, no rules engine. Conversion happens by:

1. Reading the spec (`references/agent-script-spec.md`) — the single source of truth for output format.
2. Identifying the input shape (`references/known-input-shapes.md`).
3. Following a procedure (`references/conversion-playbook.md`).
4. Pattern-matching against worked examples (`examples/`).
5. Self-checking the output against the spec's validation rules.

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
