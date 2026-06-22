# Walkthrough — From Legacy JSON to Live Agent

A step-by-step tutorial using the included sample file.

The sample at `sample/sample-agent.json` is a real Agentforce Service Agent export with four topics (Case Management, Escalation, General FAQ, General Web Search) and seven actions backed by Flows and a Prompt Template. It's a good representation of what a production agent looks like after being built in the classic Agentforce UI.

This walkthrough runs you through three paths:

- **Path A** — Conversion only (no Salesforce org needed)
- **Path B** — Full ADLC pipeline (conversion → deploy → test → security scan)
- **Path C** — Design a new agent from a use-case description (no legacy JSON needed)

---

## Prerequisites

- Claude Code installed and running
- This repo installed: `./scripts/install.sh` (see [HOWTO.md §2](./HOWTO.md))
- **Path B only:** a Salesforce org with Agentforce enabled, Salesforce CLI v2, and an Einstein Agent User configured
- **Paths A and C:** no Salesforce org required

---

## Path A — Conversion only

Use this when you want to produce an Agent Script `.agent` file from the legacy JSON, then handle deployment yourself.

There are two ways to get the input JSON. **Option A1** (CLI retrieve) is preferred for
agents still living in a connected org. **Option A2** (sample file) works without an org.

### Option A1 — Retrieve from your org (recommended)

```bash
# Authenticate first if you haven't
./scripts/org-auth.sh

# Find your agent's API name
sf data query --use-tooling-api \
  --query "SELECT DeveloperName, MasterLabel FROM GenAiPlugin LIMIT 20" \
  -o agentforce-dev

# Retrieve and assemble the Shape A JSON
./scripts/retrieve-legacy-agent.sh <Your_Agent_Name> -o agentforce-dev
# Output: legacy/<Your_Agent_Name>.json
```

Review the output file. Fields that couldn't be derived from XML carry `TODO_REPLACE`
sentinels — fill in `plannerRole` and `plannerCompany` before converting, or leave them
for the conversion skill to flag in its Notes.

Then open Claude Code and convert:

```
Use the agentforce-to-agent-script skill to convert legacy/<Your_Agent_Name>.json
```

### Option A2 — Use the included sample (no org needed)

### Step 1 — Open a Claude Code session

```bash
cd ~/Dev/agentforce-converter-claude
claude
```

### Step 2 — Run the conversion

```
Use the agentforce-to-agent-script skill to convert sample/sample-agent.json
```

Claude will:
1. Read the spec, input-shapes reference, and playbook from the skill.
2. Identify the file as **Shape A** (plugins with `pluginType === "TOPIC"`).
3. Map the four topics and seven actions to Agent Script syntax.
4. Return a `## YAML` block and a `## Notes` block.

### Step 3 — Read the Notes

The Notes section is not boilerplate — read it before doing anything with the YAML. For this sample you will see entries like:

- **Uncertainties** — two action targets (`identify_customer_by_email`, `answer_faq_question`) have Salesforce IDs as their `invocationTargetName` in the JSON, not API names. Claude emits placeholder targets and flags them. You must verify the actual Flow / Prompt Template API names in your org before deploying.
- **Defaults injected** — `default_agent_user`, welcome message, and `connection messaging` routing details are placeholders. Replace them with your org's values.
- **Inputs ignored** — runtime fields (`plannerTypeInfo`, `adlPlannerConfigurations`, `trustedUrls`, etc.) have no Agent Script equivalent and are noted.

### Step 4 — Save the YAML

```bash
mkdir -p force-app/main/default/aiAuthoringBundles/Agentforce_Service_Agent
# paste the YAML from Claude's output into:
# force-app/main/default/aiAuthoringBundles/Agentforce_Service_Agent/Agentforce_Service_Agent.agent
```

Resolve the flagged placeholder targets before moving on.

---

## Path B — Full ADLC pipeline

Use this when you want Claude to drive the entire lifecycle: convert → author → discover missing stubs → deploy → test → security scan.

### Step 0 — Authenticate your org

Skip this if you already have a connected org alias. Otherwise:

```bash
# Interactive — choose browser OAuth, JWT, or sfdx auth URL
./scripts/org-auth.sh

# Or directly for a developer org
sf org login web --alias agentforce-dev

# Verify the connection
sf org display -o agentforce-dev

# Set as default so you don't type -o on every command
sf config set target-org=agentforce-dev --global
```

Confirm `sf agent` commands are available:

```bash
sf agent --help
# If missing: sf plugins install @salesforce/plugin-agent
```

The org needs:
- Agentforce / Agent Script features enabled
- An admin user with `Modify Metadata` + `Manage Bots` permissions
- Einstein Agent license available (for the agent user created in Phase 5)

See [HOWTO.md §3](./HOWTO.md) for JWT setup, org feature verification, and permission requirements.

### Step 1 — Open a Claude Code session

```bash
cd ~/Dev/agentforce-converter-claude
claude
```

### Step 2 — Invoke the orchestrator

```
Use adlc-orchestrator to convert, deploy, and test sample/sample-agent.json against my org.
```

The orchestrator will work through the 7-phase ADLC. Here is what happens at each phase and what you need to do:

---

### Phase 0 — Legacy Conversion

**What Claude does:** Delegates to `agentforce-converter`, which reads the skill and produces the Agent Script YAML + Notes.

**What you do:** If you haven't already retrieved the JSON from the org, run the retrieve script before invoking the orchestrator:

```bash
./scripts/retrieve-legacy-agent.sh Agentforce_Service_Agent -o agentforce-dev
# Output: legacy/Agentforce_Service_Agent.json
```

Then invoke the orchestrator pointing at the assembled JSON:

```
Use adlc-orchestrator to convert, deploy, and test legacy/Agentforce_Service_Agent.json against my org.
```

The orchestrator will surface flagged uncertainties and ask you to resolve them before proceeding — specifically any `TODO_REPLACE` sentinels (fill in `plannerRole`/`plannerCompany`), the two placeholder Flow/Prompt Template targets, and the `default_agent_user`. Provide the actual values from your org.

---

### Phase 1 — Requirements Review

**What Claude does:** Derives requirements from the converted YAML (topics, actions, agent type, connection config).

**What you do:** Confirm or adjust. The sample is a `AgentforceServiceAgent` with messaging channel escalation. If your org uses a different OmniChannel Flow name, say so here.

---

### Phase 2 — Agent Authoring

**What Claude does:** Delegates to `adlc-author`, which refines the YAML — applying best practices from `developing-agentforce` (correct block ordering, topic descriptions tuned for routing accuracy, variable declarations, deterministic guards).

**What you do:** Review the `.agent` file written to `force-app/main/default/aiAuthoringBundles/Agentforce_Service_Agent/`. The author will note any assumptions.

---

### Phase 3 — Discovery

**What Claude does:** Delegates to `adlc-engineer`, which parses the `.agent` file, extracts all `flow://` and `generatePromptResponse://` targets, and checks whether they exist in your org.

For the sample, it will look for:
- `flow://SvcCopilotTmpl__AddCaseComment`
- `flow://SvcCopilotTmpl__GetCasesForContact`
- `flow://SvcCopilotTmpl__GetCaseByCaseNumber`
- `flow://Identify_Customer_by_Email_CM`
- `generatePromptResponse://Answer_FAQ_Question_CM`
- `standardInvocableAction://streamKnowledgeSearch`

**What you do:** Confirm which targets exist and which need to be created or remapped. The `SvcCopilotTmpl__*` flows are standard service templates — they likely exist if your org has the Service Cloud template installed. The `Identify_Customer_by_Email_CM` flow and `Answer_FAQ_Question_CM` prompt template are custom — you either have them or need stubs.

---

### Phase 4 — Scaffolding

**What Claude does:** For any missing targets, `adlc-engineer` generates stub Flow XML and/or Apex `@InvocableMethod` classes with the correct input/output variable shapes so the agent can deploy and run (even before the stubs are fully implemented).

**What you do:** Review the generated stubs. They are intentionally minimal — they satisfy the deployment registry but do not implement real logic. Mark which ones need real implementations and who owns them.

---

### Phase 5 — Deployment

**What Claude does:** `adlc-engineer` runs the deployment sequence:

```bash
sf project deploy start --metadata "AiAuthoringBundle:Agentforce_Service_Agent" -o <your-org>
sf agent validate authoring-bundle --api-name Agentforce_Service_Agent -o <your-org>
sf agent publish authoring-bundle --api-name Agentforce_Service_Agent -o <your-org>
sf agent activate --api-name Agentforce_Service_Agent_Bot -o <your-org>
```

**What you do:** The orchestrator pauses at the publish step and asks for explicit confirmation before activating. This is intentional — publishing creates a live runtime agent. Confirm when ready.

---

### Phase 6 — Testing & Optimization

**What Claude does:** Delegates to `adlc-qa`, which:

1. Runs smoke tests via `sf agent preview` — one utterance per topic.
2. Reads the session traces from `.sfdx/agents/`.
3. Checks topic routing accuracy, action invocation rate, grounding assessment, and safety scores.
4. Fixes any issues (up to 3 iterations) and re-tests.

For the sample agent, expect smoke test utterances like:
- "What is the status of my case?" → should route to `case_management`
- "I want to speak to a human agent" → should route to `escalation`
- "What is your return policy?" → should route to `general_faq`
- "What is the current solar panel efficiency record?" → should route to `general_web_search`

**What you do:** Review the test summary. If routing accuracy is below 95%, adlc-qa will propose description adjustments and re-test. Approve or redirect.

---

### Phase 7 — Security Assessment

**What Claude does:** Runs `securing-agentforce` against the live agent — 57 adversarial tests across OWASP LLM Top 10 categories (prompt injection, data leakage, excessive agency, etc.). Produces an A–F grade and a findings report.

**What you do:** Review the grade and any CRITICAL or HIGH findings. The orchestrator will surface remediation suggestions. Applying fixes and re-running failed categories is recommended before handing the agent to end users.

---

## What to do with the output

After a successful full pipeline run you will have:

```
force-app/main/default/aiAuthoringBundles/Agentforce_Service_Agent/
    Agentforce_Service_Agent.agent          # the Agent Script source
    Agentforce_Service_Agent.bundle-meta.xml

tests/
    Agentforce_Service_Agent-testing-center.yaml   # batch test suite
    Agentforce_Service_Agent-smoke.yaml            # smoke test set
```

The `.agent` file is the canonical source of truth. Commit it, version it, and treat it as code — future changes go through this file, not through the Agentforce UI.

---

---

## Path C — Design a new agent from a use-case description

Use this when you have a business requirement but no legacy JSON — you are building a net-new agent and want to start from a proven production pattern rather than a blank file.

No Salesforce org is needed for this path.

### Step 1 — Open a Claude Code session

```bash
cd ~/Dev/agentforce-converter-claude
claude
```

### Step 2 — Describe your use case

Tell the skill what you need in plain language:

```
I need an agent that handles employee HR self-service questions — things like leave
balances, benefits queries, and onboarding checklists. It should run in Slack and
escalate to the HR business partner for anything sensitive. Which pattern should I use?
```

The skill will:
1. Read `references/use-case-patterns.md` to identify the agentic pattern family (in this case: **Reactive / Inbound** — `AgentforceEmployeeAgent`).
2. Match the closest production use case — **UC-08: HR & Knowledge Self-Service** (65% HR ticket deflection, Bank of America, VF Services).
3. Run the suitability check: Volume Justified? Specifiable? Reversible? Empathy Critical? Present the verdict.
4. Produce a skeleton `.agent` file.

### Step 3 — Review the suitability verdict and design decisions

Before you see the YAML, the skill presents:

- **Suitability verdict** — e.g. "Strong fit for autonomous agent. HR policy Q&A is high-volume, specifiable from Knowledge Articles, and reversible. Only exception: sensitive personal situations (disciplinary, bereavement) should route to human — use HITL for those topics."
- **Design Decisions** — the policy questions you must answer before the agent is complete. For this scenario:
  - What knowledge sources are authoritative? (Which Knowledge Article categories are in scope?)
  - What is the escalation trigger? (Explicit request? Topic type? Both?)
  - Is the employee's identity verified before accessing personal data? How?
  - What HR topics are explicitly out of scope for the agent?

Answer these inline, or leave them as `# TODO:` items in the YAML and resolve them before deployment.

### Step 4 — Review the scaffolded YAML

The skill returns a skeleton `.agent` file. For the HR self-service scenario it will look roughly like:

```yaml
system:
    instructions: |
        You are an HR self-service assistant for [Company] employees.
        Answer only from the approved HR knowledge sources.
        If a question cannot be answered from those sources, say so clearly
        and offer to connect the employee with an HR business partner.
        # TODO: add company name and tone guidelines

config:
  agent_label: "HR Self-Service"
  developer_name: "HR_Self_Service_Agent"
  agent_type: AgentforceEmployeeAgent
  description: "Answers HR policy questions grounded in approved Knowledge Articles."

variables:
    EmployeeId: linked string
        source: @MessagingEndUser.EmployeeId__c
        description: "Employee ID resolved at session start."
    # TODO: add additional CRM-linked fields (department, location) if needed

topics:
    start_agent topic_selector:
        ...
    topic hr_policy_qa:
        ...
    topic escalation:
        ...
    topic off_topic:
        ...
```

Every `# TODO:` marks an open design decision from Step 3.

### Step 5 — Save the skeleton

```bash
mkdir -p force-app/main/default/aiAuthoringBundles/HR_Self_Service_Agent
# paste the YAML into:
# force-app/main/default/aiAuthoringBundles/HR_Self_Service_Agent/HR_Self_Service_Agent.agent
```

### Step 6 — Complete the design decisions and hand off

Answer the open `# TODO:` items — fill in the knowledge sources, escalation trigger,
and out-of-scope list. Then:

```
Use developing-agentforce to validate and refine
force-app/main/default/aiAuthoringBundles/HR_Self_Service_Agent/HR_Self_Service_Agent.agent
```

`developing-agentforce` will apply Agent Script best practices, verify the block structure,
and prepare the bundle for deployment.

---

## Common issues with the sample

| Issue | Cause | Fix |
|---|---|---|
| `sf project deploy start` fails — "No default username" | No default org set | Run `sf config set target-org=<alias> --global` or add `-o <alias>` to every command |
| "Org not found" or "Expired access/refresh token" | Org auth expired | Re-run `./scripts/org-auth.sh` or `sf org login web --alias <alias>` |
| Deployment fails on `Identify_Customer_by_Email_CM` | Flow doesn't exist in org | Stub it (adlc-engineer) or remap to an existing flow |
| `Answer_FAQ_Question_CM` not found | Prompt Template not deployed | Remap target or deploy the template |
| Topic routing sends FAQ questions to `general_web_search` | Topic descriptions too similar | Let adlc-qa tune descriptions; or add distinguishing keywords manually |
| Escalation action not triggering | `connection messaging` block missing `outbound_route_name` | Set to your org's OmniChannel Flow API name |
| Security grade below B | Instructions too permissive | Review Phase 7 findings; tighten `system.instructions` guardrails |
| "Internal Error, try again later" after activation | Einstein Agent license missing on agent user | Assign an EinsteinGPTUser license to `default_agent_user` |

---

## Next steps after the walkthrough

- Replace stub Flow implementations with real logic.
- Answer any open `# TODO:` design decisions left in the `.agent` file (escalation trigger, out-of-scope topics, data sources, entitlement fields).
- Add `before_reasoning` verification guards if the agent handles sensitive customer data (see the customer-verification pattern in `skills/agentforce-to-agent-script/examples/04-customer-verification/`).
- Review the sub-pattern recipes in `skills/agentforce-to-agent-script/references/use-case-patterns.md` Section 9 for structural building blocks (entitlement gate, consent gate, circuit breaker, draft-and-hold, etc.).
- Add this agent to your CI pipeline using `sf agent test run` (see `testing-agentforce` skill).
- Run `observing-agentforce` after go-live to tune routing and action success rates from real session traces.
