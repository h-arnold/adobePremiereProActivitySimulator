# Scenario Editing Guide

**⚡ TL;DR:** Most edits just require changing `Name`, `DurationMs`, or `RepeatCount`. Validate with `-ValidateOnly` and test with `-DryRun`. That's it.

This guide explains how to edit `$Scenario` in `main.ps1` safely, with practical examples you can copy and adapt.

It is based on the current scenario engine implementation in `main.ps1`.

---

## Most Common Edits (Do This)

90% of the time, you only need to do one of these:

| Goal | Action | Example |
|---|---|---|
| Make sim run longer | Find a `Wait` action and increase `DurationMs` | `DurationMs = 30000` (was 15000) |
| Make sim run faster | Find a `Wait` action and decrease `DurationMs` | `DurationMs = 5000` (was 15000) |
| More timeline scrubbing | Increase `RepeatCount` in a `Burst` action | `RepeatCount = 5` (was 2) |
| Less timeline scrubbing | Decrease `RepeatCount` in a `Burst` action | `RepeatCount = 1` (was 3) |
| Change action name for logs | Find an action and change `Name` | `Name = 'MyNewActionName'` |
| Copy an existing action | Select entire action block `@{ ... }`, copy, paste, change Name | See examples below |

**After any edit:** Always run `-ValidateOnly`, then `-DryRun` before live execution.

---

## Beginner Quick Start (Copy This Workflow)

If you are not comfortable editing scenarios yet, use this safe workflow:

1. Duplicate one existing action and change only `Name` and one timing value.
2. Run `-ValidateOnly`.
3. Run `-DryRun` and confirm the new action name appears in logs.
4. Only then change repeats, burst structures, or key bindings.

This avoids making multiple hard-to-debug changes at once.

---

## Quick Lookup Index

Can't remember what field does what? Use this table:

| I'm trying to... | Find this field | Change it to | Example |
|---|---|---|---|
| Add more wait time between actions | `DurationMs` (in `Wait` actions) | Higher number | `30000` = 30 seconds |
| Make actions happen faster | `DurationMs` | Lower number | `5000` = 5 seconds |
| Add more key presses | `RepeatCount` | Higher number | `RepeatCount = 5` |
| Fewer key presses | `RepeatCount` | Lower number | `RepeatCount = 1` |
| Change how random the pauses are | `JitterProfile` | `'Micro'`, `'Normal'`, or `'Think'` | `'Micro'` = 100-300ms |
| Require focus before action | `FocusRequired` | `$true` | Ensures window is active |
| Skip focus requirement | `FocusRequired` | `$false` | For passive waits |
| Stop run if this action fails | `AbortOnFailure` | `$true` | Strict mode |
| Continue even if action fails | `AbortOnFailure` | `$false` | Forgiving mode |

---

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

## Common Mistakes & Fixes (Quick Reference)

When you run `-ValidateOnly` and it fails, use this to find the fix:

| Error message | What it means | How to fix |
|---|---|---|
| `unknown jitter profile` | You spelled a profile name wrong | Check spelling: `'Micro'`, `'Normal'`, `'Think'` only |
| `must define RepeatCount` | Missing the field or it's 0/negative | Add `RepeatCount = 1` (or higher) |
| `must define DurationMs` | `Wait` action is missing duration | Add `DurationMs = 5000` (or any number >= 0) |
| `must define at least one child action in Sequence` | `Burst` has no actions inside | Add at least one `KeyPress` or `Wait` inside |
| `uses unsupported Type` | Type name is wrong | Use exactly: `'KeyPress'`, `'Wait'`, or `'Burst'` |
| `Empty Keys in KeyPress` | `Keys` field is empty or missing | Add `Keys = $Config.Keyboard.PlayPause` |

**Safe rule:** If validation fails, look for the typo in the first action listed in the error message, then fix and re-validate.

---

## Quick Troubleshooting

| Problem | Check This |
|---|---|
| Script validates but crashes during dry-run | Make sure all nested actions in `Burst.Sequence` are complete (all required fields filled) |
| Action name doesn't appear in logs | Make sure you didn't accidentally delete the `Name` field |
| Premiere won't get focus | Make sure `FocusRequired = $true` only on actions that actually need input |
| Script runs but nothing happens | `DurationMs = 0` on a `Wait` means "use random jitter" - sometimes that's fast |

---

## How scenario settings combine with safety settings

- Action-level `AbortOnFailure` controls whether that specific failure stops the run immediately.
- Global `Safety.AbortOnFocusFailure` can still escalate non-aborting actions when a focus error occurs.
- Global `Safety.MaxConsecutiveErrors` stops the run once consecutive failures hit the threshold.

Practical implication: you can allow some non-critical actions to fail, but persistent failures will still terminate the run.

---

## Recommended Editing Patterns by Goal

### Goal: collect more telemetry per run

- Increase `Wait` durations (`DurationMs`) in playback observation actions.
- Increase `Workflow.LoopCount` (in config) instead of making single actions excessively long.

### Goal: simulate a fast editor

- Reduce `Timing.Normal` and `Timing.Think` ranges (in config).
- Increase `RepeatCount` for scrub bursts.
- Keep `FocusRequired = $true` on input actions.

### Goal: reduce flakiness in unstable remote sessions

- Reduce unnecessary focus checks (`FocusRequired = $false`) on `Wait` actions.
- Keep focus retries in `$Config.Focus` reasonable.
- Keep `AbortOnFailure = $false` only on genuinely non-critical actions.

---

## Pre-Run Checklist (Before Every `-Validate`)

- [ ] Every action has: `Type`, `Name`, `JitterProfile`, `RepeatCount`, `FocusRequired`, `AbortOnFailure`, `PreDelayMs`, `PostDelayMs`
- [ ] Every `JitterProfile` matches: `'Micro'`, `'Normal'`, or `'Think'` (case-sensitive, quotes required)
- [ ] Every `KeyPress` has non-empty `Keys` (e.g., `Keys = $Config.Keyboard.PlayPause`)
- [ ] Every `Wait` has `DurationMs >= 0` (e.g., `DurationMs = 5000`)
- [ ] Every `Burst` has at least one child action in `Sequence`
- [ ] All commas and brackets are balanced

Then run: `powershell -ExecutionPolicy Bypass -File .\main.ps1 -ValidateOnly`

---

## Template Snippets (Copy & Paste)

Use these as starting points for new actions. Just change the `Name` field and any timing/repeat values.

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
