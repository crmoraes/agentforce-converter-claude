# AI LLM Skill: Salesforce Agentforce Script Expert

**Name:** agentforce-script-expert
**Version:** 3.1.0
**Updated:** 2026-04-02
**Description:** Comprehensive reference for designing, reviewing, and fixing Salesforce Agentforce Scripts (NGA format). Covers all YAML blocks, syntax rules, variable management, action definitions, control logic, and best practices for deterministic agent behavior.

---

## Table of Contents
1. [Core Architecture & Logical Blocks](#1-core-architecture--logical-blocks)
2. [YAML Structure: Keys & Indentation](#2-yaml-structure-keys--indentation)
3. [Complete File Skeleton](#3-complete-file-skeleton)
4. [Variables](#4-variables)
5. [Actions: Full Field Reference](#5-actions-full-field-reference)
6. [@utils Utilities & Routing](#6-utils-utilities--routing)
7. [before_reasoning & after_reasoning](#7-before_reasoning--after_reasoning)
8. [Instructions & Expressions](#8-instructions--expressions)
9. [The 5 Levels of Determinism](#9-the-5-levels-of-determinism)
10. [Standard Library Functions](#10-standard-library-functions)
11. [Customer Verification Pattern](#11-customer-verification-pattern)
12. [Anti-Patterns & Constraints](#12-anti-patterns--constraints)
13. [Agent Metadata & Lifecycle](#13-agent-metadata--lifecycle)
14. [Salesforce CLI Reference](#14-salesforce-cli-reference)
15. [Agent Access & Permissions](#15-agent-access--permissions)
16. [Agent User Setup](#16-agent-user-setup)
17. [Topic-Level System Overrides](#17-topic-level-system-overrides)
18. [N-ary Conditions & Complex Logic](#18-n-ary-conditions--complex-logic)
19. [Escalation & Connection Block](#19-escalation--connection-block)
20. [Validation, Debugging & Production Gotchas](#20-validation-debugging--production-gotchas)
21. [Known Platform Issues & Workarounds](#21-known-platform-issues--workarounds)
22. [Action Chaining & Sequencing](#22-action-chaining--sequencing)
23. [Variables: Lists & Index Iteration](#23-variables-lists--index-iteration)
24. [Context Engineering](#24-context-engineering)

---

## 1. Core Architecture & Logical Blocks

Agent Script orchestrates the Atlas Reasoning Engine by combining natural language flexibility with programmatic determinism. Every file is composed of these top-level blocks (declared in this order):

| Block | Purpose |
|---|---|
| `system:` | Global persona, welcome/error messages applied across all topics |
| `config:` | Agent metadata: name, type, description |
| `variables:` | Session-scoped state trackers (mutable or linked to CRM) |
| `language:` | Locale configuration |
| `connection <type>:` | Channel settings (`messaging` or `voice`) |
| `start_agent <name>:` | Entry point — evaluates intent and routes to the first topic |
| `topic <name>:` | Domain-specific handler (one per "Job to be Done") |

### Agent Types
The `config.agent_type` field must be one of:
- `AgentforceServiceAgent` — customer-facing service agent
- `AgentforceEmployeeAgent` — internal employee-facing agent

### Instruction Modes
Inside a `reasoning:` block, instructions use one of two modes:
- **Template mode** (`instructions: |`) — static text with simple variable injection only
- **Procedural mode** (`instructions: ->`) — executes logic alongside text; all plain-text lines must be prefixed with `|`

---

## 2. YAML Structure: Keys & Indentation

### Topic Key Naming
Keys use a **compound format**: `<block_type> <identifier>`

```yaml
start_agent topic_selector:    # entry point — always this exact compound key
topic order_status:            # a regular topic
topic customer_verification:   # another topic
```

The identifier portion must be `snake_case` with no spaces. The `start_agent` block is always named `start_agent topic_selector`.

### Indentation Reference
Agent Script YAML uses **spaces only** (no tabs). Levels are strict:

```yaml
system:                                    # 0 — top-level block
    instructions: "..."                    # 4 spaces
    messages:                              # 4 spaces
        welcome: "..."                     # 8 spaces
        error: "..."                       # 8 spaces

config:                                    # 0 — top-level block
  agent_label: "..."                       # 2 spaces  ← config uses 2-space indent
  developer_name: "..."                    # 2 spaces
  agent_type: "..."                        # 2 spaces
  description: "..."                       # 2 spaces

variables:                                 # 0
    my_var: mutable string = ""            # 4 spaces — declaration
        description: "..."                 # 8 spaces
    crm_var: linked string                 # 4 spaces
        source: @MessagingSession.Id       # 8 spaces
        description: "..."                 # 8 spaces

language:                                  # 0
    default_locale: "en_US"               # 4 spaces
    additional_locales: ""                 # 4 spaces
    all_additional_locales: False          # 4 spaces

connection messaging:                      # 0
    adaptive_response_allowed: True        # 4 spaces

topic my_topic:                            # 0
    label: "..."                           # 4 spaces
    description: "..."                     # 4 spaces
    reasoning:                             # 4 spaces
        before_reasoning:                  # 8 spaces
            if @variables.x == "y":        # 12 spaces
                transition to @topic.z     # 16 spaces
        instructions: ->                   # 8 spaces
            | Do something.               # 12 spaces — procedural text line
        after_reasoning:                   # 8 spaces
            if @variables.done == True:    # 12 spaces
                transition to @topic.next  # 16 spaces
        actions:                           # 8 spaces — reasoning action references
            my_action: @actions.my_action  # 12 spaces
                with param = ...           # 16 spaces — slot-fill
    actions:                               # 4 spaces — action definitions
        my_action:                         # 8 spaces
            description: "..."             # 12 spaces
            target: "flow://..."           # 12 spaces
            inputs:                        # 12 spaces
                "inputName": string        # 16 spaces — name is quoted
                    is_required: True      # 20 spaces
            outputs:                       # 12 spaces
                "outputName": string       # 16 spaces — name is quoted
                    is_displayable: False  # 20 spaces
```

---

## 3. Complete File Skeleton

Minimal but complete agent showing all blocks and their relationships:

```yaml
system:
    instructions: "You are a helpful service agent for Acme Corp."
    messages:
        welcome: "Hi, I'm the Acme Assistant. How can I help you today?"
        error: "Sorry, something went wrong. Please try again."

config:
  default_agent_user: "agentforce_service_agent@acme.ext"
  agent_label: "Acme Service Agent"
  developer_name: "Acme_Service_Agent"
  agent_type: "AgentforceServiceAgent"
  description: "Handles customer service requests for Acme Corp."

variables:
    IsVerified: mutable boolean = False
        description: "Whether the customer has been verified."
    ContactId: linked string
        source: @MessagingEndUser.ContactId
        description: "Salesforce Contact ID of the messaging user."

language:
    default_locale: "en_US"
    additional_locales: ""
    all_additional_locales: False

connection messaging:
    adaptive_response_allowed: True

start_agent topic_selector:
    label: "Topic Selector"
    description: "Routes user to the correct topic based on intent."
    reasoning:
        instructions: ->
            | Select the best tool based on the user's intent.
        actions:
            go_to_order_status: @utils.transition to @topic.order_status
            go_to_escalation: @utils.transition to @topic.escalation

topic order_status:
    label: "Order Status"
    description: "Handles order status enquiries."
    reasoning:
        before_reasoning:
            if @variables.IsVerified == False:
                transition to @topic.customer_verification
        instructions: ->
            | Retrieve the order status and present it to the user.
            | ALWAYS call get_order_status before answering.
        actions:
            get_order_status: @actions.get_order_status
                with orderId = ...
    actions:
        get_order_status:
            description: "Retrieves order status from the backend system."
            require_user_confirmation: False
            include_in_progress_indicator: True
            progress_indicator_message: "Looking up your order..."
            target: "flow://Get_Order_Status"
            inputs:
                "orderId": string
                    description: "The order ID to look up."
                    is_required: True
                    is_user_input: True
                    complex_data_type_name: "lightning__textType"
            outputs:
                "status": string
                    description: "The current order status."
                    is_displayable: True
                    is_used_by_planner: True
                    complex_data_type_name: "lightning__textType"

topic escalation:
    label: "Escalation"
    description: "Transfers the user to a live human agent."
    reasoning:
        instructions: ->
            | Transfer the user to a live agent if they explicitly request it.
            | If escalation fails, offer to log a support case instead.
        actions:
            escalate_to_human: @utils.escalate
```

---

## 4. Variables

### Declaration Syntax

```yaml
variables:
    # Mutable — read/write, requires a default value
    order_count:   mutable number = 0
        description: "Number of orders retrieved this session."
    status_flag:   mutable boolean = False
        description: "Tracks whether processing is complete."
    selected_item: mutable string = ""
        description: "Item selected by the user."
    results:       mutable list[object] = []
        description: "List of search results."

    # Linked — read-only, bound to a Salesforce CRM record field
    session_id: linked string
        source: @MessagingSession.Id
        description: "Current messaging session ID."
    contact_id: linked string
        source: @MessagingEndUser.ContactId
        description: "Contact ID of the end user."
```

### Supported Types

| Type | Mutable | Linked |
|---|---|---|
| `string` | ✓ | ✓ |
| `number` | ✓ | ✓ |
| `boolean` | ✓ | ✓ |
| `date` | ✓ | ✓ |
| `timestamp` | ✓ | ✓ |
| `currency` | ✓ | ✓ |
| `id` | ✓ | ✓ |
| `object` | ✓ only | ✗ |
| `list[string]`, `list[number]`, `list[object]`, etc. | ✓ only | ✗ |

**Rules:**
- `linked` variables **cannot** use `object` or `list` types — scalars only
- `linked` variables **do not** have a default value
- `mutable` variables **must** have a default value (e.g., `""`, `0`, `False`, `[]`)

### Common Linked Sources

| Source | Description |
|---|---|
| `@MessagingSession.Id` | Current session ID |
| `@MessagingSession.MessagingEndUserId` | End user platform ID |
| `@MessagingSession.EndUserLanguage` | End user preferred language |
| `@MessagingEndUser.ContactId` | Salesforce Contact ID |
| `@MessagingEndUser.Name` | End user display name |

### In-Instruction Variable Usage

```yaml
instructions: ->
    | set @variables.status = "pending"
    | set @variables.count = @variables.count + 1
    | set @variables.caseId = @outputs.caseId        # capture action output
    | The case ID is {!@variables.caseId}.            # inject into prompt text
    | run @actions.create_case                        # force deterministic execution
```

---

## 5. Actions: Full Field Reference

### Reasoning Block Reference (inside `reasoning.actions:`)
Links the LLM to an action and controls how it is invoked.

```yaml
reasoning:
    actions:
        my_action: @actions.my_action              # reference to defined action
            with orderId = ...                     # slot-fill: LLM extracts from conversation
            with customerId = @variables.cid       # explicit bind: uses variable value
            available when @variables.IsVerified == True   # gate: LLM cannot see this unless true
            description: "Use this to retrieve order details."
```

**Rules:**
- Only **one `available when` clause** per action. Use `and`/`or` for multiple conditions.
- `with param = ...` (slot-fill) should be kept to 4 or fewer per action to avoid interrogation loops.

### Action Definition Block (inside topic `actions:`)

```yaml
actions:
    action_name:
        description: "What this does — used by the LLM to decide when to call it."
        label: "Human-readable label"                      # optional
        require_user_confirmation: False                   # prompt user before executing
        include_in_progress_indicator: True                # show a spinner while running
        progress_indicator_message: "Looking that up..."   # spinner text (optional)
        source: "My_Flow_API_Name"                         # Salesforce API name (optional)
        target: "flow://My_Flow_API_Name"                  # required — invocation URI
        inputs:
            "paramName": string                            # quoted name, then type
                description: "What this input is for."
                label: "Param Label"
                is_required: True                          # True = action fails if missing
                is_user_input: True                        # False = system/internal param, skipped by LLM
                complex_data_type_name: "lightning__textType"
        outputs:
            "outputName": string                           # quoted name, then type
                description: "What this output contains."
                label: "Output Label"
                is_displayable: False                      # False = LLM cannot show raw value to user
                is_used_by_planner: True                   # True = LLM can reason about this value
                complex_data_type_name: "lightning__textType"
```

### Action Target Protocols

| Protocol | Usage |
|---|---|
| `flow://FlowApiName` | Salesforce Flow |
| `apex://ClassName` | Apex invocable method |
| `generatePromptResponse://TemplateName` | Prompt Template (LLM sub-call) |
| `api://EndpointName` | External API |
| `externalService://ServiceName` | External Service |
| `standardInvocableAction://ActionName` | Standard invocable action |
| `retriever://ConfigName` | RAG knowledge retrieval |

### `complex_data_type_name` Mapping

| NGA Type | `complex_data_type_name` |
|---|---|
| `string` | `lightning__textType` |
| `number` | `lightning__numberType` |
| `boolean` | `lightning__booleanType` |
| `object` | `lightning__recordInfoType` |
| `list[object]` | `lightning__recordInfoType` |
| `list[string]` | `lightning__textType` |
| Rich text / HTML | `lightning__richTextType` → stored as `object` |

### Output Flags — Zero-Hallucination Guardrails

| Flag | Value | Effect |
|---|---|---|
| `is_displayable` | `False` | LLM **cannot** show this value to the user |
| `is_displayable` | `True` | LLM may render this value in its response |
| `is_used_by_planner` | `True` | LLM can reason about this value for next steps |
| `is_used_by_planner` | `False` | LLM is completely blind to this value |
| `filter_from_agent` | `True` | Hides output from user-facing response while still allowing planner use; prevents hallucination on large/complex responses |

**Pattern:** Sensitive backend data (IDs, internal codes) → `is_displayable: False`, `is_used_by_planner: True`

**Pattern:** Large action responses (records, lists) → also add `filter_from_agent: True` to prevent state corruption from oversized payloads.

---

## 6. @utils Utilities & Routing

### Complete @utils Reference

| Utility | Syntax | Description |
|---|---|---|
| `@utils.transition` | `@utils.transition to @topic.<name>` | Permanent handoff to another topic |
| `@utils.escalate` | `@utils.escalate` | Transfer conversation to a live human agent |
| `@utils.setVariables` | `@utils.setVariables` | Slot-fill multiple variables from conversation in a single LLM turn |
| `@topic.X` | `@topic.X` in `reasoning.actions` | Delegate to child topic; control returns to parent to synthesize response |

> **Note:** `@utils.setVariables` is useful when you need to collect several values at once without calling a full action. The LLM fills the declared variables from the conversation context.

### Three Routing Patterns

| Pattern | Syntax | Who generates response | When to use |
|---|---|---|---|
| **Handoff (Transition)** | `@utils.transition to @topic.X` in `reasoning.actions` | Child topic | Terminal states, escalations, phase changes |
| **Supervision (Delegation)** | `@topic.X` in `reasoning.actions` | Parent topic synthesizes | DRY sub-routines, shared action sets |
| **Deterministic Jump** | `transition to @topic.X` in `before/after_reasoning` | Next topic | Conditional routing with no LLM involvement |

### DRY Architecture via Supervision

Define a shared action once in a delegate topic. All other topics reference it via supervision — control returns to the caller after execution.

```yaml
topic order_management:
    reasoning:
        instructions: ->
            | Handle the user's order request using the appropriate action.
        actions:
            check_order:  @topic.order_lookup    # delegates — control returns here
            cancel_order: @topic.order_cancel    # delegates — control returns here
```

---

## 7. before_reasoning & after_reasoning

These blocks execute **outside the LLM context** — 100% deterministic, no AI credit consumed, no hallucination possible. They are the primary tool for enforcing critical business logic.

### Placement
Both blocks sit directly under `reasoning:`, at the same level as `instructions:` and `actions:`.

### Syntax Rules
- Content goes **directly** under the block — no `instructions:` wrapper, no `|` prefix
- Supports: `if/then`, `transition to`, `run`, `set`
- Use `transition to @topic.X` (no `@utils.` prefix) — this is the deterministic jump form
- No nested `if` — use compound `and`/`or` conditions

### before_reasoning
Executes **before** the LLM processes the turn. Use for: guard clauses, enforcing preconditions, pre-loading state.

```yaml
reasoning:
    before_reasoning:
        if @variables.IsVerified == False:
            transition to @topic.customer_verification
        if @variables.case_created == True:
            transition to @topic.case_confirmation
        run @actions.load_customer_profile
    instructions: ->
        | Help the customer with their request.
```

### after_reasoning
Executes **after** the LLM responds. Use for: advancing a state machine, post-condition checks, completion detection.

```yaml
reasoning:
    instructions: ->
        | Collect the required information from the user.
    after_reasoning:
        if @variables.all_fields_collected == True:
            transition to @topic.submit_request
        if @variables.retry_count >= 3:
            transition to @topic.escalation
```

### Same-Turn Variable Availability
Variables set by actions called during the **current turn** are available in `after_reasoning`. However, if the LLM chose *not* to call the action, the variable retains its previous value. To guarantee the variable is set, use `run @actions.name` inside `instructions:` to force the call before `after_reasoning` evaluates.

---

## 8. Instructions & Expressions

### Safe Operator Set

| Category | Supported | NOT Supported |
|---|---|---|
| Comparison | `==`, `<>`, `<`, `<=`, `>`, `>=`, `is`, `is not` | — |
| Logical | `and`, `or`, `not` | — |
| Arithmetic | `+`, `-` | `*`, `/`, `%` |
| Nesting | compound `if x and y:` | nested `if x: then if y:` |

### Procedural Instruction Patterns

```yaml
instructions: ->
    # Variable assignment
    | set @variables.status = "active"

    # Capture action output into a variable
    | set @variables.caseId = @outputs.caseId

    # Inject variable value into prompt text
    | The case ID is {!@variables.caseId}.

    # Force an action — LLM cannot skip this call
    | run @actions.create_case

    # Conditional transition
    | if @variables.IsVerified == False:
    |     transition to @topic.verification

    # Compound condition
    | if @variables.attempt_count >= 3 and @variables.IsVerified == False:
    |     transition to @topic.escalation
```

### available when (Action/Topic Gating)
Prevents the LLM from seeing an action unless a condition is met. **One clause per action only** — combine multiple conditions with `and`/`or`.

```yaml
reasoning:
    actions:
        submit_case: @actions.submit_case
            available when @variables.IsVerified == True
        premium_support: @actions.premium_support
            available when @variables.tier == "premium" and @variables.IsVerified == True
```

### Prompt Engineering Guidelines
- Use **commanding verbs**: "Retrieve", "Verify", "Calculate", "Confirm"
- Use **capitalization** for hard boundaries: `ALWAYS`, `NEVER`, `DO NOT`
- Use **RAG actions** (`retriever://`) for complex policies instead of hard-coding rules in instructions
- Keep topics to **~25–40 lines** of instructions. Beyond that, decompose into phase topics.

---

## 9. The 5 Levels of Determinism

Apply progressively when designing or refactoring. Higher levels give more control but require more explicit design.

| Level | Technique | When to use |
|---|---|---|
| **1. Instruction-free** | No instructions — pure LLM autonomy | Prototyping only |
| **2. Instructions** | Natural language `instructions:` block | Guiding tone, scope, and behavior |
| **3. Data Grounding** | `retriever://` RAG, Prompt Templates | Preventing knowledge hallucination |
| **4. Variables** | State tracking + `available when` gating | Multi-step flows, conditional logic |
| **5. Deterministic Actions** | `before/after_reasoning`, `run @actions.x`, forced transitions | Critical operations — financial, legal, case creation |

### Phase Decomposition Pattern
Break any topic exceeding ~30 lines into dedicated phase topics. Use `after_reasoning` to advance phases without LLM involvement:

```
[collect_info] --(after_reasoning: all_fields_collected == True)--> [confirm_details]
                                                                    --(after_reasoning: confirmed == True)--> [submit]
```

Each phase topic is ~25 lines max, has a single clear responsibility, and transitions deterministically to the next.

---

## 10. Standard Library Functions

**Text Functions:**
- `text.contains(string, substring)` → `boolean`
- `text.concat(string1, string2)` → `string`
- `text.is_empty(string)` → `boolean` (true if null or empty string)

**List Functions:**
- `list.length(list)` → `number`
- `list.contains(list, item)` → `boolean`
- `list.add(list, item)` → `list` (returns new list with item appended)

**Date Functions:**
- `date.today()` → `date` (current date)
- `date.now()` → `timestamp` (current datetime)

**Usage in procedural instructions:**

```yaml
instructions: ->
    | if text.is_empty(@variables.email):
    |     set @variables.status = "missing_email"
    | if list.contains(@variables.selected_items, "premium"):
    |     transition to @topic.premium_flow
    | if list.length(@variables.results) == 0:
    |     transition to @topic.no_results
```

---

## 11. Customer Verification Pattern

When a topic related to customer verification or identity authentication exists, declare this canonical variable set. These names and sources are the standard for all auth flows.

```yaml
variables:
    # Linked — from CRM session context (read-only)
    EndUserId: linked string
        source: @MessagingSession.MessagingEndUserId
        description: "End user platform ID. Also referred to as MessagingEndUser Id."
    RoutableId: linked string
        source: @MessagingSession.Id
        description: "Current session ID. Also referred to as MessagingSession Id."
    ContactId: linked string
        source: @MessagingEndUser.ContactId
        description: "Salesforce Contact ID of the end user."
    EndUserLanguage: linked string
        source: @MessagingSession.EndUserLanguage
        description: "End user preferred language."

    # Mutable — written during the verification flow
    VerifiedCustomerId: mutable string = ""
        description: "Stores the verified customer ID after successful authentication."
    VerificationAttempts: mutable number = 0
        description: "Tracks the number of failed verification attempts."
    IsVerified: mutable boolean = False
        description: "Whether the customer has been successfully verified."
```

**Guard pattern** — add to `before_reasoning` in every sensitive topic:

```yaml
before_reasoning:
    if @variables.IsVerified == False:
        transition to @topic.customer_verification
```

**Lockout pattern** — inside the verification topic's `after_reasoning`:

```yaml
after_reasoning:
    if @variables.IsVerified == True:
        transition to @topic.topic_selector
    if @variables.VerificationAttempts >= 3:
        transition to @topic.escalation
```

---

## 12. Anti-Patterns & Constraints

1. **Manual topic tracking**: Do not use `set @variables.current_topic = "X"`. The framework tracks state natively — duplicating it creates synchronization bugs.

2. **`actions:` at root level**: `actions:` may only exist inside a `topic <name>:` block, never at the top level of the file.

3. **Missing required inputs**: Actions with `is_required: True` inputs fail silently if the input is not bound. Always bind or slot-fill every required input.

4. **Too many slot-fills**: More than 4–5 `with param = ...` per action causes interrogation loops and increases hallucination risk. Pre-bind from variables wherever possible.

5. **Same-turn variable race condition**: Checking a variable in `after_reasoning` that was supposed to be set by an action the LLM *might not have called*. Fix: use `run @actions.name` in `instructions:` to force the call, or handle the unset case explicitly in `after_reasoning`.

6. **`object` or `list` type as `linked`**: Only scalar types (`string`, `number`, `boolean`, `date`, etc.) can be `linked`. Objects and lists must always be `mutable`.

7. **Nested `if` statements**: `if x: then if y:` is not supported. Use `if x and y:` or flatten into sequential statements.

8. **`instructions:` wrapper in before/after_reasoning**: These blocks must not use an `instructions:` key or `|` prefixes. Direct statements only.

9. **Circular topic references**: The runtime caps iterations at ~3–4 per turn. Circular transitions will break out and revert to the Topic Selector.

10. **Multiple `available when` clauses**: Only one `available when` per action is supported. Combine conditions using `and`/`or`.

11. **`is_user_input: False` on fields the user must provide**: Setting `is_user_input: False` tells the LLM the value is a system/internal parameter and it will not prompt the user for it. Only use this for params populated from variables or constants.

12. **Monolithic topics**: Topics with hundreds of lines overload the LLM context window, causing hallucination and cognitive overload. Break into phase topics of ~25–40 lines each with deterministic `after_reasoning` transitions between them.

---

*(Note: ISSUE-001 — instructions resolving only on topic entry — was resolved February 2026. Variables now correctly re-evaluate across iterations within the same turn. Run-then-if patterns within the same topic are valid.)*

---

## 13. Agent Metadata & Lifecycle

### Two Independent Metadata Domains

```
AUTHORING DOMAIN (developer-owned, exists before any publish)
  AiAuthoringBundle
    ├── .agent                  (Agent Script source — the editable text file)
    └── .bundle-meta.xml        (metadata; optional <target> links to published version)

RUNTIME DOMAIN (created by publish — do NOT edit directly)
  Bot                           (top-level container, one per agent)
    └── BotVersion              (one per published version)
          └── GenAiPlannerBundle (versioned compiled bundle)
                └── local topics and actions
```

**AiAuthoringBundle forms:**
- **Naked** (e.g., `My_Agent`) — always points to the highest DRAFT; the only writable surface
- **Version-suffixed** (e.g., `My_Agent_1`) — frozen snapshot; read-only

**Retrieve after publish** locks the authoring bundle via a `<target>` tag in `bundle-meta.xml`. Recovery: remove `<target>` from bundle-meta.xml and redeploy.

**`Agent:X` pseudo-type** covers the runtime domain (Bot, BotVersion, GenAiPlannerBundle). Does **NOT** include AiAuthoringBundle.

### File Locations

```
<packageDirectory>/main/default/aiAuthoringBundles/<Developer_Name>/
    <Developer_Name>.agent
    <Developer_Name>.bundle-meta.xml
```

### Deploy vs. Publish

| Operation | What it does | Creates runtime? |
|---|---|---|
| `sf project deploy start` | Stages `AiAuthoringBundle` metadata | No |
| `sf agent publish authoring-bundle` | Creates Bot + BotVersion + GenAiPlannerBundle | Yes |

### Recommended 6-Step Pipeline

```bash
# 1. Generate boilerplate (--no-spec is MANDATORY — omitting causes CLI hang)
sf agent generate authoring-bundle --json --no-spec --name "My Agent" --api-name My_Agent

# 2. Edit the .agent file

# 3. Deploy (stages metadata, validates backing logic existence via Invocable Action Registry)
sf project deploy start --json --metadata AiAuthoringBundle:My_Agent

# 4. Validate syntax
sf agent validate authoring-bundle --json --api-name My_Agent

# 5. Publish (creates runtime entities)
sf agent publish authoring-bundle --json --api-name My_Agent

# 6. Activate
sf agent activate --json --api-name My_Agent_Bot
```

**Deploy validation note:** Deploy checks that referenced flows/apex classes *exist* via the Invocable Action Registry, but does NOT validate parameter names or types.

### Lifecycle Operations

| Operation | Notes |
|---|---|
| Delete | DRAFT-only agents can be deleted via CLI; published agents require Setup UI |
| Rename | Do not rename in-place; create a new agent with the desired name |
| Open in Builder | `sf org open authoring-bundle` (all) or `sf org open agent --api-name <Bot>` |
| Test lifecycle | `sf agent test create` → `sf agent test run --wait 5` → `sf agent test results` |

**Tests run against activated published agents only.** `sf agent test create` does NOT auto-deploy to the org.

---

## 14. Salesforce CLI Reference

### Core Command Summary

| Command | Purpose |
|---|---|
| `sf agent generate authoring-bundle` | Create new agent bundle (always use `--no-spec`) |
| `sf agent validate authoring-bundle` | Check syntax before deployment |
| `sf project deploy start` | Push backing logic and AiAuthoringBundle |
| `sf agent publish authoring-bundle` | Convert bundle into runtime agent |
| `sf agent activate` | Make published agent available |
| `sf agent deactivate` | Deactivate a published agent |
| `sf agent test create` | Create test spec in org |
| `sf agent test run --wait 5` | Run tests and wait for results |
| `sf agent test results` | Retrieve test results |
| `sf agent preview start` | Interactive test without publishing |
| `sf org open authoring-bundle` | Open all bundles in Agentforce Studio |
| `sf org open agent --api-name <Bot>` | Open specific published agent |

### Critical CLI Rules

- Always place `--json` immediately after the base command (`sf agent generate --json ...`)
- Use **space-separated** (not comma-separated) metadata arguments: `--metadata "TypeA:Name TypeB:Name"`
- Quote wildcard patterns: `--metadata "AiAuthoringBundle:*"`
- Agent metadata types are **NOT queryable via SOQL** — use CLI retrieve commands instead
- `sf bot` commands were removed in sf CLI v2 — use `sf agent` exclusively
- Deployment with `--source-dir` may hang if `AiEvaluationDefinition` files are present — use `--metadata AiAuthoringBundle:MyAgent` instead

### CI/CD Pipeline (8 Steps)

```bash
# 1. Retrieve current state
sf project retrieve start --json --metadata "AiAuthoringBundle:My_Agent"

# 2. Edit .agent source file

# 3. Deploy backing logic (flows/apex) and authoring bundle together
sf project deploy start --json --metadata "AiAuthoringBundle:My_Agent Flow:My_Flow ApexClass:MyClass"

# 4. Validate
sf agent validate authoring-bundle --json --api-name My_Agent

# 5. Publish
sf agent publish authoring-bundle --json --api-name My_Agent

# 6. Activate
sf agent activate --json --api-name My_Agent_Bot

# 7. Run tests
sf agent test run --json --api-name My_Agent_Bot --wait 5

# 8. Verify
sf agent test results --json --api-name My_Agent_Bot
```

---

## 15. Agent Access & Permissions

### Making a Published Agent Visible to Users

Agents require a `PermissionSet` with `<agentAccesses>` to appear in the Lightning Copilot panel.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">
    <agentAccesses>
        <agentName>My_Agent</agentName>  <!-- must exactly match developer_name -->
        <enabled>true</enabled>
    </agentAccesses>
    <hasActivationRequired>false</hasActivationRequired>
    <label>My Agent Access</label>
</PermissionSet>
```

```bash
# Deploy the permission set
sf project deploy start --json --metadata "PermissionSet:My_Agent_Access"

# Assign to a user
sf org assign permset --json --name My_Agent_Access --on-behalf-of user@example.com
```

### Visibility Troubleshooting

| Symptom | Cause | Solution |
|---|---|---|
| No Agentforce icon in UI | `CopilotSalesforceUser` PS not assigned | Assign `CopilotSalesforceUser` permission set |
| Icon visible, agent not in list | Missing `<agentAccesses>` | Add `<agentAccesses>` to permission set |
| Agent visible, errors on open | Agent not fully published/active | Verify `BotVersion` Status = Active |
| "Agent not found" error | Developer name mismatch | Ensure `<agentName>` exactly matches `developer_name` in config |

### Apex Class Permissions

Einstein Agent User must have access to **every** Apex class referenced by **any** action across **all** topics. Missing even one class causes the whole agent to fail.

- System permission set: `AgentforceServiceAgentUser`
- Custom permission set: `{AgentName}_Access` — must explicitly list all `<classAccesses>` for every Apex class used

> **Warning:** The auto-generated `NextGen_{AgentName}_Permissions` permission set is frequently incomplete. Always build the custom PS manually.

---

## 16. Agent User Setup

### Service vs. Employee Agents

| Type | User Model | Permissions |
|---|---|---|
| `AgentforceServiceAgent` | Dedicated Einstein Agent User account | Consistent, uniform across all sessions |
| `AgentforceEmployeeAgent` | Runs as the logged-in user | Respects individual sharing rules |

### Service Agent 6-Step Setup

```bash
# Step 1: Create Einstein Agent User (scratch org)
sf org create user --json --definition-file config/agent-user.json

# Step 1 (production/sandbox): Use sf data create record
sf data create record --json --sobject User --values "Username=agent@myorg.ext ProfileId=<EinsteinAgentProfile> ..."

# Step 2: Assign system permission set (BEFORE publishing)
sf org assign permset --json --name AgentforceServiceAgentUser --on-behalf-of agent@myorg.ext

# Step 3: Create custom permission set listing ALL Apex classes
# (create {AgentName}_Access.permissionset-meta.xml manually)

# Step 4: Assign custom permission set
sf org assign permset --json --name MyAgent_Access --on-behalf-of agent@myorg.ext

# Step 5: Set in agent config
#   default_agent_user: "agent@myorg.ext"

# Step 6: Deploy → validate → publish → activate
```

> **Critical:** `default_agent_user` must reference a user with an Einstein Agent license. An incorrect license produces a misleading "Internal Error, try again later" — not a permissions error.

---

## 17. Topic-Level System Overrides

Topics can define their own `system:` block to **completely replace** the global system instructions for that topic. This enables persona switching and specialist modes.

### Hierarchy

| Level | Location | Scope | Dynamic? |
|---|---|---|---|
| Global `system:` block | Top-level file | All topics (baseline) | No — static text only |
| Topic `system:` block | Inside `topic <name>:` | Overrides global for that topic | No — static text only |
| Topic `reasoning.instructions:` | Inside `reasoning:` | Extends/adjusts within topic | Yes — variables and conditionals |

### Topic-Level System Override Syntax

```yaml
topic formal_mode:
    label: "Formal Communication"
    description: "Professional business communication mode"

    # Completely replaces global system: for this topic only
    system:
        instructions: "You are a formal business professional. Use professional language at all times. Address users as Sir or Madam. Avoid contractions and slang. Maintain a respectful, corporate tone."

    reasoning:
        instructions: ->
            | Good day. How may I be of assistance?
        actions:
            back: @utils.transition to @topic.topic_selector
```

### Dynamic Per-User Behavior via Reasoning Instructions

Use variables to branch behavior within a topic's `reasoning.instructions:` — this is the correct pattern for dynamic adjustments (topic `system:` only accepts static text):

```yaml
topic support:
    reasoning:
        instructions: ->
            if @variables.customer_tier == "vip":
                | PRIORITY CUSTOMER — provide white-glove service.
                | You have authority to offer 20% discounts.

            if @variables.customer_tier == "premium":
                | PREMIUM CUSTOMER — provide thorough, detailed responses.
                | You can offer 10% discounts.

            if @variables.business_hours == False:
                | NOTE: Outside business hours. Do not transfer to live agents.

            | Help the customer with their request.
```

**Best practice:** Global `system:` for universal guardrails → topic `system:` for complete persona changes → topic `reasoning.instructions:` for context-aware personalization.

---

## 18. N-ary Conditions & Complex Logic

### Flat Compound Conditions

Agent Script does **not** support nested `if` statements. Use compound `and`/`or` on a single `if` line instead.

```yaml
# ❌ INVALID — nested if
before_reasoning:
    if @variables.a == True:
        if @variables.b == True:
            transition to @topic.x

# ✅ CORRECT — flat N-ary condition
before_reasoning:
    if @variables.a == True and @variables.b == True:
        transition to @topic.x
```

### Grouping with Parentheses

Use parentheses to express mixed `and`/`or` logic:

```yaml
before_reasoning:
    # Premium with any product, OR standard with active warranty
    if (@variables.tier == "premium" and @variables.product_type != None) or (@variables.tier == "standard" and @variables.has_warranty == True):
        transition to @topic.priority_support
```

### N-ary `available when`

```yaml
reasoning:
    actions:
        process_return: @actions.handle_return
            available when @variables.order_exists == True and @variables.within_return_window == True and @variables.item_eligible == True

        use_priority: @actions.priority_service
            available when @variables.tier == "gold" or @variables.tier == "platinum" or @variables.tier == "enterprise"

        expedite: @actions.expedite_order
            available when @variables.product_type == "perishable" and (@variables.status == "pending" or @variables.status == "processing")
```

### Type Notes

- Use `number` — **not** `integer`. The `integer` type is **not supported** in AiAuthoringBundle and will cause errors.
- Boolean literals must be capitalized: `True` / `False` — lowercase `true`/`false` will fail.

---

## 19. Escalation & Connection Block

### Connection Block Syntax

The `connection messaging:` block is required for `@utils.escalate` to work. It defines the Omni-Channel routing destination.

```yaml
# Single channel (singular 'connection')
connection messaging:
    outbound_route_type: "OmniChannelFlow"    # ONLY "OmniChannelFlow" is supported
    outbound_route_name: "My_Omni_Channel_Flow"  # API name of the Omni-Channel Flow
    escalation_message: "Transferring you to a human agent now..."   # required when block is present
    adaptive_response_allowed: True

# Multiple channels (plural 'connections')
connections:
    messaging:
        outbound_route_type: "OmniChannelFlow"
        outbound_route_name: "Chat_Support_Flow"
        escalation_message: "Connecting you to chat support..."
        adaptive_response_allowed: True
    telephony:
        outbound_route_type: "OmniChannelFlow"
        outbound_route_name: "Phone_Support_Flow"
        escalation_message: "Transferring to phone support..."
        adaptive_response_allowed: False
```

> **Warning:** Only `"OmniChannelFlow"` is supported for `outbound_route_type`. Values like `"queue"`, `"skill"`, or `"agent"` cause validation errors.

> **Warning:** `@utils.escalate with reason="..."` syntax is **only** valid in GenAiPlannerBundle. Using it in AiAuthoringBundle causes a SyntaxError.

### CustomerWebClient Surface Post-Publish Patch

Every publish via `sf agent publish` overwrites the GenAiPlannerBundle and drops the `CustomerWebClient` surface. A 6-step manual patch is required after each publish if that surface is needed:

```xml
<!-- Patch XML to add to GenAiPlannerBundle after each publish -->
<plannerSurfaces>
    <adaptiveResponseAllowed>false</adaptiveResponseAllowed>
    <callRecordingAllowed>false</callRecordingAllowed>
    <outboundRouteConfigs>
        <escalationMessage>One moment while I connect you with a support specialist.</escalationMessage>
        <outboundRouteName>Route_from_Your_Agent</outboundRouteName>
        <outboundRouteType>OmniChannelFlow</outboundRouteType>
    </outboundRouteConfigs>
    <surface>SurfaceAction__CustomerWebClient</surface>
    <surfaceType>CustomerWebClient</surfaceType>
</plannerSurfaces>
```

### Prompt Template Action Target

```yaml
actions:
    generate_summary:
        description: "Generate a customer-facing summary."
        inputs:
            "Input:customerName": string       # quoted, with "Input:" prefix
                description: "Customer name"
                is_required: True
            "Input:caseDetails": string
                description: "Case details to summarize"
                is_required: True
        outputs:
            promptResponse: string             # always "promptResponse"
                description: "The generated content."
                is_used_by_planner: True
                is_displayable: True
        target: "generatePromptResponse://My_Prompt_Template"  # quotes required

# Reasoning invocation
reasoning:
    actions:
        run_summary: @actions.generate_summary
            with "Input:customerName" = @variables.customer_name
            with "Input:caseDetails" = @variables.case_details
            set @variables.summary = @outputs.promptResponse
```

**Input mapping:** Agent Script `"Input:fieldName"` → Prompt Template `{!fieldName}`

**Known limitation:** Chained actions using the `run` keyword may fail to map Prompt Template input parameters. Use Prompt Template actions as primary (LLM-invoked) actions, not via `run`.

---

## 20. Validation, Debugging & Production Gotchas

### Credit Costs

| Operation | Cost |
|---|---|
| `transition to @topic.X`, `set @variables.*`, `@utils.escalate` | Free (0 credits) |
| `before_reasoning` / `after_reasoning` execution | Free (0 credits) |
| Action call (Flow, Apex, API) | ~20 credits per call |
| Prompt Template action | ~2–16 credits per call |

**Optimization pattern:** Fetch data once in `before_reasoning:`, cache in variables, reuse across the topic rather than calling the same action multiple times.

### Validation Commands

```bash
# Validate before publish (catches syntax errors, missing references)
sf agent validate authoring-bundle --json --api-name My_Agent

# Retrieve after publish to inspect version lock
sf project retrieve start --json --metadata "AiAuthoringBundle:My_Agent"

# List agent metadata (not SOQL-queryable — must use CLI)
sf project retrieve start --json --metadata "Bot:My_Agent_Bot"
```

### 8-Step Debugging Workflow

1. **Reproduce** with minimal input — isolate the turn/topic where failure occurs
2. **Check `default_agent_user`** — wrong license → "Internal Error" (misleading)
3. **Verify backing logic deployed** — Flow/Apex must exist before publish
4. **Inspect `bundle-meta.xml`** — stale `<target>` lock may prevent edits
5. **Check Apex permissions** — agent user must have access to ALL Apex classes across ALL topics
6. **Look for same-turn race conditions** — check if `after_reasoning` depends on an action the LLM may not have called; fix with `run @actions.X`
7. **Check action output sizes** — large responses can corrupt session state; use `filter_from_agent: True`
8. **Deactivate → republish** — when all else fails, deactivate the Bot, republish, and reactivate

### Reserved Apex Variable Names

Avoid using these names in `@InvocableVariable` declarations — they cause Apex compilation errors:
- `model`
- `description`
- `label`

### Response Size Limit

Agent output is capped at **1 MB** per turn. Return minimal, summarized data from actions.

---

## 21. Known Platform Issues & Workarounds

| # | Issue | Status | Workaround |
|---|---|---|---|
| 1 | `AiEvaluationDefinition` files under `force-app/` cause deployment hang (2+ min) | WORKAROUND | Use `--metadata AiAuthoringBundle:MyAgent` instead of `--source-dir` |
| 2 | `sf agent publish` fails with namespace prefix on `apex://` targets | OPEN | Try `apex://ns__ClassName`, or wrap Apex in a Flow |
| 3 | `require_user_confirmation` does not trigger confirmation dialog | OPEN | Implement manually: two-step pattern with `available when @variables.user_confirmed == True` |
| 4 | Action definitions without an `outputs:` block cause "Internal Error" on publish | WORKAROUND | Always include an `outputs:` block, even if empty |
| 5 | Large action responses cause session state corruption | OPEN | Return minimal data; add `filter_from_agent: True` to large outputs |
| 6 | Agent fails silently if user lacks permission for ANY action | OPEN | Ensure agent user has `{AgentName}_Access` PS with `<classAccesses>` for ALL Apex classes |
| 7 | Dynamic welcome messages (`{!userName}` in `messages.welcome`) not resolved | OPEN | Use static welcome messages; personalize in first topic's instructions |
| 8 | Welcome message line breaks stripped | OPEN | Keep welcome messages on a single line |
| 9 | `CustomerWebClient` plannerSurface dropped on every publish | OPEN | Apply post-publish XML patch (see Section 19) |
| 10 | Comments inside `if` blocks treated as empty body (runtime error) | OPEN | Always include at least one executable statement in every `if` block |
| 11 | Previously valid OpenAPI schemas now fail validation | OPEN | Ensure `info.version` is present; remove non-standard `x-` extensions |
| 12 | `sf bot` CLI commands incompatible with Agent Script | RESOLVED | Use `sf agent` exclusively (sf CLI v2+) |
| 13 | `connections:` plural wrapper block not valid — use singular `connection messaging:` | RESOLVED | Use `connection messaging:` (singular) |
| 14 | Auto-generated `NextGen_{AgentName}_Permissions` PS is often incomplete | OPEN | Build the custom PS manually listing all Apex classes |
| 15 | `EinsteinAgentApiChannel` surfaceType not available on all orgs | OPEN | Use `CustomerWebClient` surfaceType instead |

---

*(Note: ISSUE-001 — instructions resolving only on topic entry — was resolved February 2026. Variables now correctly re-evaluate across iterations within the same turn. Run-then-if patterns within the same topic are valid.)*

---

## 22. Action Chaining & Sequencing

Use `run @actions.x` inside `instructions:` to force multiple actions to execute in a guaranteed sequence within a single turn, independent of LLM planning.

### Single forced call

```yaml
instructions: ->
    | run @actions.load_customer_profile
    | Help the customer with their request.
```

### Sequential chain — fixed order

```yaml
instructions: ->
    | run @actions.verify_eligibility
    | set @variables.eligible = @outputs.eligible
    | if @variables.eligible == False:
    |     transition to @topic.ineligible
    | run @actions.create_case
    | set @variables.caseId = @outputs.caseId
    | The case {!@variables.caseId} has been created.
```

Each `run` fires in order. Later runs can reference outputs from earlier ones via `@outputs.<name>` or a `set` assignment.

### LLM-driven chain via reasoning actions

When the LLM should decide which actions to call (but must call them all), list them all in `reasoning.actions:` and use commanding language:

```yaml
reasoning:
    instructions: ->
        | ALWAYS call search_orders first, then call get_order_details.
        | Do not respond until both actions have been called.
    actions:
        search_orders:     @actions.search_orders
            with customerId = @variables.ContactId
        get_order_details: @actions.get_order_details
            with orderId = ...
```

### Pre-fetch then reason

The most credit-efficient pattern: load data in `before_reasoning` (0 credits), then let the LLM reason over it.

```yaml
reasoning:
    before_reasoning:
        run @actions.load_account_summary
    instructions: ->
        | Using the account summary already loaded, help the customer.
        | Do not call load_account_summary again.
    actions:
        update_contact: @actions.update_contact
            with ...
```

**Rules:**
- `run @actions.x` inside `before/after_reasoning` executes deterministically (0 credits).
- `run @actions.x` inside `instructions:` is still LLM-context but treated as a directive — the LLM is told it must call it.
- Chaining more than ~4 `run` calls in a single topic turn increases latency. Consider splitting into phase topics if sequencing is long.

---

## 23. Variables: Lists & Index Iteration

### Declaring list variables

```yaml
variables:
    results:       mutable list[object] = []
        description: "Search results returned by an action."
    selected_ids:  mutable list[string] = []
        description: "IDs chosen by the user."
    scores:        mutable list[number] = []
        description: "Numeric scores for each result."
```

Supported list element types: `string`, `number`, `boolean`, `object`.

### Reading list length

```yaml
instructions: ->
    | if list.length(@variables.results) == 0:
    |     transition to @topic.no_results
    | There are {!list.length(@variables.results)} results available.
```

### Index-based access

Access individual elements using bracket notation:

```yaml
instructions: ->
    | set @variables.first_id = @variables.selected_ids[0]
    | set @variables.second_id = @variables.selected_ids[1]
```

Indexes are zero-based. Accessing an out-of-bounds index returns `None`.

### Iteration pattern via index variable

Agent Script has no native `for` loop. Simulate iteration with a `mutable number` index counter and topic-to-self transitions:

```yaml
variables:
    results:       mutable list[object] = []
        description: "List of items to process."
    current_index: mutable number = 0
        description: "Current position in the results list."

topic process_results:
    label: "Process Results"
    description: "Iterates through results one at a time."
    reasoning:
        before_reasoning:
            if @variables.current_index >= list.length(@variables.results):
                transition to @topic.done
        instructions: ->
            | Process item {!@variables.current_index}: {!@variables.results[@variables.current_index]}.
            | run @actions.handle_item
            | set @variables.current_index = @variables.current_index + 1
        after_reasoning:
            if @variables.current_index < list.length(@variables.results):
                transition to @topic.process_results
    actions:
        handle_item:
            description: "Processes a single result item."
            target: "flow://Handle_Item"
            inputs:
                "item": object
                    is_required: True
                    is_user_input: False
```

**Warning:** The runtime caps same-topic transitions at ~3–4 per turn to prevent infinite loops. For longer lists, return batch-processed results from an action rather than looping in script.

### Appending to a list

```yaml
instructions: ->
    | set @variables.selected_ids = list.add(@variables.selected_ids, @outputs.newId)
```

`list.add` returns a new list — it does not mutate in place.

### Checking list membership

```yaml
instructions: ->
    | if list.contains(@variables.selected_ids, @variables.target_id):
    |     transition to @topic.already_selected
```

---

## 24. Context Engineering

Context engineering controls what the Atlas Reasoning Engine sees at inference time — the system prompt, conversation history, action outputs, and retrieved knowledge. Poor context hygiene causes hallucination, state corruption, and cost overruns.

### The four context layers

| Layer | Controlled by | How to tune |
|---|---|---|
| **System context** | `system:` + topic `system:` blocks | Keep persona concise; move policy to RAG |
| **Reasoning instructions** | `topic.reasoning.instructions:` | Scope tightly to the topic's job; ~25–40 lines max |
| **Action output context** | `is_displayable`, `is_used_by_planner`, `filter_from_agent` | Expose only what the LLM needs to reason or display |
| **Retrieved knowledge** | `retriever://` action outputs | Gate with `available when`; use `filter_from_agent: True` on large payloads |

### Strategy 1 — Minimize system prompt surface area

Put universal guardrails in `system.instructions`. Put everything else in topic instructions or RAG.

```yaml
system:
    instructions: "You are a helpful service agent for Acme Corp. Never discuss competitor products. Respond in the user's language."
```

Avoid embedding long policy documents or enumerated product lists in `system:` — they bloat every turn's context. Use a `retriever://` action instead.

### Strategy 2 — Output flag discipline

Every action output should declare exactly the context access it needs:

```yaml
outputs:
    "customerId": string
        is_displayable: False       # internal ID — never show to user
        is_used_by_planner: True    # but LLM needs it to call the next action
    "policyText": string
        is_displayable: True        # LLM may quote this to the user
        is_used_by_planner: True
        filter_from_agent: True     # but strip it from session state after display (large payload)
    "debugTrace": string
        is_displayable: False
        is_used_by_planner: False   # LLM is completely blind to this
```

**Default posture:** `is_displayable: False`, `is_used_by_planner: True`. Grant display and visibility deliberately.

### Strategy 3 — Pre-fetch, don't mid-fetch

Fetch lookup data in `before_reasoning` so it enters the LLM context as a given, not as a mid-reasoning tool call:

```yaml
reasoning:
    before_reasoning:
        run @actions.load_customer_tier
    instructions: ->
        | The customer's tier is already loaded.
        | Use it to calibrate your response.
```

This reduces the number of reasoning cycles needed per turn and prevents the LLM from re-fetching data it already has.

### Strategy 4 — Topic decomposition as context scoping

Each topic gets its own reasoning context. A topic with 200 lines of instructions crowds out space for the conversation and action outputs. Decompose:

```
[collect_info]  25 lines → [confirm_details]  20 lines → [submit]  15 lines
```

Each phase topic is small, focused, and transitions deterministically. The LLM only sees the current phase's instructions, not the entire workflow.

### Strategy 5 — RAG for policy and knowledge

Replace hard-coded rules with retrieval:

```yaml
# Instead of this (static, grows without bound):
instructions: ->
    | POLICY: Returns are allowed within 30 days. Exceptions: perishables (7 days),
    | electronics (15 days), software (no returns)...

# Do this:
reasoning:
    instructions: ->
        | run @actions.get_return_policy
        | Apply the retrieved policy to the customer's request.
    actions:
        get_return_policy: @actions.get_return_policy
            available when @variables.product_category is not None
actions:
    get_return_policy:
        description: "Retrieves the applicable return policy for the product category."
        target: "retriever://Return_Policy_KB"
        inputs:
            "category": string
                is_required: True
                is_user_input: False
        outputs:
            "policy": string
                is_displayable: False
                is_used_by_planner: True
                filter_from_agent: True
```

### Strategy 6 — Persona isolation via topic system overrides

When a topic needs a radically different persona (e.g. a legal disclaimer mode, a formal escalation topic), use a topic-level `system:` override rather than conditional logic inside `instructions:`. This gives the LLM a clean context for that topic with no residual signals from the global persona.

```yaml
topic legal_disclaimer:
    system:
        instructions: "You are presenting a legal disclaimer. Read it verbatim. Do not paraphrase, add context, or answer questions about its content."
    reasoning:
        instructions: ->
            | run @actions.get_disclaimer_text
            | Present the retrieved disclaimer text verbatim.
```

### Context engineering anti-patterns

| Anti-pattern | Problem | Fix |
|---|---|---|
| Long `system:` with enumerated rules | Bloats every turn; rules drift out of sync with reality | Move to RAG retriever |
| `is_used_by_planner: True` on all outputs | LLM reasons over irrelevant data; increases hallucination risk | Set `False` for outputs the LLM doesn't need |
| `filter_from_agent: False` on large payloads | Oversized outputs corrupt session state (1 MB cap) | Add `filter_from_agent: True` to large action outputs |
| Monolithic topics (100+ lines) | LLM context crowded; poor instruction adherence | Decompose into phase topics of ~25–40 lines |
| Re-fetching data the LLM already has | Wastes credits; increases turn latency | Pre-fetch in `before_reasoning`; reference via variables |
