# Configuration guide

This guide explains every configurable value in `main.ps1`, what it changes at runtime, and how to tune it for common operational goals.

It is written against the current script configuration model (`$ChromeUrls`, `$PingTarget`, `$Config`, and `$Scenario`).

If you specifically want step-by-step instructions for editing workflow actions, use [`docs/scenario-editing-guide.md`](scenario-editing-guide.md) alongside this page.

## If you are short on time (safe starter settings)

If you are not confident with the internals yet, make only these edits first:

1. Set `Premiere.ProjectPath` to a real `.prproj`.
2. Set `Telemetry.PingTarget` to the file/media server you actually use.
3. Leave everything else on defaults.
4. Run `-ValidateOnly`, then `-Preflight`, then live.

This gets you reliable first-run behaviour without over-tuning.

## Quick “what should I change?” map

- **Need script to run at all** → `Premiere.ProjectPath`, optionally executable paths.
- **Need more/fewer telemetry points** → `Telemetry.TelemetrySampleIntervalSec`.
- **Need less noise in JSON logs** → `Logging.Include*Detail` flags.
- **Need to handle multi-adapter machines** → `Telemetry.NetworkAdapterName`.
- **Need stricter stop-on-error behaviour** → `Safety` section.
- **Need different user behaviour simulation** → edit `$Scenario` (see scenario guide).

## How configuration is loaded

Configuration has four layers in one file:

1. **Script-top constants** (`$ChromeUrls`, `$PingTarget`).
2. **Top-level config object** (`$Config`) grouped into sections (`Browser`, `Premiere`, `Focus`, `Timing`, `Workflow`, `Keyboard`, `Logging`, `Telemetry`, `Safety`).
3. **Scenario action list** (`$Scenario`) that defines the sequence of key/wait/burst actions.
4. **Run mode switches** (`-ValidateOnly`, `-DryRun`, `-Preflight`) that affect whether automation is simulated or live.

The script validates configuration before execution, including telemetry interval validity, project path requirements, Chrome URL shape, and scenario action schema.

---

## Minimum edits for a real live run

Before your first live run, edit these values:

- `$Config.Premiere.ProjectPath` → point to a real `.prproj` file.
- `$PingTarget` or `$Config.Telemetry.PingTarget` → set this to the actual media/project file server (or other relevant network target).
- Optionally pin executables if auto-detection fails:
  - `$Config.Browser.ExecutablePath`
  - `$Config.Premiere.ExecutablePath`

Then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\main.ps1 -ValidateOnly
powershell -ExecutionPolicy Bypass -File .\main.ps1 -Preflight
powershell -ExecutionPolicy Bypass -File .\main.ps1
```

If any step fails, do not continue to live mode. Fix the configuration first.

---

## Script-top constants

### `$ChromeUrls`

- **Default:** two YouTube URLs.
- **Purpose:** controls the two browser windows launched before Premiere actions.
- **Important constraints:** the script enforces **exactly two** URLs, and each must match `http://` or `https://`.
- **When to change:** only if your test scenario needs different background streaming load.

### `$PingTarget`

- **Default:** `google.com`.
- **Purpose:** seed value for `$Config.Telemetry.PingTarget`.
- **When to change:** set to the SMB/CIFS media server or other infrastructure endpoint you actually care about.

---

## `$Config` reference

Before changing advanced values: if you do not clearly understand what a setting does, leave it at default and test first in `-DryRun`.

## `Browser`

### `ExecutablePath`

- **Default:** `$null` (auto-discovery).
- **Effect:** if set, script tries this path/command first; otherwise it checks standard Chrome install paths.
- **Tune for:** locked-down estates, non-standard installs, portable Chrome paths.

### `Urls`

- **Default:** `$ChromeUrls`.
- **Effect:** list of URLs to open.
- **Tune for:** changing background traffic profile.

### `LaunchCount`

- **Default:** `2`.
- **Effect:** used in success checks (`RequireSuccessfulLaunch` expects this many successful launches).
- **Tune for:** usually leave unchanged to match the fixed two-URL model.
- **Beginner note:** keep this at `2`. If you change it without changing URL count, validation/launch checks can fail.

### `LaunchDelayMs`

- **Default:** `1500`.
- **Effect:** delay between Chrome launches.
- **Tune for:** slower endpoints that need more settle time before next launch.

### `RequireSuccessfulLaunch`

- **Default:** `$true`.
- **Effect:** if true, run aborts when successful Chrome launches do not match `LaunchCount`.
- **Tune for:** strict reproducibility (`$true`) vs. permissive resilience (`$false`).

## `Premiere`

### `ExecutablePath`

- **Default:** `$null` (auto-discovery using common 2025/2024/2023 paths).
- **Effect:** used when `UseFileAssociation = $false`, or for preflight resolution checks.
- **Tune for:** non-standard install locations.

### `Arguments`

- **Default:** empty array.
- **Effect:** extra arguments passed when launching by explicit executable path mode.
- **Tune for:** advanced launch flags.

### `UseFileAssociation`

- **Default:** `$true`.
- **Effect:** if true, opens the project directly via file association; if false, launches via `ExecutablePath` + `Arguments` + project path.
- **Tune for:** environments where file association is unreliable or mapped to wrong build.
- **Beginner note:** keep `$true` unless you have a known reason to launch via explicit executable path.

### `ProcessName` and `ProcessNames`

- **Default:** `'Adobe Premiere Pro'` and `@('Adobe Premiere Pro')`.
- **Effect:** merged and deduplicated into the process-name list used to detect running Premiere windows/processes.
- **Tune for:** build variants, localisation differences, renamed process strings.
- **Beginner note:** only change these if preflight/logs show Premiere detection failures.

### `WindowTitleRegex`

- **Default:** `'Premiere Pro'`.
- **Effect:** filters candidate windows when selecting the active Premiere process.
- **Tune for:** custom title patterns, localised UI titles.
- **Beginner note:** this is regex. A typo can stop window matching. Change cautiously.

### `ProjectPath`

- **Default:** placeholder path.
- **Effect:** mandatory; validated before execution. Live/preflight requires this path to exist.
- **Tune for:** your actual benchmark project file.

### `InitialLoadDelayMs`

- **Default:** `10000`.
- **Effect:** additional settle delay after launch before readiness logic continues.
- **Tune for:** larger projects or slower storage.

## `Focus`

### `RetryCount`

- **Default:** `5`.
- **Effect:** number of focus attempts before failure.
- **Tune for:** flaky RDP/VPN/virtual desktop focus behaviour.

### `RetryDelayMs`

- **Default:** `750`.
- **Effect:** delay between focus retries.
- **Tune for:** high-latency UI environments.

### `VerifyDelayMs`

- **Default:** `400`.
- **Effect:** wait before verifying focus state.
- **Tune for:** window-manager lag.

### `RequireSameIntegrityLevel`

- **Default:** `$true`.
- **Effect:** in full live mode, aborts when PowerShell, Premiere, and Chrome integrity levels do not match.
- **Tune for:** keep true for reliable keyboard injection; only relax if you explicitly accept degraded fidelity.
- **Beginner note:** this protects you from “script says it ran, but no keys actually landed” situations.

## `Timing`

### `Micro`, `Normal`, `Think` (each has `MinMs` and `MaxMs`)

- **Defaults:**
  - `Micro`: 100–300 ms
  - `Normal`: 400–1500 ms
  - `Think`: 2000–6000 ms
- **Effect:** controls random jitter durations used between and inside actions.
- **Tune for:** mimicking faster/slower user interaction cadence.

## `Workflow`

### `MaxRunTimeSec`

- **Default:** `900`.
- **Effect:** hard deadline across loops; workflow aborts if exceeded.
- **Tune for:** bounding test duration in shared labs.

### `LoopCount`

- **Default:** `1`.
- **Effect:** repeats full scenario this many times.
- **Tune for:** repeated-sample benchmarking.

### `ReadyTimeoutSec`

- **Default:** `120`.
- **Effect:** maximum wait for Premiere readiness/window availability.
- **Tune for:** large projects or cold-cache startup conditions.

## `Keyboard`

### `PlayPause`, `StepForward`, `StepBack`

- **Defaults:** `k`, `l`, `j`.
- **Effect:** key strings sent in keypress actions.
- **Tune for:** custom Premiere shortcut mappings in your editing profile.

## `Logging`

### `LogPath`

- **Default:** `<repo>\logs`.
- **Effect:** output folder for text log and JSONL log.
- **Tune for:** centralised log collection locations.

### `LogLevel`

- **Default:** `Information`.
- **Effect:** console visibility threshold (`Debug` < `Information` < `Warning` < `Error`).
- **Tune for:** verbose troubleshooting (`Debug`) or quieter normal runs (`Warning`).
- **Beginner note:** this changes console output only; logs are still written to files.

### `EnableConsole`

- **Default:** `$true`.
- **Effect:** enables/disables terminal output.
- **Tune for:** unattended runs where stdout noise should be reduced.

### `EnableJsonLog`

- **Default:** `$true`.
- **Effect:** toggles structured JSONL output.
- **Tune for:** if downstream tooling parses logs, keep this enabled.

### `IncludePingDetail`, `IncludeSystemLoadDetail`, `IncludeNetworkDetail`

- **Defaults:** all `$true`.
- **Effect:** include per-sample telemetry arrays in summary events.
- **Tune for:** disable to reduce JSONL size in large test campaigns.

## `Telemetry`

### `PingTarget`

- **Default:** `$PingTarget`.
- **Effect:** host/IP used for per-action ping sampling.
- **Tune for:** set to your actual storage/media dependency endpoint.

### `TelemetrySampleIntervalSec`

- **Default:** `1`.
- **Effect:** shared sampling cadence for ping, system load, and network throughput; must be > 0.
- **Tune for:**
  - lower value (e.g. `0.5`) for finer-grained telemetry;
  - higher value (e.g. `2`) for lower overhead.
- **Beginner note:** `1` is a good balance. Avoid very low values unless you need spike analysis.

### `PingTimeoutMs`

- **Default:** `1000`.
- **Effect:** timeout per ping attempt.
- **Tune for:** long-latency links where false timeouts are common.

### `SampleOnStart`

- **Default:** `$true`.
- **Effect:** takes an immediate sample when action telemetry starts.
- **Tune for:** keep enabled if you need first-moment action visibility.

### `FailureWarningLimitPerAction`

- **Default:** `1`.
- **Effect:** caps warning logs per telemetry collector/action after failures start.
- **Tune for:** increase for richer diagnostics; decrease to reduce log noise.

### `NetworkAdapterName`

- **Default:** `$null` (auto-select active adapter).
- **Effect:** preferred adapter for throughput sampling.
- **Tune for:** dual-homed machines (Ethernet + Wi‑Fi + VPN) where auto-selection can pick the wrong interface.
- **Beginner note:** only set this if logs show the wrong adapter is being sampled.

## `Safety`

### `AbortOnFocusFailure`

- **Default:** `$true`.
- **Effect:** escalates focus-related action failures to run-stopping failures.
- **Tune for:** strict automation integrity vs. best-effort continuation.

### `MaxConsecutiveErrors`

- **Default:** `3`.
- **Effect:** hard stop after this many consecutive action failures.
- **Tune for:** higher for exploratory diagnostics, lower for strict CI-style gating.

---

## `$Scenario` values and how they interact with config

Each action entry supports:

- `Type`: `KeyPress`, `Wait`, `Burst`
- `Name`: log/event identifier
- `JitterProfile`: must exist in `$Config.Timing`
- `RepeatCount`: integer >= 1
- `FocusRequired`: force focus check before action
- `AbortOnFailure`: whether this action should terminate run on failure
- `PreDelayMs` / `PostDelayMs`: non-negative waits around action body
- Type-specific fields:
  - `KeyPress`: `Keys` (non-empty string)
  - `Wait`: `DurationMs` (non-negative; if `0`, jitter profile value is used)
  - `Burst`: `Sequence` (one or more nested actions)

Use scenario edits when your goal is to change **what** user behaviour is simulated; use `$Config` edits when your goal is to change **how** the simulator runs.

---

## Tuning recipes by operational goal

Tip: apply one recipe at a time, then run a short `-DryRun` or single-loop live test before combining recipes.

## Goal: improve reproducibility across machines

1. Keep `Browser.RequireSuccessfulLaunch = $true`.
2. Keep `Safety.AbortOnFocusFailure = $true`.
3. Keep `Focus.RequireSameIntegrityLevel = $true`.
4. Pin `Telemetry.NetworkAdapterName` on dual-homed devices.
5. Keep identical `ProjectPath` payload and scenario across all devices.

## Goal: reduce run overhead while preserving broad trends

1. Increase `Telemetry.TelemetrySampleIntervalSec` (for example to `2`).
2. Disable detailed sample arrays:
   - `Logging.IncludePingDetail = $false`
   - `Logging.IncludeSystemLoadDetail = $false`
   - `Logging.IncludeNetworkDetail = $false`
3. Keep summary metrics enabled (default behaviour).

## Goal: capture short transient spikes

1. Decrease `Telemetry.TelemetrySampleIntervalSec` (for example to `0.5`).
2. Keep sample detail flags enabled.
3. Increase `Workflow.LoopCount` to gather more action samples per host.

## Goal: make the simulation look more like a slower human editor

1. Increase `Timing.Normal.MaxMs` and `Timing.Think.MinMs/MaxMs`.
2. Increase `Scenario` `Wait` durations (`ObservePlayback`, `FinalObservePlayback`).
3. Optionally increase `Focus.RetryDelayMs` if focus transitions are slow.

## Goal: make the simulation more aggressive / high interaction

1. Reduce `Timing.Micro` and `Timing.Normal` ranges.
2. Increase relevant `RepeatCount` values in burst actions.
3. Keep `MaxRunTimeSec` high enough to avoid deadline aborts.

## Goal: run in constrained environments for safe validation

1. Use `-ValidateOnly` for schema/config checks.
2. Use `-DryRun` for end-to-end simulated execution and log-shape checks.
3. Use `-Preflight` for live readiness diagnostics without full desktop automation.

---

## Change process (recommended)

1. Edit configuration values in `main.ps1`.
2. Run `-ValidateOnly` first.
3. Run `-DryRun` to inspect resulting logs.
4. Run `-Preflight` on target hosts.
5. Execute live run only when preflight is clean.

This sequence prevents invalid or misleading benchmark runs.

---

## Verification pass for this guide

When updating this document in future, verify it against code with:

```bash
rg -n "^\$ChromeUrls|^\$PingTarget|^\$Config =|^\$Scenario =" main.ps1
rg -n "Test-ChromeLaunchConfiguration|Test-ProjectPathConfiguration|Get-ConfiguredPremiereProcessNames|Get-JitterDelay|Test-ActionDefinition|Test-Configuration" main.ps1
rg -n "TelemetrySampleIntervalSec|FailureWarningLimitPerAction|NetworkAdapterName|IncludePingDetail|IncludeSystemLoadDetail|IncludeNetworkDetail|MaxRunTimeSec|LoopCount|ReadyTimeoutSec|AbortOnFocusFailure|MaxConsecutiveErrors" main.ps1
```

These checks make sure documented defaults, constraints, and behavioural notes still match the implementation.
