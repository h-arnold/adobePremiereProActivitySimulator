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
- Premiere, Chrome, and the PowerShell session running at the same privilege level

## Configuration

Edit the script-top constants and the top-level `$Config` object in `main.ps1` before live execution.

Minimum required changes:

- set the two values in `$ChromeUrls`
- set `$Config.Premiere.ProjectPath`
- if needed, set `$Config.Browser.ExecutablePath`
- if needed, set `$Config.Premiere.ExecutablePath`
- adjust `$Config.Premiere.ProcessName` or `$Config.Premiere.WindowTitleRegex` if your Premiere install differs

## Run Modes

Validation only:

```powershell
powershell -ExecutionPolicy Bypass -File .\main.ps1 -ValidateOnly
```

This checks the configuration shape and scenario structure without launching applications or requiring the configured files to exist yet.

Dry-run simulation:

```powershell
powershell -ExecutionPolicy Bypass -File .\main.ps1 -DryRun
```

This runs the full controller path with simulated launches, focus, key input, and ping samples so you can inspect the generated logs safely.

Live execution:

```powershell
powershell -ExecutionPolicy Bypass -File .\main.ps1
```

If you use PowerShell 7 for dry-run checks:

```powershell
pwsh -File .\main.ps1 -DryRun
```

Live desktop automation should still be validated in Windows PowerShell 5.1 because SendKeys and UI automation behavior are host-sensitive.

## Logs

Each run writes logs under `logs`:

- `run-<guid>.log`
- `run-<guid>.jsonl`

The JSONL log contains structured event entries and, when enabled, per-sample ping details.

## Testing Strategy

Recommended order:

1. run `-DryRun` to confirm config structure and workflow logging
2. run `-ValidateOnly` after setting real paths
3. run a live session on the target Windows workstation
4. review the latest files in `logs`

## Project Files

- `main.ps1` - entry point and full workflow implementation
- `SPEC.md` - technical specification
- `.github/copilot-instructions.md` - workspace instructions
