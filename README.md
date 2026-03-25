# Premiere Pro Workflow Simulator

Synthetic Adobe Premiere Pro workflow automation for Windows desktop diagnostics.

## What It Does

The script in `main.ps1` implements the workflow described in `SPEC.md`:

- launches two Chrome windows before Premiere automation starts
- launches a configured Premiere project
- waits for Premiere readiness
- focuses the Premiere window before every keyboard-driven action
- simulates a short playback/editing workflow with jittered timing
- samples ping telemetry at a fixed 1 second interval per action
- writes text and JSONL logs with per-action telemetry summaries

## Requirements

- Windows PowerShell 5.1 in an interactive Windows desktop session
- Adobe Premiere Pro installed and able to open the target project
- Google Chrome installed
- a valid `.prproj` path configured in `main.ps1`
- Premiere, Chrome, and the PowerShell session running at the same privilege level for full desktop automation

## Configuration

Edit the script-top constants and the top-level `$Config` object in `main.ps1` before live execution.

Minimum required changes:

- set the two values in `$ChromeUrls`
- if needed, set `$PingTarget`
- set `$Config.Premiere.ProjectPath`
- if needed, set `$Config.Browser.ExecutablePath`
- if needed, set `$Config.Premiere.ExecutablePath`
- adjust `$Config.Premiere.ProcessName`, `$Config.Premiere.ProcessNames`, or `$Config.Premiere.WindowTitleRegex` if your Premiere install differs

For live runs, the script now prefers a Premiere window whose title matches both the configured window regex and the configured project name when possible. If your environment uses a different process name variant, add it to `$Config.Premiere.ProcessNames`.

## Run Modes

Validation only:

```powershell
powershell -ExecutionPolicy Bypass -File .\main.ps1 -ValidateOnly
```

This checks the configuration shape and scenario structure without launching applications or requiring the configured files to exist yet.

It also validates action definitions more aggressively, including supported action types, jitter profile names, repeat counts, wait durations, and burst sequence contents.

Dry-run simulation:

```powershell
powershell -ExecutionPolicy Bypass -File .\main.ps1 -DryRun
```

This runs the full controller path with simulated launches, focus, key input, and ping samples so you can inspect the generated logs safely.

In `-DryRun`, ping samples are synthetic by design. They are generated inside the script and do not represent real network reachability.

Preflight checks:

```powershell
powershell -ExecutionPolicy Bypass -File .\main.ps1 -Preflight
```

This performs a constrained-safe live-readiness check and reports blockers such as Constrained Language Mode, unresolved executables, and missing project paths without attempting desktop automation.

When the host is in Constrained Language Mode, preflight now distinguishes between:

- full desktop automation readiness
- degraded live readiness, where the script can still launch Chrome and Premiere and collect telemetry while skipping focus and key injection

Live execution:

```powershell
powershell -ExecutionPolicy Bypass -File .\main.ps1
```

If you use PowerShell 7 for dry-run checks:

```powershell
pwsh -File .\main.ps1 -DryRun
```

Live desktop automation should still be validated in Windows PowerShell 5.1 because SendKeys and UI automation behavior are host-sensitive.

If the host is running in PowerShell Constrained Language Mode, the script now falls back to a degraded live mode instead of failing immediately. In that mode it will:

- launch Chrome and Premiere normally
- wait for Premiere readiness using constrained-safe checks
- collect timing and ping telemetry
- skip focus automation, integrity enforcement, and actual keyboard injection
- mark keyboard-driven actions as simulated in the logs and final summary

Use a full language mode session if you need real foreground focus control and actual SendKeys input.

## Logs

Each run writes logs under `logs`:

- `run-<guid>.log`
- `run-<guid>.jsonl`

The JSONL log contains structured event entries and, when enabled, per-sample ping details.

At startup, the script logs the effective ping target so the active telemetry host is explicit in the text log, console output, and JSONL log.

Per-action ping summaries are also written as human-readable summary lines to the console and text log, while the JSONL log retains the structured telemetry payload.

For live execution, the logs also include additional readiness and focus diagnostics such as:

- `Premiere/Waiting` while the main window is still loading or the project cannot yet be confirmed
- `Focus/Attempt` and `Focus/MissingWindow` during retry loops
- `Focus/IntegrityCheck` and `Focus/IntegrityWarning` when checking privilege alignment between the script, Premiere, and Chrome

In constrained live mode, the logs also record when focus, integrity checks, and key sends were intentionally skipped.

On Windows live runs, the script now uses `ping.exe` for telemetry sampling instead of `Test-Connection` to avoid host-specific and resource-related issues in restricted Windows PowerShell environments. If ping telemetry still reports failures, the remaining causes are usually DNS resolution problems, ICMP policy blocks, or unreachable targets rather than Constrained Language Mode itself. The script logs the first ping failure for each action and summarizes the rest to reduce noise.

## Testing Strategy

Recommended order:

1. run `-DryRun` to confirm config structure and workflow logging
2. run `-ValidateOnly` after setting real paths
3. run `-Preflight` to confirm live prerequisites and identify blockers
4. run a live session on the target Windows workstation
5. review the latest files in `logs`

## Project Files

- `main.ps1` - entry point and full workflow implementation
- `SPEC.md` - technical specification
- `.github/copilot-instructions.md` - workspace instructions
