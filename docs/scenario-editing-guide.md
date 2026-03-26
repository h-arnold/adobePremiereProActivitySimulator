# Scenario editing guide

This guide explains how to edit `$Scenario` in `main.ps1` safely, with practical examples you can copy and adapt.

It is based on the current scenario engine implementation in `main.ps1`.

## Beginner quick start (copy this workflow)

If you are not comfortable editing scenarios yet, use this safe workflow:

1. Duplicate one existing action and change only `Name` and one timing value.
2. Run `-ValidateOnly`.
3. Run `-DryRun` and confirm the new action name appears in logs.
4. Only then change repeats, burst structures, or key bindings.

This avoids making multiple hard-to-debug changes at once.

## What `$Scenario` controls

`$Scenario` is an ordered list of actions. The workflow runner executes each action in sequence, and repeats the whole list according to `$Config.Workflow.LoopCount`.

For each action, the runner can:

- enforce Premiere focus before input (when `FocusRequired = $true`),
- start/stop telemetry for that action,
- apply pre/post delays,
- apply jitter delays from `$Config.Timing`,
- abort or continue based on action and safety settings.

## Where to edit it

Edit the `$Scenario = @( ... )` block in `main.ps1`.

Recommended change flow:

1. Make one scenario change at a time.
2. Run `-ValidateOnly` to catch schema/typing errors.
3. Run `-DryRun` to check execution order and log output.
4. Only then run live.

---

## Action schema (what every action needs)

Every action must include:

- `Type`
- `Name`
- `JitterProfile`
- `RepeatCount` (integer `>= 1`)
- `FocusRequired` (`$true`/`$false`)
- `AbortOnFailure` (`$true`/`$false`)
- `PreDelayMs` (integer `>= 0`)
- `PostDelayMs` (integer `>= 0`)

Type-specific requirements:

- `KeyPress` needs non-empty string `Keys`.
- `Wait` needs integer `DurationMs >= 0`.
- `Burst` needs non-empty `Sequence` (child actions).

Supported `Type` values are exactly:

- `KeyPress`
- `Wait`
- `Burst`

Any unknown type or missing required field fails validation.

### Simple “traffic light” rule for edits

- **Green (safe for beginners):** `Name`, `DurationMs`, `PreDelayMs`, `PostDelayMs`, `RepeatCount` (small changes).
- **Amber (needs care):** `JitterProfile`, `FocusRequired`, `AbortOnFailure`.
- **Red (easy to break):** changing nested `Burst.Sequence` structures and regex-like values elsewhere in config at the same time.

If you make an amber or red change, always validate and dry-run before live execution.

---

## Jitter and waits: what actually happens

There are two places delays happen:

1. **Inside an action** (`PreDelayMs`, `PostDelayMs`, repeated keypress delays, explicit wait durations).
2. **After each action** (a jitter delay from `JitterProfile` in `Invoke-WorkflowAction`).

For `Wait` actions:

- if `DurationMs > 0`, that exact duration is used;
- if `DurationMs <= 0`, a random delay is drawn from the action's `JitterProfile`.

This makes `Wait` actions useful both for fixed observation windows and jitter-only “human pause” windows.

---

## Working examples

You can paste any example below directly into `$Scenario` as a new entry.

## Example 1: Add a longer playback observation window

Use this when you want more telemetry during steady playback:

```powershell
@{
    Type = 'Wait'
    Name = 'LongObservePlayback'
    Keys = $null
    JitterProfile = 'Think'
    RepeatCount = 1
    FocusRequired = $false
    AbortOnFailure = $false
    DurationMs = 30000
    PreDelayMs = 0
    PostDelayMs = 0
}
```

Why this works:

- `Wait` includes valid `DurationMs` and required common fields.
- `FocusRequired = $false` avoids unnecessary focus churn during passive observation.

## Example 2: Increase scrub intensity with a burst

Use this when you need more aggressive timeline stepping:

```powershell
@{
    Type = 'Burst'
    Name = 'HeavyStepForwardBurst'
    Keys = $null
    JitterProfile = 'Micro'
    RepeatCount = 3
    FocusRequired = $true
    AbortOnFailure = $true
    Sequence = @(
        @{
            Type = 'KeyPress'
            Name = 'StepForward'
            Keys = $Config.Keyboard.StepForward
            JitterProfile = 'Micro'
            RepeatCount = 2
            FocusRequired = $true
            AbortOnFailure = $true
            PreDelayMs = 0
            PostDelayMs = 80
        }
    )
    PreDelayMs = 0
    PostDelayMs = 0
}
```

Why this works:

- `Burst` contains a non-empty child `Sequence`.
- Child action is a valid `KeyPress` definition.
- Higher `RepeatCount` at both levels raises action density.

## Example 3: Add a multi-step edit pattern in one burst

Use this for a compact “back then forward then pause” pattern:

```powershell
@{
    Type = 'Burst'
    Name = 'BackForwardPattern'
    Keys = $null
    JitterProfile = 'Micro'
    RepeatCount = 1
    FocusRequired = $true
    AbortOnFailure = $true
    Sequence = @(
        @{
            Type = 'KeyPress'
            Name = 'StepBackTwice'
            Keys = $Config.Keyboard.StepBack
            JitterProfile = 'Micro'
            RepeatCount = 2
            FocusRequired = $true
            AbortOnFailure = $true
            PreDelayMs = 0
            PostDelayMs = 50
        },
        @{
            Type = 'KeyPress'
            Name = 'StepForwardOnce'
            Keys = $Config.Keyboard.StepForward
            JitterProfile = 'Micro'
            RepeatCount = 1
            FocusRequired = $true
            AbortOnFailure = $true
            PreDelayMs = 0
            PostDelayMs = 100
        },
        @{
            Type = 'Wait'
            Name = 'ShortSettle'
            Keys = $null
            JitterProfile = 'Normal'
            RepeatCount = 1
            FocusRequired = $false
            AbortOnFailure = $false
            DurationMs = 750
            PreDelayMs = 0
            PostDelayMs = 0
        }
    )
    PreDelayMs = 0
    PostDelayMs = 0
}
```

Why this works:

- `Burst.Sequence` can contain mixed action types.
- Child `Wait` is valid because it includes `DurationMs`.

## Example 4: Jitter-only wait window

Use this when you want random think time with no fixed duration:

```powershell
@{
    Type = 'Wait'
    Name = 'RandomThinkPause'
    Keys = $null
    JitterProfile = 'Think'
    RepeatCount = 1
    FocusRequired = $false
    AbortOnFailure = $false
    DurationMs = 0
    PreDelayMs = 0
    PostDelayMs = 0
}
```

Because `DurationMs` is `0`, runtime duration comes from the `Think` jitter profile.

---

## Common mistakes (and how to avoid them)

- **Unknown jitter profile name** (for example typo in `JitterProfile`).
  - Fix: use only names defined in `$Config.Timing`.
- **`RepeatCount = 0` or negative values**.
  - Fix: use integer `>= 1`.
- **Missing `DurationMs` in `Wait` action**.
  - Fix: add non-negative integer `DurationMs`.
- **Empty `Sequence` in `Burst`**.
  - Fix: include at least one valid child action.
- **Empty `Keys` in `KeyPress`**.
  - Fix: set to a non-empty key string (for example `$Config.Keyboard.PlayPause`).
- **Over-aggressive focus requirements on passive waits**.
  - Fix: set `FocusRequired = $false` for passive observation waits.

### What failure messages usually mean

- `unknown jitter profile` → typo in `JitterProfile` or missing profile in `$Config.Timing`.
- `must define RepeatCount` → missing field or value is `0`/negative/non-integer.
- `must define DurationMs` → `Wait` action missing duration.
- `must define at least one child action in Sequence` → empty `Burst.Sequence`.
- `uses unsupported Type` → type name is not exactly `KeyPress`, `Wait`, or `Burst`.

---

## How scenario settings combine with safety settings

- Action-level `AbortOnFailure` controls whether that specific failure stops the run immediately.
- Global `Safety.AbortOnFocusFailure` can still escalate non-aborting actions when a focus error occurs.
- Global `Safety.MaxConsecutiveErrors` stops the run once consecutive failures hit the threshold.

Practical implication: you can allow some non-critical actions to fail, but persistent failures will still terminate the run.

---

## Recommended editing patterns by goal

## Goal: collect more telemetry per run

- Increase `Wait` durations (`DurationMs`) in playback observation actions.
- Increase `Workflow.LoopCount` instead of making single actions excessively long.

## Goal: simulate a fast editor

- Reduce `Timing.Normal` and `Timing.Think` ranges.
- Increase `RepeatCount` for scrub bursts.
- Keep `FocusRequired = $true` on input actions.

## Goal: reduce flakiness in unstable remote sessions

- Reduce unnecessary focus checks (`FocusRequired = $false`) on `Wait` actions.
- Keep focus retries in `$Config.Focus` reasonable.
- Keep `AbortOnFailure = $false` only on genuinely non-critical actions.

---

## Pre-run checklist for scenario edits

1. Every action has all required common fields.
2. Every `JitterProfile` exists in `$Config.Timing`.
3. Every `KeyPress` has non-empty `Keys`.
4. Every `Wait` has `DurationMs >= 0`.
5. Every `Burst` has at least one child in `Sequence`.
6. `-ValidateOnly` and `-DryRun` both complete successfully.

## Minimal template snippets (for quick edits)

### Template: `KeyPress`

```powershell
@{
    Type = 'KeyPress'
    Name = 'MyKeyAction'
    Keys = $Config.Keyboard.PlayPause
    JitterProfile = 'Normal'
    RepeatCount = 1
    FocusRequired = $true
    AbortOnFailure = $true
    PreDelayMs = 0
    PostDelayMs = 0
}
```

### Template: `Wait`

```powershell
@{
    Type = 'Wait'
    Name = 'MyWaitAction'
    Keys = $null
    JitterProfile = 'Think'
    RepeatCount = 1
    FocusRequired = $false
    AbortOnFailure = $false
    DurationMs = 5000
    PreDelayMs = 0
    PostDelayMs = 0
}
```

### Template: `Burst`

```powershell
@{
    Type = 'Burst'
    Name = 'MyBurstAction'
    Keys = $null
    JitterProfile = 'Micro'
    RepeatCount = 1
    FocusRequired = $true
    AbortOnFailure = $true
    Sequence = @(
        @{
            Type = 'KeyPress'
            Name = 'ChildStep'
            Keys = $Config.Keyboard.StepForward
            JitterProfile = 'Micro'
            RepeatCount = 1
            FocusRequired = $true
            AbortOnFailure = $true
            PreDelayMs = 0
            PostDelayMs = 50
        }
    )
    PreDelayMs = 0
    PostDelayMs = 0
}
```
