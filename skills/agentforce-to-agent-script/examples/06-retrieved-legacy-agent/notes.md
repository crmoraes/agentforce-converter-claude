# Example 06 — Retrieved Legacy Agent (CLI-assembled input)

## What this demonstrates

Input assembled by `scripts/retrieve-legacy-agent.sh` + `scripts/assemble_legacy_agent.py`
rather than exported from the planner UI. This is the Shape A JSON you get when the
conversion skill is fed a CLI-retrieved agent — it is structurally identical to Shape A
but has two characteristics that don't appear in planner-UI exports:

1. **`TODO_REPLACE` sentinels** in fields that couldn't be derived from XML metadata
   (`plannerRole`, `plannerCompany`, and any function whose XML was missing from the org).
2. **Salesforce-ID suffixes** on plugin names (`Order_Status_16jKc0000004Cqw`) — the
   assembler strips these to produce `localDevName`, but the raw `name` field retains them.

## Key transforms shown

| Input field | Output location | Notes |
|---|---|---|
| `name` (`Solar_Support_Agent`) | `config.developer_name` | |
| `label` | `config.agent_label` | |
| `description` | `config.description` | |
| `plannerRole` (TODO_REPLACE) | `system.instructions` | Merged with plannerCompany; TODO preserved in output so the user is forced to fill it in |
| `plannerCompany` (TODO_REPLACE) | `system.instructions` | See above |
| `welcomeMessage` | `system.messages.welcome` | |
| `locale` | `language.default_locale` | `secondaryLocales` was empty → `additional_locales` omitted |
| `plugins[].localDevName` | `topic <name>:` key | Suffix-stripped name used, not the raw `name` field |
| `plugin.scope` + `instructionDefinitions[]` | `reasoning.instructions` | Concatenated in order |
| `plugin.functions[]` | `topic.<name>.actions:` | |
| `canEscalate: true` on Escalation plugin | `@utils.escalate` in topic instructions | No explicit escalation action → use `@utils.escalate` directly |
| `variables: []` (empty) | `variables:` block omitted | No variables to declare |

## Things to notice

- **`TODO_REPLACE` in `system.instructions`** — the output carries the sentinel into the
  YAML verbatim (inside a comment bracket). This is intentional: it forces the deploying
  engineer to fill in the persona text before the agent goes live. The conversion skill
  must flag this in its Notes output as an **Uncertainty**.

- **Missing function XML** — the Escalation topic's function (`EscalateToAgent`) had
  `TODO_REPLACE_EscalateToAgent` as its `invocationTarget` (assembler couldn't find its
  XML). The conversion skill replaces this with `@utils.escalate` because the plugin has
  `canEscalate: true` — this is the correct resolution pattern for escalation topics with
  missing function targets.

- **Plugin name suffix** — `Order_Status_16jKc0000004Cqw` normalises to `order_status`
  as the topic key. The Salesforce ID portion is never carried into the output YAML.

- **Empty `variables[]`** — retrieved metadata rarely contains variable declarations
  (they live in the Bot runtime config, not in GenAiPlugin XML). The output has no
  `variables:` block. If the original agent used context variables, they must be added
  manually after conversion — flag this in Notes.

## Folder name vs. developer_name

The folder is named `06-retrieved-legacy-agent` for example navigation.
The `developer_name` in the output is `Solar_Support_Agent`.
These do not match — **this is intentional for all teaching examples**.

When saving a real conversion output, the path must be:
```
force-app/main/default/aiAuthoringBundles/Solar_Support_Agent/Solar_Support_Agent.agent
```

## Safety review note

This example contains `TODO_REPLACE` sentinels in `system.instructions`. Before
deploying to production, the `[TODO_REPLACE: ...]` placeholder must be replaced with
real persona text, and the file must pass the safety review in Section 15 of the
`developing-agentforce` skill. The example output intentionally leaves the sentinel
visible so engineers are forced to confront it — a blank or placeholder persona
bypasses the safety review's ability to detect impersonation, manipulation, or
proxy-discrimination risks hidden in persona framing.

## Things flagged (would be in Notes)

- `plannerRole` and `plannerCompany` — both `TODO_REPLACE`; input assembled from XML
  which does not carry these fields. User must supply persona text before deploying.
- `EscalateToAgent` function — XML not found; resolved to `@utils.escalate` because
  `canEscalate: true` on the Escalation plugin.
- `variables[]` empty — if the original agent used context variables (e.g. ContactId),
  they must be declared manually. Check the org's Bot runtime config.
- `default_agent_user` — synthesised placeholder; replace with the real agent user
  username before deploying.
- `secondaryLocales` empty — `additional_locales` omitted from output.
