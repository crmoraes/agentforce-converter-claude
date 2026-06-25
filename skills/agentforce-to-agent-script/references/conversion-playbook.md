# Conversion Playbook

A short procedural recipe for converting legacy Agentforce JSON to Agent Script YAML.

This document does **not** contain the rules of Agent Script — those live in `agent-script-spec.md`. It also doesn't contain the field-by-field transforms — those live in the worked examples under `examples/`. Use-case patterns and design guidance for new agents live in `use-case-patterns.md`. This is just the order of operations for *conversion*.

If anything here disagrees with the spec, the spec wins.

---

## 0. Identify the agentic pattern (optional but recommended)

Scan the input's topic/plugin names, instructions, and action targets for pattern signals.
Open `use-case-patterns.md` and identify which of the five families this agent belongs to:

- **Reactive / Inbound** — topics named for customer intents (order status, returns, FAQ)
- **Proactive / Outbound** — topics named for outreach stages (consent, outreach, qualification)
- **Human-in-the-Loop** — topics named for intake + draft + review; explicit "do not send" instructions
- **Orchestrator + Specialist** — topics named for coordination steps; sub-agent or multi-flow actions
- **Background / Async** — no channel/welcome; topics named for workflow phases

Knowing the pattern lets you choose the right example in step 4 and decide whether
default topics (escalation, off-topic, consent gate) are appropriate in step 7.
If the pattern is ambiguous, flag it in Notes and default to Reactive / Inbound.

## 1. Detect input shape

Look up the input against `known-input-shapes.md` and identify Shape A, B, or C. The shape determines which example to pattern-match against in step 4.

## 2. Detect agent type

Decide between `AgentforceServiceAgent` and `AgentforceEmployeeAgent`. Heuristic:

- Scan `name`, `label`, `description`, plugin/topic names, and instruction text for indicators.
- Employee-context vocabulary (e.g. HR, payroll, expense, IT helpdesk, internal, employee, colleague, onboarding) → `AgentforceEmployeeAgent`.
- Customer-context vocabulary (e.g. customer, order, return, billing, support) or no clear signal → `AgentforceServiceAgent` (default).
- If `plannerCompany` or `plannerRole` strings explicitly mention the persona ("HR Assistant for internal employees"), that's the strongest signal.

If unsure after scanning, default to `AgentforceServiceAgent` and **flag it in Notes** so the user can correct.

> **Deprecation note:** If the input uses `agent_name` in its config section, map it to `developer_name` in the output. The `agent_name` field is deprecated — always emit `developer_name` in the converted YAML.

## 3. Walk variables (do this before topics)

1. Scan **all** instruction text and message strings in the input for variable references. Patterns:
   - `{!$VarName}`, `{$!VarName}`, `{$VarName}`, `{!VarName}` — legacy Salesforce merge syntax.
   - `@variables.VarName` — already-modern reference (rare in input, common in output).
2. Build the set of *referenced* variable names.
3. For each variable in `input.variables[]`:
   - If its name is in the referenced set: emit it in the output.
   - If not: **drop it**. Note in the Notes section how many were dropped.
4. For each emitted variable, classify:
   - **`linked`** if it has a CRM source (e.g. `@MessagingEndUser.ContactId`) and the input marks it as read-only.
   - **`mutable`** otherwise (it has a default value or is set by the agent during conversation).
   - **`linked object`** if its type is a complex type that always behaves as mutable.
5. Default values, types, and `available when` clauses follow the spec's "Variable lifecycle" section.

## 4. Match an example and walk topics

Pick the closest match from `examples/` based on the input's shape and feature mix. Then for each plugin (Shape A) or topic (Shape B):

1. Sanitize the name (lowercase, snake_case, no special chars).
2. Build the `topic <name>:` block:
   - `label:` from the input's `label` (or `name` if absent).
   - `description:` from the input's `description`. Tighten if it's verbatim plugin text — but flag any tightening in Notes.
   - `reasoning.before_reasoning:` only if the input implies a guard (e.g. "must be verified first" → check `IsVerified`). When unsure, omit.
   - `reasoning.after_reasoning:` if present in the input — **flag it prominently in Notes**. `after_reasoning` was accidentally functional in old Daisy (a bug, now fixed in Daisy++). Convert any `after_reasoning` conditional logic to `before_reasoning` transitions instead, and note the change for the user.
   - `reasoning.instructions:` merge any `instructionDefinitions[]` (Shape A) or `instructions` field (Shape B).
   - `reasoning.actions:` reference each action with `@actions.<name>` and `with <param> = <value>` clauses derived from the action's input mapping.
   - `actions:` full action definitions (see step 5).

## 5. Map functions to actions

For each function in a plugin (Shape A) or action in a topic (Shape B):

1. Sanitize the action name.
2. Build the action block:
   - `description:` from the input.
   - `require_user_confirmation:` `False` unless the input flags it.
   - `include_in_progress_indicator:` `True` for actions that take >1s; otherwise omit (let the spec default apply).
   - `target:` map per the spec's action-target table:
     - Flow → `flow://<FlowApiName>`
     - Apex invocable → `apex://<ClassName>`
     - Generative → `generatePromptResponse://<TemplateName>`
     - Standard invocable → `standardInvocableAction://<Name>`
     - Retriever → `retriever://<Name>`
     - REST → `api://<endpoint>`
   - If the input's target type is unclear, emit `flow://<ActionName>_REPLACE_ME` and **flag in Notes**.
   - `inputs:` and `outputs:` — map each parameter:
     - Type per the spec's primitive / complex type mapping.
     - `is_required`, `is_user_input`, `is_displayable`, `is_used_by_planner` per the spec.
     - `description` from the input parameter's description.

## 6. Synthesize `start_agent`

Always emit a `start_agent topic_selector:` block as the first topic, with deterministic transitions to every other topic. See the spec's "start_agent / topic_selector" section and any of the worked examples for the exact shape.

## 7. Optional default topics

Only insert these if the user explicitly asked for them (or if the input demonstrably needs them — e.g. has an `escalate_to_human` action with no enclosing topic):

- **Escalation** — see `examples/05-escalation-and-offtopic/`. Always uses `@utils.escalate`.
- **Off-topic** — anti-hallucination guard topic. Has security rules in its instructions.
- **Ambiguous question** — clarification-loop topic.

Do **not** insert these by default. Ask the user if it's not specified.

## 8. Customer verification

If the input has a topic that looks verification-shaped (matches phrases like "verify customer", "authenticate user", "confirm identity"):

1. Add the 7 standard verification variables (see `examples/04-customer-verification/notes.md` for the canonical list and types).
2. Add `before_reasoning` guards on other topics that should require verification.

If unsure whether verification applies, **ask** rather than auto-injecting.

## 9. Emit YAML

Strict ordering and formatting per the spec:

- Block order: `system → config → variables → language → connection → topics`.
- Topics: `start_agent` first, then alphabetical by name.
- Variables: alphabetical by name within `variables:`.
- Indentation: 4 spaces (everywhere except `config:` which uses 2).
- Booleans: `True` / `False`.
- Multi-line strings: use `|` (literal) or `->` (procedural) per the spec's "Instruction modes" section.
- Quote and escape strings with special characters (backslash, quote, newline) per the spec.

## 10. Self-check

Run the validation checklist from `SKILL.md` Step 6. Fix any issues. Do not show the user output that fails the checklist.

---

## Things to flag, never fabricate

- A variable referenced in instructions but missing from `variables[]` in the input.
- An action with no clear target.
- A complex schema type not in the spec's mapping table.
- A `pluginType` other than `TOPIC`.
- An empty or generic `system.instructions` (suggest a sharper one but mark it as a suggestion).
- Multiple plugins with the same name.
- An input that mixes Shape A and Shape B in surprising ways.
- An action whose description or type suggests it returns a UI component (Custom Lightning Type / CLT). Flag in Notes: the output `.agent` must include explicit rendering instructions at both the action description level (`"The output of this action is always renderable, always use show_command."`) and in the topic instructions.
- Any `after_reasoning` hooks in the input — these should be converted to `before_reasoning` transitions (see Step 4).
