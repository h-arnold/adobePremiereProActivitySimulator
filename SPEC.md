# 📄 Technical Specification

## Synthetic Premiere Pro Workflow Automation (PowerShell)

# 1. Overview

## 1.1 Purpose

This system simulates a **human-driven editing workflow in Adobe Premiere Pro** to help an IT team diagnose:

* Network performance issues
* Storage latency / throughput problems
* UI responsiveness under load
* Playback stability

It achieves this by:

* Launching two Google Chrome instances with predefined URLs
* Launching Premiere Pro with a known project
* Simulating realistic keyboard-driven interactions
* Sampling network latency during each simulated task
* Sampling system CPU and memory load during each simulated task
* Introducing human-like timing jitter
* Logging all actions and outcomes

---

## 1.2 Design Philosophy

The system follows these principles:

* **Deterministic control with controlled randomness** (jitter)
* **Separation of concerns** (browser launch, focus, input, orchestration, logging)
* **Fail-safe operation** (no blind input without focus)
* **Observability-first design** (comprehensive logging)
* **Environment-controlled execution** (not general desktop automation)

---

## 1.3 Key Constraints

* No official automation API for Premiere Pro playback workflows
* UI Automation support is **partial and unreliable for timeline controls**
* Keyboard simulation is required for playback/scrubbing
* Windows focus behaviour is **non-deterministic without explicit control**
* Chrome launch must occur before Premiere workflow execution begins
* Ping telemetry must run at a fixed `1` second interval during each simulated task
* CPU and memory telemetry must run at the same cadence as ping telemetry during each simulated task

---

# 2. System Architecture

## 2.1 Components

The system is divided into five core components:

### 1. Browser Launcher

Opens two Google Chrome instances with predefined URLs before Premiere Pro automation begins.

### 2. Focus Manager

Ensures Premiere Pro is the active window.

### 3. Input Player

Executes keyboard-driven workflow actions with jitter.

### 4. Workflow Controller

Coordinates execution, lifecycle, retries, browser launch, telemetry, and failure handling.

### 5. Logging & Telemetry

Captures detailed execution data for diagnostics, including per-task ping summaries and per-task CPU and memory load summaries.

---

## 2.2 High-Level Flow

```text
Start
  ↓
Load Script Constants
  ↓
Load Config
  ↓
Launch Chrome Instances
  ↓
Launch Premiere / Project
  ↓
Wait for Window Ready
  ↓
[Loop]
  → Start Telemetry Sampling
  → Focus Premiere
  → Verify Focus
  → Execute Action
  → Apply Jitter
  → Stop Telemetry Sampling
  → Log Result
  → Write Ping Summary
  → Write System Load Summary
[End Loop]
  ↓
Write Summary
  ↓
End
```

---

# 3. Configuration Specification

## 3.1 Script-Top Constants

The script must expose explicit constants at the top of the file for browser launch and network telemetry:

```powershell
$ChromeUrls = @(
    'https://example-1'
    'https://example-2'
)

$PingTarget = 'google.com'
```

Rules:

* Exactly two Chrome URLs are required for v1 execution
* Constants are defined before the main configuration object
* The configuration object may reference these constants, but the source of truth remains the script-top constants

---

## 3.2 Configuration Model

All tunable values must be defined in a **single top-level configuration object**:

```powershell
$Config = @{ ... }
```

This object may hydrate its browser and telemetry sections from the script-top constants.

---

## 3.3 Configuration Sections

### 3.3.1 Browser Settings

| Field                 | Description                                |
| --------------------- | ------------------------------------------ |
| ExecutablePath        | Path to `chrome.exe` or launch command     |
| Urls                  | Two URLs sourced from script constants     |
| LaunchCount           | Fixed at `2` for v1                        |
| LaunchDelayMs         | Delay between Chrome launches              |
| RequireSuccessfulLaunch | Abort if one or both browser launches fail |

---

### 3.3.2 Premiere Settings

| Field              | Description              |
| ------------------ | ------------------------ |
| ExecutablePath     | Path to Premiere executable or launch command |
| Arguments          | Optional launch arguments such as project file path |
| UseFileAssociation | Whether to open the project through file association |
| ProcessName        | Premiere process name    |
| WindowTitleRegex   | Window match pattern     |
| ProjectPath        | Path to `.prproj`        |
| LaunchTimeoutSec   | Max launch wait          |
| InitialLoadDelayMs | Post-launch settle delay |

---

### 3.3.3 Focus Settings

| Field         | Description                  |
| ------------- | ---------------------------- |
| RetryCount    | Max focus attempts           |
| RetryDelayMs  | Delay between retries        |
| VerifyDelayMs | Delay before verifying focus |
| RequireSameIntegrityLevel | Require the script, Premiere, and Chrome to run at the same privilege level |

---

### 3.3.4 Timing (Jitter Profiles)

| Type   | Range        |
| ------ | ------------ |
| Micro  | 100–350 ms   |
| Normal | 400–1500 ms  |
| Think  | 2000–6000 ms |

---

### 3.3.5 Workflow Settings

| Field         | Description              |
| ------------- | ------------------------ |
| MaxRunTimeSec | Max session duration     |
| LoopCount     | Number of workflow loops |
| ReadyTimeoutSec | Max time to wait for Premiere to become ready |

---

### 3.3.6 Keyboard Mapping

Explicit mapping of shortcuts:

```powershell
Keyboard = @{
    PlayPause   = " "
    StepForward = "{RIGHT}"
    StepBack    = "{LEFT}"
}
```

---

### 3.3.7 Logging Settings

| Field             | Description                               |
| ----------------- | ----------------------------------------- |
| LogPath           | Output directory                          |
| LogLevel          | Verbosity                                 |
| EnableConsole     | Console logging toggle                    |
| EnableJsonLog     | Toggle structured JSON output             |
| IncludePingDetail | Include per-sample ping entries in output |
| IncludeSystemLoadDetail | Include per-sample CPU and memory entries in output |

---

### 3.3.8 Telemetry Settings

| Field            | Description                                      |
| ---------------- | ------------------------------------------------ |
| PingTarget       | Host name or IP sourced from script constant     |
| PingIntervalSec  | Sample interval in seconds for telemetry sampling |
| CollectPerAction | Start and stop sampling for each simulated task  |
| SummaryMetrics   | Highest, Lowest, Median, Average                 |
| PingTimeoutMs    | Timeout for individual ping attempts             |
| SampleOnStart    | Capture an immediate ping sample before the interval begins |

In addition to ping telemetry, the system must collect CPU and memory load samples once per interval and emit a separate per-action system load summary.

---

### 3.3.9 Safety Controls

| Field                | Description            |
| -------------------- | ---------------------- |
| AbortOnFocusFailure  | Stop on focus failure  |
| MaxConsecutiveErrors | Threshold before abort |

---

# 4. Component Specifications

---

# 4.1 Browser Launcher

## 4.1.1 Purpose

Launches two Google Chrome instances before Premiere Pro automation begins so that the workstation is placed under representative browser and network activity.

---

## 4.1.2 Responsibilities

* Validate that exactly two URLs are configured
* Launch Chrome window 1 with URL 1
* Launch Chrome window 2 with URL 2
* Apply an optional delay between launches
* Detect launch failures and report them to the controller
* Log browser launch timing and outcome
* Use launch flags that prefer a new window for each URL and avoid tab reuse where possible

---

## 4.1.3 Inputs

* `$ChromeUrls`
* `$Config.Browser`

---

## 4.1.4 Outputs

* Success / Failure
* Per-instance launch timing
* Process identifiers where available
* Error reason

---

## 4.1.5 Behaviour

### Launch Sequence

1. Validate that two non-empty URLs are defined
2. Resolve Chrome executable or shell association
3. Launch first Chrome window with URL 1
4. Wait `LaunchDelayMs`
5. Launch second Chrome window with URL 2
6. Log both outcomes before proceeding to Premiere launch

---

## 4.1.6 Failure Modes

| Condition            | Type                              |
| -------------------- | --------------------------------- |
| Chrome not installed | Fatal                             |
| Invalid URL constant | Fatal                             |
| One launch failed    | Recoverable → Fatal based on config |
| Both launches failed | Fatal                             |

---

## 4.1.7 Functions

* `Start-ChromeLoad`
* `Start-ChromeInstance`
* `Test-ChromeLaunchConfiguration`

---

# 4.2 Focus Manager

## 4.2.1 Purpose

Attempts to make Premiere Pro the active and focused window before any input, then verifies that focus was acquired.

---

## 4.2.2 Responsibilities

* Detect Premiere process
* Locate main window via UI Automation
* Restore window if minimised
* Bring window to foreground
* Set keyboard focus
* Verify focus success
* Retry on failure
* Detect blocking UI (where possible)
* Avoid sending input if Premiere, Chrome, or the script are running at mismatched integrity levels

---

## 4.2.3 Inputs

* `$Config.Premiere`
* `$Config.Focus`

---

## 4.2.4 Outputs

* Success / Failure
* Retry count
* Timing metrics
* Error reason

---

## 4.2.5 Behaviour

### Focus Sequence

1. Locate window via UIAutomation
2. Call `SetFocus()`
3. Optional fallback:

   * Win32 `ShowWindow`
   * Win32 `SetForegroundWindow`
4. Wait `VerifyDelayMs`
5. Validate focus
6. Retry if necessary

### Readiness Criteria

Before any simulated action begins, the controller must verify:

1. Premiere process is running
2. Main window exists and is visible
3. The expected project is loaded or the project path is confirmed
4. No blocking modal dialog is detected by the configured checks
5. The initial post-launch settle delay has elapsed

---

## 4.2.6 Failure Modes

| Condition            | Type                              |
| -------------------- | --------------------------------- |
| Process not found    | Fatal                             |
| Window not available | Recoverable                       |
| Focus not acquired   | Recoverable → Fatal after retries |

---

## 4.2.7 Functions

* `Get-PremiereWindow`
* `Test-PremiereRunning`
* `Focus-PremiereWindow`
* `Test-PremiereFocused`
* `Wait-PremiereWindowReady`

---

# 4.3 Input Player

## 4.3.1 Purpose

Simulates human-like interaction via keyboard input.

---

## 4.3.2 Responsibilities

* Execute key sequences
* Apply jitter delays
* Handle repeated actions
* Enforce focus requirement
* Provide structured action execution

---

## 4.3.3 Action Model

Each action must include:

| Field          | Description            |
| -------------- | ---------------------- |
| Type           | Action kind such as key press, wait, or composite sequence |
| Name           | Action identifier      |
| Keys           | SendKeys string        |
| JitterProfile  | Micro / Normal / Think |
| RepeatCount    | Number of repetitions  |
| FocusRequired  | Boolean                |
| AbortOnFailure | Boolean                |
| DurationMs     | Duration for wait-style actions |
| Sequence       | Ordered child actions for burst or composite actions |
| PreDelayMs     | Delay before the action begins |
| PostDelayMs    | Delay after the action completes |

---

## 4.3.4 Supported Action Types

* Play/Pause
* Step forward/backward
* Scrub movement
* Idle wait
* Burst sequences

For v1, burst sequences are represented as ordered child actions that the controller executes serially.

---

## 4.3.5 Behaviour

* Verify focus when `FocusRequired` is true
* Send keys using `SendKeys`
* Apply jitter delay
* Log execution

---

## 4.3.6 Functions

* `Send-HumanKeys`
* `Get-JitterDelay`
* `Invoke-KeyAction`
* `Invoke-ActionSequence`

---

# 4.4 Workflow Controller

## 4.4.1 Purpose

Orchestrates the full synthetic workflow.

---

## 4.4.2 Responsibilities

* Launch Chrome instances
* Launch Premiere/project
* Wait for readiness
* Execute workflow scenario
* Coordinate focus + input
* Start and stop telemetry per simulated task
* Handle retries and failures
* Enforce runtime limits
* Produce summary
* Emit a ping summary after every action, including actions that fail or time out

---

## 4.4.3 Inputs

* `$Config`
* Scenario definition

---

## 4.4.4 Outputs

* Pass / Degraded / Fail
* Execution summary
* Logs

---

## 4.4.5 Workflow States

* Initialising
* LaunchingBrowser
* LaunchingPremiere
* WaitingForWindow
* Focusing
* ExecutingAction
* CollectingTelemetry
* Recovering
* Completed
* Failed
* TimedOut

---

## 4.4.6 Execution Loop

For each action:

1. Confirm Premiere running
2. Start ping sampling for the action and take an immediate initial sample
3. Focus window
4. Verify focus
5. Execute action
6. Apply jitter
7. Stop ping sampling
8. Log action result and ping summary

---

## 4.4.7 Failure Handling

### Recoverable

* Retry focus
* Skip action if safe
* Record telemetry gap if a task terminates before a valid ping sample is collected

### Degraded

* Continue with warning
* Continue if ping sampling partially fails but workflow execution remains safe
* Treat modal dialogs, project load errors, and privilege mismatches as blocking conditions unless explicitly configured otherwise

### Fatal

* Abort workflow

---

## 4.4.8 Functions

* `Start-ChromeLoad`
* `Start-PremiereSession`
* `Wait-PremiereReady`
* `Invoke-SyntheticWorkflow`
* `Stop-PremiereSession`
* `Write-RunSummary`

---

# 4.5 Logging & Telemetry

## 4.5.1 Purpose

Provide full observability for diagnostics.

---

## 4.5.2 Requirements

* Timestamp all events
* Log Chrome launch attempts and outcomes
* Log all focus attempts
* Log all actions and delays
* Run a ping every second during each simulated task
* Compute per-task Highest / Lowest / Median / Average ping
* Log errors and retries
* Provide summary output

---

## 4.5.3 Log Fields

* Timestamp
* Run ID
* Component
* Event Type
* Severity
* Action Name
* Result
* Duration
* Retry Count
* Error Message
* Ping Target
* Ping Sample Count
* Ping LowestMs
* Ping HighestMs
* Ping MedianMs
* Ping AverageMs

---

## 4.5.4 Ping Telemetry Behaviour

* Ping sampling begins immediately before a simulated task starts
* An initial sample is taken at the start of the task so actions shorter than 1 second still produce telemetry when possible
* Sampling runs at `1` second intervals until that task completes
* Failed ping attempts are logged and excluded from latency aggregates unless no successful samples exist
* If no successful samples are collected, the task summary records telemetry as unavailable
* Aggregate metrics are emitted after every simulated task, not only at the end of the full run

---

## 4.5.5 Output Formats

* Text log (required)
* JSON log (optional)

---

## 4.5.6 Functions

* `Write-Log`
* `Write-ActionLog`
* `Write-ErrorLog`
* `Start-PingTelemetry`
* `Stop-PingTelemetry`
* `Get-PingStatistics`
* `Write-PingSummary`
* `Write-RunSummary`

---

# 5. Scenario Definition

## 5.1 Structure

Workflow defined as a sequence of actions:

```text
[Action 1] → [Action 2] → [Action 3] → ...
```

---

## 5.2 Example Scenario

```text
Pause (Think)
Play
Wait (Think)
Step Forward ×4 (Micro)
Pause (Normal)
Step Back ×2 (Micro)
Play
Wait (Think)
Pause
```

---

## 5.3 Design Rules

* Actions must be **idempotent where possible**
* Avoid destructive shortcuts
* Use predictable, repeatable sequences
* Keep workflows short and observable

---

# 6. Error Handling Strategy

## 6.1 Categories

### Recoverable

* Temporary focus failure
* Minor timing issues
* Single Chrome launch failure when continuation is explicitly allowed
* Partial ping telemetry loss within a task

### Degraded

* Multiple retries required
* Skipped action
* Incomplete telemetry sample count for a task

### Fatal

* Premiere exited
* Focus impossible
* Timeout exceeded
* Chrome launch prerequisites failed

---

## 6.2 Retry Policies

### Focus

* 3–5 retries
* 300–1000 ms delay

### Browser Launch

* Validate configuration once before launch
* Browser launch retries are optional and must be explicitly configured

### Actions

* Generally not retried
* Only retry safe/idempotent actions

### Ping Sampling

* No backfill for missed intervals
* Failed samples are logged individually and excluded from aggregates

---

# 7. Environment Requirements

## 7.1 System Setup

* Dedicated machine or VM
* Notifications disabled
* Stable Premiere version
* Google Chrome installed and launchable
* Fixed keyboard shortcut profile
* Fixed workspace layout
* Windows PowerShell 5.1 is the supported v1 host for UI automation and SendKeys behavior
* Script, Premiere, and Chrome must run in the same interactive desktop session and at the same integrity level

---

## 7.2 Project Requirements

* Self-contained project
* No missing media
* No relink prompts
* No plugin warnings
* Predictable timeline state
* Expected main panel or timeline panel should already be selected before the workflow begins, or the script must explicitly select it as part of readiness

---

## 7.3 Execution Constraints

* Script must run in active desktop session
* No user interference during execution
* Target URLs must be reachable enough for Chrome launch and ping diagnostics to be meaningful
* No UAC prompts, licensing prompts, or update prompts may appear during execution unless the script explicitly handles them

---

# 8. Non-Functional Requirements

## Reliability

* Never send input without confirmed focus
* Never start the Premiere workflow until Chrome launch preconditions are evaluated

## Observability

* Full logging of all operations
* Per-task ping aggregates captured consistently

## Maintainability

* Config-driven behaviour with a small set of explicit script-top constants

## Safety

* No destructive commands
* Safe abort conditions

---

# 9. Future Enhancements (Out of Scope for v1)

* Mouse-based interaction
* Screenshot capture on failure
* UI Automation dialog handling
* External config file (JSON)
* Multi-scenario execution
* Performance metrics integration