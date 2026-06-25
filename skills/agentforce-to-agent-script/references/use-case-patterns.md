# Use-Case Patterns & Common Deployment Scenarios

A practical design reference for authoring new Agent Script files from requirements.
Maps 21 validated production use cases to their Agent Script constructs so you can
start from a proven pattern rather than a blank file.

Covers five agentic pattern families, then annotates all 21 use cases individually.
Use this document when the user describes a *new* agent scenario and you need to choose
the right structural pattern — not when converting an existing JSON export (that path
is `conversion-playbook.md`).

If anything here conflicts with `agent-script-spec.md`, the spec wins.

---

## Table of Contents

1. [The Five Agentic Pattern Families](#1-the-five-agentic-pattern-families)
2. [Pattern: Reactive / Inbound](#2-pattern-reactive--inbound)
3. [Pattern: Proactive / Outbound](#3-pattern-proactive--outbound)
4. [Pattern: Human-in-the-Loop (HITL)](#4-pattern-human-in-the-loop-hitl)
5. [Pattern: Orchestrator + Specialist](#5-pattern-orchestrator--specialist)
6. [Pattern: Background / Async](#6-pattern-background--async)
7. [Suitability Framework](#7-suitability-framework)
8. [The 21 Use Cases — Design Profiles](#8-the-21-use-cases--design-profiles)
9. [Common Sub-Patterns & Structural Recipes](#9-common-sub-patterns--structural-recipes)
10. [Design Decisions Checklist](#10-design-decisions-checklist)

---

## 1. The Five Agentic Pattern Families

Every production Agentforce deployment maps to one of five agentic patterns.
Identify the pattern first — it determines how the `start_agent`, topics, and
`connection` blocks should be structured.

| Pattern | Trigger | Session | Risk level | Primary `@utils` call |
|---|---|---|---|---|
| Reactive / Inbound | User message | Live / synchronous | Low | `@utils.escalate` |
| Proactive / Outbound | Platform event or schedule | Initiated by agent | Medium | `@utils.sendEmail` / API action |
| Human-in-the-Loop | User message or event | Live, with approval gate | Low–Medium | `@utils.escalate` |
| Orchestrator + Specialist | Decomposed goal | Sub-agent delegation | Medium–High | Sub-agent action |
| Background / Async | CRM event / schedule | Headless (no user session) | Medium | Workflow action |

---

## 2. Pattern: Reactive / Inbound

**What it is:** Agent responds to user messages in real time. The user drives the session.
The agent resolves autonomously or escalates to a human.

**Use cases in this family:**
Customer Service, Voice Agents, Intelligent Routing & Triage, HR & Knowledge Self-Service,
Event Venue Concierge, Executive Event Assistant (EVA), IT Security Incident Triage,
Entitlement-First Service, Conversational Commerce, Web-Grounded FAQ.

**Canonical topic structure:**

```
start_agent topic_selector   → routes by intent
topic <primary_task>         → resolves the core job (e.g. order_status, return_request)
topic escalation             → hands off to human when threshold crossed
topic off_topic              → anti-hallucination guard
```

**Escalation threshold patterns:**

```yaml
# Sentiment-based
reasoning:
    before_reasoning: |
        if @variables.CustomerSentiment == "NEGATIVE" and @variables.EscalationAttempts >= 2:
            @utils.escalate
    instructions: |
        ...

# Topic-scope-based (off-topic guard)
topic off_topic:
    label: "Off-Topic Guard"
    description: "Handle any request outside the defined scope."
    reasoning:
        instructions: |
            Tell the user you can only help with [scope]. Offer to connect them
            with a human agent who can assist further.
            @utils.escalate
```

**Before-reasoning guard for entitlement:**

```yaml
# Resolve entitlement tier once at session start; gate every sensitive topic
variables:
    CustomerTier: linked string
        source: @MessagingEndUser.ContactTier__c
        description: "Service tier resolved at session start."

topic premium_support:
    reasoning:
        before_reasoning: |
            if @variables.CustomerTier != "PREMIUM":
                | I'm sorry, that service is only available to Premium members.
                | Would you like to upgrade your plan?
                stop
        instructions: |
            ...
```

---

## 3. Pattern: Proactive / Outbound

**What it is:** The agent monitors a platform signal (CRM event, schedule, data change)
and *initiates* contact without a user starting the session. The agent sends the first
message (email, SMS, voice call).

**Use cases in this family:**
SDR / Lead Nurturing, Outbound Voice Recruitment Pre-Screening.

**Key structural differences from Reactive:**

- No `connection messaging:` block with a `welcome:` message — the agent opens the
  conversation rather than waiting for one.
- A `variables:` block with CRM-linked context pre-loaded before outreach starts.
- Consent gate as first topic (mandatory before any outreach action).
- Human takeover point is defined by *stage* (e.g. qualified opportunity created),
  not by sentiment or failure.
- Rate-limit guardrail in instructions (max outreach attempts per prospect).

**Canonical topic structure:**

```
start_agent topic_selector   → checks consent status first
topic consent_verification   → opt-in check / SMS confirm before call
topic outreach               → personalised message / call content
topic qualification          → capture BANT criteria
topic handoff_to_human       → triggered when opportunity meets threshold
topic off_topic              → scope guard
```

**Consent gate pattern:**

```yaml
topic consent_verification:
    label: "Consent Verification"
    description: "Verify opt-in status before any outbound contact."
    reasoning:
        before_reasoning: |
            if @variables.ConsentStatus != "OPT_IN":
                | Thank you for your time. We will not contact you further.
                stop
        instructions: |
            Confirm the prospect has opted in via [channel].
            Do not proceed with outreach if consent is not confirmed.
```

**Handoff trigger pattern (stage-based, not sentiment-based):**

```yaml
topic handoff_to_human:
    label: "Qualified Lead Handoff"
    description: "Transfer to human rep when qualification threshold is met."
    reasoning:
        before_reasoning: |
            if @variables.QualificationScore < @variables.HandoffThreshold:
                | Keep going — not ready for handoff yet.
                stop
        instructions: |
            Summarise the qualification answers.
            Notify the assigned rep.
            Update the lead record with BANT answers.
            @utils.escalate
```

---

## 4. Pattern: Human-in-the-Loop (HITL)

**What it is:** The agent handles intake, drafting, or triage — but a human reviews
and approves before any consequential action is taken. The agent never acts unilaterally
on high-stakes decisions.

**Use cases in this family:**
Case Summary & Claims Processing, Email Triage & Response Drafting,
Bereavement & Hardship Financial Services.

**HITL is mandatory when any of these apply:**
- Action is financially irreversible (e.g. payout, account closure).
- Regulatory accountability requires named human sign-off.
- Emotional sensitivity means a mistake causes harm beyond task failure.
- Accuracy is below the autonomous-safe threshold for this decision type.

**The bereavement case is the canonical HITL maximum:** agent only handles intake
and routes to a specialist. It never drafts, recommends, or acts on the account.
This is intentional and non-negotiable — empathy and regulatory duty require a human.

**Canonical topic structure:**

```
start_agent topic_selector   → routes by intent
topic intake                 → gather case details, no decisions yet
topic draft_response         → produce recommendation / draft for human review
topic escalation             → route to appropriate human queue with context
```

**Draft-and-hold pattern:**

```yaml
topic email_draft:
    label: "Draft Email Response"
    description: "Generate a draft response for human review before sending."
    reasoning:
        instructions: ->
            | Analyse the incoming email context:
            action: get_email_context
            | Draft a response following tone guidelines.
            | Present the draft to the agent user for review.
            | Do NOT send the email. Wait for explicit approval.
            | The agent user will send via their email client.
    actions:
        get_email_context:
            description: "Retrieve email thread and customer context."
            target: flow://Get_Email_Context
            inputs:
                EmailId:
                    type: String
                    is_required: True
```

**Escalation with context handoff:**

```yaml
topic escalation:
    label: "Route to Specialist"
    description: "Transfer to human specialist with full context package."
    reasoning:
        instructions: ->
            | Prepare a context summary before transfer:
            action: create_case_summary
            | Transfer to the [specialist queue] with the case summary attached.
            @utils.escalate
```

---

## 5. Pattern: Orchestrator + Specialist

**What it is:** One orchestrator agent decomposes a complex goal into sub-tasks and
delegates to domain-specialist sub-agents. Results are aggregated and presented to
the user (or deposited in a target system).

**Use cases in this family:**
Complex Field Service Resolution, Enterprise Employee Onboarding, Multi-Agent
Orchestration (SOMA / MOMA).

**Two sub-variants:**

| Sub-variant | Description | Agent Script shape |
|---|---|---|
| SOMA (Single Org, Multiple Agents) | All agents in one org; shared data model | Sub-agent actions with shared variables |
| MOMA (Multi-Org / Multi-Team) | Agents owned by different teams; explicit contracts | Sub-agent actions with explicit handoff contracts |

**Key structural differences from Reactive:**
- Topics map to *coordination steps*, not user intents.
- Each sub-agent invocation is an action with explicit `inputs:` and `outputs:`.
- Circuit breaker: if sub-agent returns empty / error, the orchestrator handles fallback
  explicitly (never proceeds silently).
- Handoff contracts must be documented: field names, types, required/optional.

**Canonical orchestrator topic structure:**

```
start_agent topic_selector   → intent classification (what type of request)
topic intake                 → gather decomposition inputs from user
topic orchestrate            → fan out to sub-agents (parallel or sequential)
topic aggregate_results      → collect outputs, resolve conflicts
topic present_outcome        → surface final result to user / write to system
topic escalation             → circuit breaker when sub-agent fails
```

**Sub-agent delegation pattern:**

```yaml
topic orchestrate_onboarding:
    label: "Coordinate Onboarding Streams"
    description: "Delegate IT provisioning, HR paperwork, and facilities setup in parallel."
    reasoning:
        instructions: ->
            | Initiate all three onboarding streams:
            action: trigger_it_provisioning
            action: trigger_hr_setup
            action: trigger_facilities_access
            | Wait for all three to complete (check status via polling action).
            action: check_onboarding_status
            | If any stream failed, route to escalation topic.
    actions:
        trigger_it_provisioning:
            description: "Start IT account and device provisioning via IT sub-agent."
            target: flow://Trigger_IT_Onboarding_SubAgent
            inputs:
                EmployeeId:
                    type: String
                    is_required: True
            outputs:
                ProvisioningJobId:
                    type: String
                    is_required: True
```

**Circuit breaker pattern:**

```yaml
topic aggregate_results:
    reasoning:
        before_reasoning: |
            if @variables.ITProvisioningStatus == "FAILED":
                | IT provisioning failed. Routing to escalation.
                @utils.route topic: escalation
            if @variables.HRSetupStatus == "FAILED":
                | HR setup failed. Routing to escalation.
                @utils.route topic: escalation
        instructions: |
            All streams completed. Present the onboarding summary.
```

---

## 6. Pattern: Background / Async

**What it is:** Agent executes a long-horizon task without a live user session.
Triggered by a CRM event, schedule, or data change. Results deposited in a target
system (email, case, record, dashboard) — the user reviews asynchronously.

**Use cases in this family:**
Employee Productivity (meeting prep), Finance Close Process Automation,
Headless Event-Triggered Agent (churn detection).

**Key structural differences:**
- No `connection messaging:` block (no live channel).
- No `system.messages.welcome` — no user is present at session start.
- Topics map to *workflow phases*, not user intents.
- The final action writes results to a CRM record, sends a notification, or creates a task.
- Human approval gate (if required) is an asynchronous: record + notify, not a live prompt.

**Canonical topic structure:**

```
start_agent topic_selector   → routes by trigger type
topic gather_context         → load CRM data needed for the task
topic execute_task           → core processing (reconcile, research, score)
topic flag_exceptions        → identify items requiring human review
topic deposit_results        → write output to CRM / send notification
```

**Headless event-triggered pattern:**

```yaml
# No connection block — headless
system:
    instructions: |
        You are a background automation agent. You have no live user session.
        You receive a trigger event and execute a defined workflow.
        Do not attempt to ask the user questions. Complete the task and deposit results.

variables:
    TriggerEventId: linked string
        source: @AgentSession.TriggerEventId
        description: "ID of the triggering CRM event."
    TargetRecordId: linked string
        source: @AgentSession.TargetRecordId
        description: "CRM record to act on."

start_agent topic_selector:
    reasoning:
        instructions: |
            Based on the trigger type, route to the appropriate workflow topic.
            @utils.route topic: execute_churn_prevention
```

**Finance close async pattern (human approves GL post):**

```yaml
topic flag_exceptions:
    label: "Flag Reconciliation Exceptions"
    description: "Identify line items that need human review before GL post."
    reasoning:
        instructions: ->
            | Review reconciliation output for exceptions:
            action: get_reconciliation_results
            | For each exception, create a task assigned to the finance controller.
            action: create_review_task
            | Do NOT post to GL. The finance controller will approve the GL post
            | after reviewing the flagged exceptions.
```

---

## 7. Suitability Framework

Before designing any agent, evaluate the use case against these four criteria.
Wrong answers here produce agents that fail in production.

| Criterion | Question | If NO |
|---|---|---|
| Volume Justified | Is demand high enough to justify build cost? | Do manually — not worth the agent |
| Specifiable | Can the task be defined precisely enough for an AI agent? | Ambiguous tasks need human judgment — HITL at best |
| Reversible | Are the agent's actions easily undone? | Add human approval gate; never act autonomously |
| Empathy Critical | Does emotional connection matter more than task completion? | Human-only at minimum; HITL maximum |

**Verdict rules:**

- All four YES → **Autonomous agent** (strong fit)
- Volume + Specifiable + Reversible, Empathy = NO → **Autonomous agent**
- Not Reversible, other three YES → **Human-in-the-Loop** (never autonomous on irreversible)
- Not Specifiable → **Human-only** (ambiguous tasks can't be encoded)
- Empathy Critical = YES → **Human-only or HITL maximum** (empathy is a veto; no exceptions)
- Not Volume Justified → **Automation or human** (agent overkill; use a Flow or scheduled job)

**Canonical HITL maximum case — bereavement & hardship:**
`volume_justified: true, specifiable: false, reversible: false, empathy_critical: true`
→ Agent handles intake only. 100% human specialist involvement for all decisions.
An agent that tries to autonomously handle grief is a liability, not a feature.

---

## 8. The 21 Use Cases — Design Profiles

Each entry gives: agentic pattern, agent type, primary channel(s), required Agent Script
constructs, key variables, production ROI signal, and the single most important design
decision a human must make before deployment.

---

### UC-01: Customer Service & Self-Service

**Pattern:** Reactive / Inbound
**Agent type:** `AgentforceServiceAgent`
**Channels:** Chat, WhatsApp, Mobile App
**ROI signal:** 70% autonomous resolution rate

**Required constructs:**
- `before_reasoning` entitlement gate on all sensitive topics
- `variables.CustomerTier` linked to contact record
- `off_topic` guard topic
- `escalation` topic with sentiment threshold

**Key variables:**
```yaml
CustomerTier: linked string
    source: @MessagingEndUser.ContactTier__c
SessionEscalationCount: mutable integer = 0
CustomerSentiment: mutable string = "NEUTRAL"
```

**Critical design decision:** At what sentiment score, dollar threshold, or explicit
request does the agent escalate? This is a business policy decision embedded in
`before_reasoning`. Get it wrong and customers feel trapped.

---

### UC-02: Employee Productivity & Sales Coaching

**Pattern:** Background / Async (meeting prep) + Reactive / Inbound (coaching)
**Agent type:** `AgentforceEmployeeAgent`
**Channels:** Slack, Email, Salesforce CRM console
**ROI signal:** Meeting prep time 1 day → 15 minutes

**Required constructs:**
- No `connection messaging:` for background prep variant
- `variables.AccountId` and `variables.MeetingDate` linked from CRM
- Action: `get_account_history`, `get_opportunity_pipeline`, `get_contact_profile`
- Final action deposits summary into a CRM record or Slack message

**Critical design decision:** What data sources feed the prep brief? Incomplete data
produces bad briefs. Define the exact CRM fields and external sources before authoring.

---

### UC-03: SDR / Lead Nurturing

**Pattern:** Proactive / Outbound
**Agent type:** `AgentforceServiceAgent` (external-facing SDR persona)
**Channels:** Email, Salesforce CRM (automated sequences)
**ROI signal:** $2.7M closed revenue attributed; 3× reply rate

**Required constructs:**
- Consent gate as first topic (mandatory)
- `variables.ConsentStatus` linked from lead record
- `variables.OutreachAttemptCount` mutable counter with max-attempts guard
- Rate-limit guardrail in `system.instructions`
- Human handoff topic triggered by qualification score, not sentiment

**Critical design decision:** What qualification threshold triggers handoff to a human
rep? Handing off too early wastes rep time. Too late and the prospect goes cold.

---

### UC-04: Voice Agents (Inbound IVR)

**Pattern:** Reactive / Inbound
**Agent type:** `AgentforceServiceAgent`
**Channels:** Voice / telephony
**ROI signal:** ~4M calls deflected/year; $0.50 vs $6.00 per interaction

**Required constructs:**
- `connection voice:` block instead of `connection messaging:`
- Short, spoken-English instructions (avoid bullet lists, markdown)
- DTMF / intent routing in `start_agent`
- `variables.CallerPhoneNumber` linked from session
- Escalation transfers to live agent queue with estimated wait time

**Critical design decision:** What call types must *always* route to a human, regardless
of confidence? Define these as `before_reasoning` hard stops, not soft instructions.

---

### UC-05: Conversational Commerce (Shopper Agent)

**Pattern:** Reactive / Inbound
**Agent type:** `AgentforceServiceAgent`
**Channels:** Website Chat, Mobile App, WhatsApp
**ROI signal:** 470M commerce credits processed at rollout

**Required constructs:**
- `variables.CartId` mutable (created when agent adds first item)
- Action: `search_product_catalog`, `add_to_cart`, `get_product_recommendations`
- `before_reasoning` check: is cart session active?
- Escalation topic for checkout issues (payment failures are irreversible-adjacent)

**Critical design decision:** Which product data fields does the agent have access to?
Out-of-stock handling and personalization require real-time inventory + customer profile.

---

### UC-06: Case Summary & Claims Processing

**Pattern:** Human-in-the-Loop
**Agent type:** `AgentforceServiceAgent`
**Channels:** Salesforce CRM console (internal agent tool)
**ROI signal:** 60% reduction in average handle time

**Required constructs:**
- Action: `get_case_history`, `generate_summary`, `pre_populate_resolution_form`
- Draft presented for human review — never auto-submitted
- `require_user_confirmation: True` on any action that writes to the case record
- `variables.CaseId` linked from session

**Critical design decision:** Which fields in the summary draft can the agent
auto-populate vs. which must the human fill in? Define the boundary explicitly.

---

### UC-07: Intelligent Routing & Triage

**Pattern:** Reactive / Inbound
**Agent type:** `AgentforceServiceAgent`
**Channels:** Chat, Voice, Email
**ROI signal:** 35% reduction in misrouted cases; 82% deflection (Datasite)

**Required constructs:**
- `start_agent` with explicit intent classification in instructions
- `@utils.route topic:` to route to topic matching detected intent
- `@utils.escalate` with `queue:` parameter for skill-based routing
- `variables.DetectedIntent` mutable string capturing the classification result

**Critical design decision:** What is the list of queues and their routing criteria?
This must be maintained as the queue structure changes — stale routing = misroutes.

---

### UC-08: HR & Knowledge Self-Service

**Pattern:** Reactive / Inbound
**Agent type:** `AgentforceEmployeeAgent`
**Channels:** Slack, Intranet Chat, Salesforce
**ROI signal:** 65% HR ticket deflection rate

**Required constructs:**
- `knowledge:` block with approved Knowledge Articles only
- `system.instructions` guardrail: "Answer only from the provided knowledge sources.
  If the answer is not in the knowledge sources, say so clearly."
- `variables.EmployeeId` linked from session
- Off-topic guard: policy questions outside the KB scope escalate to HR BP

**Critical design decision:** What knowledge sources are authoritative? The agent must
never answer from training data on HR policy — only from sanctioned articles.
Outdated knowledge = compliance risk.

---

### UC-09: Email Triage & Response Drafting

**Pattern:** Human-in-the-Loop
**Agent type:** `AgentforceServiceAgent` or `AgentforceEmployeeAgent`
**Channels:** Email (internal agent tool)
**ROI signal:** 50% reduction in email response time

**Required constructs:**
- Action: `get_email_thread`, `classify_email_intent`, `draft_response`
- `require_user_confirmation: True` on any send action (or omit send action entirely)
- Draft presented in CRM record for human review
- `variables.EmailId` linked from session

**Critical design decision:** Does the agent send autonomously, or only draft? In
production, autonomous send creates liability for incorrect content. Default to draft-only
and require explicit human approval to send.

---

### UC-10: Event Venue Concierge

**Pattern:** Reactive / Inbound
**Agent type:** `AgentforceServiceAgent`
**Channels:** Mobile App (deep-link navigation)
**ROI signal:** <1 second pathfinding across 34,000 pre-computed paths

**Required constructs:**
- Action: `get_venue_map_path` (calls pre-computed graph, not real-time pathfinding)
- Action: `get_concession_wait_time` (real-time feed)
- `variables.VenueEventId` linked from session
- `variables.UserCurrentLocation` mutable (updated by mobile app)

**Key insight — pre-computation:** Navigation uses pre-computed paths (Floyd-Warshall),
not real-time graph search. The action target returns a pre-computed route. The agent
is the interface layer, not the pathfinding engine.

**Critical design decision:** How is user location resolved? GPS permission, beacon,
QR code check-in? The answer changes the `variables.UserCurrentLocation` source binding.

---

### UC-11: Executive Event Assistant (EVA)

**Pattern:** Reactive / Inbound
**Agent type:** `AgentforceServiceAgent`
**Channels:** Mobile App, WhatsApp
**ROI signal:** 99.4% utterance completion rate (World Economic Forum, Davos)

**Required constructs:**
- `variables.AttendeeId` linked from authenticated session
- Action: `get_schedule`, `request_bilateral_meeting`, `get_forum_navigation`
- Determinism guardrail: "Never express opinions on geopolitical topics, policy
  positions, or participant statements." (This is a `system.instructions` hard rule.)
- `before_reasoning` check: is attendee authenticated?

**Critical design decision:** How is neutrality enforced? For high-profile events, any
opinion attribution to the platform is a reputational risk. The neutrality guardrail must
be specific and testable, not generic ("be balanced").

---

### UC-12: Complex Field Service Resolution

**Pattern:** Orchestrator + Specialist
**Agent type:** `AgentforceServiceAgent`
**Channels:** Technician Mobile App, Salesforce Field Service
**ROI signal:** 45% reduction in mean time to resolution (MTTR)

**Required constructs:**
- Orchestrator topics: intake, parts_check, technician_dispatch, customer_notification
- Sub-agent actions: one per domain (parts, scheduling, customer comms)
- Circuit breaker in `before_reasoning` on aggregate topic
- `variables.WorkOrderId` linked from session
- `variables.PartsAvailabilityStatus`, `variables.TechnicianAvailability` mutable

**Critical design decision:** Which decisions does the orchestrator make autonomously
vs. escalate to the dispatcher? Parts substitution over a cost threshold must escalate.

---

### UC-13: Enterprise Employee Onboarding

**Pattern:** Orchestrator + Specialist (MOMA)
**Agent type:** `AgentforceEmployeeAgent`
**Channels:** Email, Slack, HR Portal
**ROI signal:** 75% reduction in time-to-day-1-readiness

**Required constructs:**
- Orchestrator delegates to: IT sub-agent, HR sub-agent, Facilities sub-agent
- All sub-agents must complete before onboarding is marked ready
- Circuit breaker: if any stream fails, route to HR coordinator
- `variables.EmployeeStartDate`, `variables.EmployeeId`, `variables.DepartmentCode`

**Critical design decision:** What is the SLA for each sub-agent stream? Onboarding
has a hard deadline (start date). Define timeout thresholds and fallback paths explicitly.

---

### UC-14: Bereavement & Hardship Financial Services

**Pattern:** Human-in-the-Loop (intake only; all decisions human)
**Agent type:** `AgentforceServiceAgent`
**Channels:** Chat, Phone (intake routing only)
**ROI signal:** 100% compliance with FCA Consumer Duty

**Required constructs:**
- `system.instructions` must include: empathy acknowledgment language, no transactional
  framing, no autonomous account actions of any kind
- Single topic: `bereavement_intake` — gather case type and route to specialist queue
- `@utils.escalate` with `queue: "Bereavement Specialist Team"` as the *only* resolution
- No action that reads account balance, proposes settlement, or modifies account status

**Critical design decision:** What language does the agent use in the first response?
This is set in `system.messages.welcome` and the `bereavement_intake` instructions.
It must be reviewed by a welfare specialist, not just a product team.

---

### UC-15: Finance Close Process Automation

**Pattern:** Background / Async
**Agent type:** `AgentforceEmployeeAgent`
**Channels:** Salesforce CRM (headless)
**ROI signal:** 80% reduction in manual reconciliation effort

**Required constructs:**
- No `connection messaging:` block (headless)
- Action: `get_ledger_data`, `run_reconciliation`, `flag_exception`, `create_review_task`
- `require_user_confirmation: True` on GL post action (humans approve)
- `variables.ReportingPeriod` linked from trigger event
- Final action: creates task for finance controller, never posts to GL autonomously

**Critical design decision:** What tolerance threshold defines an "exception" that needs
human review vs. an immaterial variance that can be auto-cleared? This is a finance
policy decision that must be encoded as a specific number.

---

### UC-16: IT Security Incident Triage

**Pattern:** Reactive / Inbound (alert-driven, not user-driven)
**Agent type:** `AgentforceEmployeeAgent`
**Channels:** SIEM integration, Slack, Salesforce
**ROI signal:** 90% reduction in analyst time on alert noise filtering

**Required constructs:**
- Action: `get_alert_details`, `deduplicate_alerts`, `classify_severity`, `pre_populate_playbook`
- `variables.AlertId` linked from trigger
- `variables.SeverityScore` mutable — computed by classification action
- `before_reasoning` check: if severity == "CRITICAL", immediately escalate to SOC lead
- `require_user_confirmation: True` on any remediation action (containment, isolation)

**Critical design decision:** What CVSS score or signal combination triggers autonomous
containment vs. human approval? Containment can isolate production systems — wrong
threshold causes outages.

---

### UC-17: Entitlement-First Service Agent

**Pattern:** Reactive / Inbound
**Agent type:** `AgentforceServiceAgent`
**Channels:** Chat, Mobile App
**ROI signal:** 100% rollout to 4.6M users with zero entitlement breach incidents

**Three-stage entitlement pattern (proven in production):**

1. **Resolve tier** — `before_reasoning` loads `CustomerTier` from CRM before any topic executes
2. **Gate topics** — each sensitive topic has a `before_reasoning` tier check; stops cold if tier insufficient
3. **Propagate to sub-agents** — if orchestrating sub-agents, pass tier as an explicit input parameter

**Required constructs:**
```yaml
variables:
    CustomerTier: linked string
        source: @MessagingEndUser.ContactTier__c
    # Resolved at session start — never trusted from user input

# Every premium topic:
topic premium_feature:
    reasoning:
        before_reasoning: |
            if @variables.CustomerTier != "PREMIUM" and @variables.CustomerTier != "ENTERPRISE":
                | That feature is only available to Premium members.
                stop
```

**Critical design decision:** Is tier resolved from a CRM source (trusted) or from a
user-supplied claim (untrusted)? Never trust the user's stated tier. Always resolve from
the authoritative CRM source in a `linked` variable.

---

### UC-18: Headless Event-Triggered Agent

**Pattern:** Background / Async (event-driven)
**Agent type:** `AgentforceServiceAgent` or `AgentforceEmployeeAgent`
**Channels:** Headless (no user interface)
**ROI signal:** 17,000 autonomous actions per week (DIRECTV)

**Required constructs:**
- No `connection` block
- `system.instructions` states explicitly: "You are a background agent. You have no
  live user session. Execute the defined workflow and deposit results."
- `variables.TriggerEventId` and `variables.TargetRecordId` linked from session
- Action sequence: detect signal → evaluate → act → notify → close
- Audit trail: every action writes a record to a log object

**Critical design decision:** What ambient signals trigger the workflow? Signal definition
determines the false positive rate. Too broad = noisy actions on healthy accounts.
Too narrow = misses real churn. This is a data science decision, not a product decision.

---

### UC-19: Multi-Agent Orchestration (SOMA / MOMA)

**Pattern:** Orchestrator + Specialist
**Agent type:** `AgentforceServiceAgent` (orchestrator) + domain specialists
**Channels:** Varies per domain
**ROI signal:** 4.6M users served (Xero); 40K+ employees (Bank of America)

**SOMA vs. MOMA choice:**

| | SOMA | MOMA |
|---|---|---|
| Teams | Single team owns all agents | Different teams own different agents |
| Data model | Shared org, shared objects | Explicit API contracts between orgs/teams |
| Handoff | Variable passing | Explicit input/output schemas on sub-agent actions |
| Risk | Easier to build, harder to scale | Harder to build, scales across org boundaries |

**MOMA handoff contract pattern:**

```yaml
actions:
    call_hr_specialist_agent:
        description: "Delegate HR query to HR domain specialist agent."
        target: flow://Invoke_HR_Specialist_Agent
        inputs:
            EmployeeId:
                type: String
                is_required: True
                description: "Employee whose HR query this is."
            QueryText:
                type: String
                is_required: True
                description: "Verbatim user query — do not paraphrase."
            SessionContext:
                type: String
                is_required: False
                description: "JSON blob of session variables to pass to specialist."
        outputs:
            ResponseText:
                type: String
                is_required: True
            HandoffRequired:
                type: Boolean
                is_required: False
                description: "True if specialist needs human escalation."
```

**Critical design decision:** How are contracts versioned? If Team A changes the HR
specialist's input schema, the orchestrator breaks silently. Define a versioning and
deprecation policy before going live.

---

### UC-20: Outbound Voice Recruitment Pre-Screening

**Pattern:** Proactive / Outbound
**Agent type:** `AgentforceServiceAgent`
**Channels:** Voice (outbound dialer), SMS (consent)
**ROI signal:** 2× hire likelihood; 150K+ calls (Adecco); $0.50/call

**Required constructs:**
- `connection voice:` block
- SMS consent gate before any call attempt (GDPR / TCPA compliance)
- `variables.CandidateId` linked from ATS record
- `variables.ConsentStatus` linked and checked in `before_reasoning`
- Structured output action: captures BANT-equivalent screening answers to ATS record
- `require_user_confirmation: False` on screening questions (autonomous), `True` on
  any action that updates the candidate's status in ATS

**Critical design decision:** What disqualifying answers end the screening immediately
vs. require a human to review? Auto-disqualification can constitute discriminatory
screening — legal review required before encoding any disqualification rules.

---

### UC-21: Web-Grounded FAQ Agent

**Pattern:** Reactive / Inbound
**Agent type:** `AgentforceServiceAgent`
**Channels:** Website Chat, WhatsApp
**ROI signal:** 70% chat deflection; deployment in weeks not quarters

**Required constructs:**
- `knowledge:` block grounded in web-crawled FAQ URLs (not authored Knowledge Articles)
- `system.instructions` guardrail: "Answer only from the retrieved FAQ content.
  Do not synthesise or extrapolate beyond what the FAQ source says."
- Action: `search_faq_web_source` (retriever action)
- Escalation topic for questions the FAQ doesn't cover

**Key advantage over Knowledge-Article-based agents:** Zero KB authoring overhead.
Deploy on web content that already exists. Suitable for time-to-value-sensitive projects.

**Critical design decision:** How often is the web source re-crawled? Stale FAQ content
produces wrong answers. Define the crawl schedule and cache TTL explicitly.
For regulatory content, daily crawl minimum.

---

## 9. Common Sub-Patterns & Structural Recipes

Reusable building blocks that appear across multiple use cases.

### 9.1 Entitlement Gate (universal — use in any access-controlled agent)

```yaml
variables:
    CustomerTier: linked string
        source: @MessagingEndUser.ContactTier__c
        description: "Service tier from CRM. Resolved at session start."

topic <sensitive_topic>:
    reasoning:
        before_reasoning: |
            if @variables.CustomerTier != "PREMIUM":
                | This feature requires a Premium subscription.
                | Would you like information about upgrading?
                stop
```

### 9.2 Consent Gate (proactive / outbound agents — mandatory)

```yaml
topic consent_check:
    label: "Consent Verification"
    description: "Verify opt-in before any outbound action."
    reasoning:
        before_reasoning: |
            if @variables.ConsentStatus != "OPT_IN":
                | We respect your contact preferences. No further outreach will be sent.
                stop
        instructions: |
            Confirm the contact has opted in via [channel] for [purpose].
```

### 9.3 Rate-Limit Guard (proactive agents — prevents spam)

```yaml
variables:
    OutreachAttemptCount: linked integer
        source: @Lead.OutreachAttempts__c
        description: "Number of outreach attempts made for this lead."

# In system.instructions or topic instructions:
# "Do not attempt outreach if OutreachAttemptCount >= 3. Mark lead as exhausted."
```

### 9.4 Draft-and-Hold (HITL — never send autonomously)

```yaml
actions:
    draft_response:
        description: "Generate a response draft for human review."
        require_user_confirmation: True    # Agent user must approve before any action
        target: flow://Draft_Response_For_Review
```

### 9.5 Circuit Breaker (orchestrator agents — fail loudly, not silently)

```yaml
topic aggregate:
    reasoning:
        before_reasoning: |
            if @variables.SubAgentAStatus == "FAILED":
                @utils.route topic: escalation
            if @variables.SubAgentBStatus == "FAILED":
                @utils.route topic: escalation
```

### 9.6 Audit Trail (background / headless agents — every action logged)

```yaml
actions:
    log_action:
        description: "Write an audit record for every autonomous action taken."
        require_user_confirmation: False
        target: flow://Write_Agent_Audit_Log
        inputs:
            ActionType: { type: String, is_required: True }
            TargetRecordId: { type: String, is_required: True }
            Outcome: { type: String, is_required: True }
```

### 9.7 Determinism Anchor (high-stakes topics — force order, prevent reordering)

```yaml
topic <high_stakes>:
    reasoning:
        instructions: ->
            | Step 1 — always first: verify identity.
            action: verify_identity
            | Step 2: load account context.
            action: get_account_context
            | Step 3 only if identity verified: present options.
            | Never skip or reorder these steps.
```

### 9.8 Knowledge-Grounded Anti-Hallucination (FAQ / HR / compliance agents)

```yaml
system:
    instructions: |
        Answer only from the knowledge sources provided.
        If the question cannot be answered from those sources, say:
        "I don't have that information. Let me connect you with someone who can help."
        Never synthesise, extrapolate, or answer from general knowledge.
```

---

## 10. Design Decisions Checklist

These decisions must be made by a human before the agent is authored.
Encoding wrong answers is worse than not encoding them — wrong policy persists silently.

**Scope & topics:**
- [ ] What topics is the agent in scope for? What is explicitly out of scope?
- [ ] What is the authoritative list of intents the `start_agent` should route?

**Access & entitlement:**
- [ ] What CRM field determines the user's tier / entitlement?
- [ ] Which topics require a tier check? What happens when the user fails the check?
- [ ] Is the user's identity verified before sensitive actions? How is verification done?

**Escalation & handoff:**
- [ ] What triggers escalation to a human? (Sentiment score? Explicit request? Topic type? Dollar amount?)
- [ ] Which human queue does escalation go to? Is there more than one queue?
- [ ] What context is passed at escalation? (Case summary? Session transcript? Variables?)
- [ ] Is escalation always available, or only after the agent attempts resolution?

**Actions & reversibility:**
- [ ] Which actions are irreversible? (Account modification, payment, cancellation)
- [ ] For irreversible actions: is `require_user_confirmation: True` set?
- [ ] For high-stakes actions: is a human approval gate (async task) required?

**Data & knowledge:**
- [ ] What data sources ground the agent's answers? (Knowledge Articles, Data Cloud, web crawl)
- [ ] How often are those sources refreshed? Who is responsible for keeping them current?
- [ ] Can the agent answer from general training knowledge, or only from grounded sources?

**Channels & personas:**
- [ ] What channel(s) does the agent operate on? (Chat, voice, headless)
- [ ] Does tone differ by channel? (Voice = spoken English, no markdown)
- [ ] What is the agent's name and persona? Is it disclosed as AI per applicable law?

**Proactive / outbound (if applicable):**
- [ ] Has consent been obtained? How is consent status stored and checked?
- [ ] What is the maximum outreach frequency per contact?
- [ ] What disqualifying signals stop outreach immediately?

**Multi-agent (if applicable):**
- [ ] What is the handoff contract between orchestrator and specialists?
- [ ] How are contracts versioned and communicated between teams?
- [ ] What happens when a sub-agent fails or times out?

---

## 11. Key Architectural Principles

These five principles, derived from 10 months of production deployments (June 2025 – June 2026), distinguish reliable enterprise agents from fragile ones.

### Principle 1 — Separation of Concerns

Agent Script defines rails (deterministic); reasoning runs inside them. Keep this boundary explicit.

```
Agent Script (Deterministic):
START → Authenticate User → Route to Department → Execute Topic → END

Within "Execute Topic" (Agentic):
- LLM interprets user query
- Retrieves relevant knowledge
- Formulates natural language response
```

Why it works:
- Critical paths (auth, routing) are predictable — failures are isolated and diagnosable
- Creative tasks (answers, summaries) leverage LLM flexibility
- Failures are isolated to specific reasoning steps, not systemic

### Principle 2 — Determinism Over Intelligence

Prefer predictable flows over purely AI-driven logic for any decision with a binary correct answer.

**Avoid (Purely Agentic):**
```
"Decide if the user is eligible for a refund based on policy"
Problem: LLM may interpret policy differently each time
```

**Prefer (Hybrid):**
```apex
// Apex Logic Action
public static Boolean isRefundEligible(Case c) {
    return c.CreatedDate > Date.today().addDays(-30)
           && c.Type == 'Product Issue'
           && c.Status != 'Closed';
}
```
Agent uses the Apex result: "Based on your purchase date and issue type, you ARE eligible for a refund. Would you like me to process it?"

Result: 100% consistent eligibility determination.

**The Golden Rule:** If you can't accept the agent being wrong 5–10% of the time, don't use an LLM for that decision — use code.

### Principle 3 — Progressive Disclosure

Load expertise on-demand rather than stuffing all context upfront.

**Avoid (Context Stuffing):**
Agent Instructions: [15,000 words covering every scenario]

**Prefer (Progressive):**
- Global Instructions: [500 words — core behavior only]
- Topic 1 — Product Info: [800 words — product expertise, loaded only when selected]
- Topic 2 — Billing: [600 words — billing expertise, loaded only when selected]
- Topic 3 — Technical: [1000 words — technical expertise, loaded only when selected]

Flow: User asks question → Topic Selector routes → Topic-specific instructions loaded → Knowledge retriever adds 3–5 articles → Response generated with focused context.

Benefits:
- Faster routing (less context to process)
- More relevant responses (focused expertise)
- Easier maintenance (update one topic vs. entire agent)

### Principle 4 — Skills-Based Architecture (Atomic Design)

Each action should do one thing well. Design atomic, composable actions rather than monolithic ones.

**Avoid (Monolithic):**
```
Action: "handleCustomerRequest"
- Looks up account
- Checks eligibility
- Creates case
- Sends email
- Updates dashboard
Problem: If email fails, entire action fails
```

**Prefer (Atomic Skills):**
```
Skill 1: lookupAccount      → Input: accountName     → Output: accountRecord
Skill 2: checkEligibility   → Input: accountRecord   → Output: isEligible (Boolean)
Skill 3: createCase         → Input: accountId, description → Output: caseId
Skill 4: sendNotification   → Input: caseId, template → Output: success (Boolean)
```

Benefits:
- Reusable across multiple topics
- Easy to test individually
- Failures isolated and recoverable

### Principle 5 — Pre-Processing Over Runtime

Generate complex summaries offline, retrieve at runtime. Avoid making the agent do heavy computation during a live session.

**Avoid (Runtime Heavy):**
Agent queries 50,000 opportunity records → analyzes win/loss ratios → calculates trends → generates summary → 45 second wait, timeout risk.

**Prefer (Pre-processed):**
```apex
// Scheduled Apex (Daily 2 AM)
public class QuarterlySummaryBatch {
    // Processes all records
    // Generates summaries per region/product
    // Stores in QuarterlySummary__c object
}
```

Agent Runtime: User asks "Summarize Q4 performance" → Agent queries: `SELECT Summary__c FROM QuarterlySummary__c WHERE Quarter__c = 'Q4 2025'` → Returns pre-generated 500-word summary → 2-second response.

---

## 12. Agent Maturity Evolution Path

Use this framework to assess where a given deployment is today and what investment is needed to reach production-grade reliability.

| Phase | Description | Characteristics | Typical Accuracy |
|---|---|---|---|
| **Phase 1** | Simple Prompt-Based Agent | Instructions only; basic Q&A; no deterministic actions | 40–60% |
| **Phase 2** | Action-Enhanced Agent | Instructions + actions; data retrieval and updates | 60–75% |
| **Phase 3** | Hybrid Deterministic + Agentic | Agent Script for critical paths; LLM for interpretation; pre-processed data | 75–90% |
| **Phase 4** | Production-Ready Enterprise Agent | All of Phase 3 + observability, error handling, performance optimization, regression testing | 85–95% |

**How to progress:**
- Phase 1 → 2: Add actions for data retrieval and CRM updates
- Phase 2 → 3: Add `before_reasoning` guards, variable state management, pre-processing for large data
- Phase 3 → 4: Add Agent Analytics, regression test suites (20+ cases), monitoring alerts, performance optimization

**Balance Framework:**

| Dimension | Deterministic (Code) | Flexible (LLM) | Never Flexible |
|---|---|---|---|
| **Speed** | Fast lookups (<3 seconds) | Allow 10–15 seconds for complex analysis | N/A |
| **Behavior** | Authentication, routing, transactions | Query interpretation, response formatting | Security, compliance, financial operations |
| **Capability** | Launch with proven patterns (70% AI-driven) | Iterate toward advanced capabilities (90% AI-driven) | Always maintain deterministic guardrails |
