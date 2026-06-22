# Example 01 — Plugin Agent (canonical)

## What this demonstrates

The most common shape: a Salesforce Agentforce export with `plugins[]` at the root, each plugin of `pluginType === "TOPIC"` carrying functions and instruction definitions.

## Key transforms shown

| Input field | Output location |
|---|---|
| `name` | `config.developer_name` |
| `label` | `config.agent_label` |
| `description` | `config.description` |
| `plannerRole` + `plannerCompany` | `system.instructions` (concatenated) |
| `plannerToneType` | **dropped** — Agent Script doesn't model tone explicitly. Captured in Notes. |
| `welcomeMessage` | `system.messages.welcome` |
| `locale` + `secondaryLocales[]` | `language.default_locale` + `additional_locales` |
| `plugins[]` (TOPIC) | one `topic <name>:` block each |
| `plugin.scope` + `plugin.instructionDefinitions[]` | merged into `topic.<name>.reasoning.instructions` |
| `plugin.functions[]` | actions in `topic.<name>.actions:` |
| `function.invocationTarget` + `invocationTargetType` | `target: "<type>://<name>"` |
| `function.inputs[]` / `outputs[]` | `inputs:` / `outputs:` blocks |
| `variables[]` (only referenced ones) | `variables:` block |
| Variable `IsVerified` (defined but never referenced) | **dropped** per lazy-emission rule |

## Things to notice

- `start_agent topic_selector:` is **synthesized** from the plugin list — there's no input field for it.
- Topics are alphabetical (`order_status` then `returns`); `start_agent` is always first regardless.
- `{!$ContactId}` in input instruction text → `{!@variables.ContactId}` in output.
- `IsVerified` was in `variables[]` but never referenced anywhere — it does NOT appear in the output.
- `default_agent_user` was synthesized as `<developer_name>@acme.ext` because the input had no `userName` field; this is a placeholder the user is expected to override.

## Folder name convention

When saving this output, the path should be:
```
force-app/main/default/aiAuthoringBundles/Acme_Service_Agent/Acme_Service_Agent.agent
```
The folder name matches `config.developer_name`. The example lives in `01-plugin-agent/` as a teaching fixture — its folder name does **not** match `developer_name` because the folder name here is for example navigation, not Salesforce deployment.

## Things flagged (would be in Notes)

- `plannerToneType: "CASUAL"` — dropped; tone is implicit in `system.instructions`.
- `IsVerified` variable — defined but unused; dropped per the lazy-emission rule.
- `default_agent_user` — synthesized placeholder; user must replace with a real org user.
- `system.messages.error` — defaulted because input had no error message.
