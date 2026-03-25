# Premiere Pro Workflow Simulator

Synthetic Adobe Premiere Pro workflow automation for Windows desktop diagnostics.

## Ultra-concise summary

This script opens two browser videos, opens a Premiere project, simulates playback/scrubbing actions, and logs latency/CPU/memory/network telemetry per action so you can compare performance across machines.

## Table of Contents

- [Start here (60 seconds)](#start-here-60-seconds)
- [Run this now (copy/paste commands)](#run-this-now-copypaste-commands)
- [Common mistakes that invalidate results](#common-mistakes-that-invalidate-results)
- [What logs to collect](#what-logs-to-collect)
- [Detailed reference](#detailed-reference)
  - [What It Does](#what-it-does)
  - [Requirements](#requirements)
  - [Configuration](#configuration)
  - [Run Modes](#run-modes)
  - [Logs](#logs)
  - [Testing Strategy](#testing-strategy)
  - [Project Files](#project-files)

## Start here (60 seconds)

1. Set `$Config.Premiere.ProjectPath` to the real `.prproj` used for testing.
2. Set the telemetry ping target to the actual CIFS/SMB file server hosting project/media files. In `main.ps1`, `$Config.Telemetry.PingTarget` is initialised from `$PingTarget`, so you can change either.
3. Confirm enough Adobe CC licences, then sign in on every test machine first.
4. Run `-Preflight`; only run live if preflight is clean.
5. For benchmark-quality data, run in an unconstrained PowerShell/desktop automation environment.

Note: you normally do **not** need to change the default YouTube URLs; they are intentionally chosen to represent tutorial + Spotify-style concurrent streaming load.

## Run this now (copy/paste commands)

**Get the script onto the test machine (pick one method):**

```powershell
# Method A: clone a repo
git clone <repo-url> .\adobePremiereProActivitySimulator
cd .\adobePremiereProActivitySimulator
```

```powershell
# Method B: copy from a shared location
Copy-Item \\<server>\<share>\adobePremiereProActivitySimulator .\ -Recurse -Force
cd .\adobePremiereProActivitySimulator
```

**Prepare and run:**

```powershell
# Optional: unblock if files came from internet/download zone
Get-ChildItem .\*.ps1 | Unblock-File

# 1) Validate config/schema only
powershell -ExecutionPolicy Bypass -File .\main.ps1 -ValidateOnly

# 2) Dry-run for safe log verification
powershell -ExecutionPolicy Bypass -File .\main.ps1 -DryRun

# 3) Preflight live readiness checks
powershell -ExecutionPolicy Bypass -File .\main.ps1 -Preflight

# 4) Live run
powershell -ExecutionPolicy Bypass -File .\main.ps1
```

**Useful log commands:**

```powershell
# List newest runs
Get-ChildItem .\logs\run-* | Sort-Object LastWriteTime -Descending | Select-Object -First 10

# Tail latest text log
Get-Content (Get-ChildItem .\logs\*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName -Wait
```

## Common mistakes that invalidate results

- Placeholder project path left unchanged.
- Ping target set to a generic host instead of the actual file server.
- Running broad benchmarks in constrained mode and treating results as equivalent to full automation runs.
- Skipping Adobe CC licence planning and account sign-in before starting a broad rollout.
- Inconsistent project/media payload across devices.
- Ignoring adapter selection on machines with Wi‑Fi + ethernet + VPN adapters.
- Mixing dry-run and live logs during analysis.
- Running script elevated while Premiere/Chrome are unelevated (or vice versa), which can break focus/input behaviour.

## What logs to collect

- `logs\run-<guid>.log` for readable timelines.
- `logs\run-<guid>.jsonl` for structured cross-device analysis.

Use the text log for “what happened”. Use JSONL for “how bad was it and when”.

## What to look for in JSONL when performance is intermittent

Across machines, compare these recurring patterns:

- ping spikes and packet loss during timeline actions
- high CPU/memory pressure at the same time as input lag
- network throughput drops or bursts aligned with playback/scrub actions
- repeated focus retries or readiness delays before actions complete

If symptoms happen at the same action names (for example `ObservePlayback`, `StepForwardBurst`, `FinalObservePlayback`) on multiple devices, you likely have a systemic bottleneck rather than a single endpoint issue.

## Quick PowerShell triage snippets for many JSONL files

Run from repo root after collecting logs from multiple devices into one folder tree.

Count high-latency ping samples from ping summaries (CIFS-impact threshold example: > 20 ms):

```powershell
Get-ChildItem .\logs -Filter *.jsonl -Recurse |
  ForEach-Object {
    $file = $_.FullName
    Get-Content $file | ForEach-Object {
      $e = $_ | ConvertFrom-Json
      if ($e.Component -eq 'Telemetry' -and $e.EventType -eq 'PingSummary' -and $e.PingSamples) {
        foreach ($sample in $e.PingSamples) {
          if ($sample.Success -and $sample.LatencyMs -gt 20) {
            [pscustomobject]@{ File = $file; Action = $e.ActionName; RttMs = $sample.LatencyMs; Ts = $sample.Timestamp }
          }
        }
      }
    }
  } | Group-Object File | Sort-Object Count -Descending | Select-Object -First 20
```

Find actions with the worst average latency:

```powershell
Get-ChildItem .\logs -Filter *.jsonl -Recurse |
  ForEach-Object { Get-Content $_.FullName } |
  ForEach-Object { $_ | ConvertFrom-Json } |
  Where-Object { $_.Component -eq 'Telemetry' -and $_.EventType -eq 'PingSummary' -and $_.PingTelemetryAvailable } |
  Group-Object { $_.ActionName } |
  ForEach-Object {
    $avg = ($_.Group | Measure-Object -Property PingAverageMs -Average).Average
    [pscustomobject]@{ Action = $_.Name; AvgRttMs = [math]::Round($avg,2); Samples = $_.Count }
  } | Sort-Object AvgRttMs -Descending
```

Surface runs where throughput collapsed during actions:

```powershell
Get-ChildItem .\logs -Filter *.jsonl -Recurse |
  ForEach-Object {
    $file = $_.FullName
    Get-Content $file | ForEach-Object {
      $e = $_ | ConvertFrom-Json
      if ($e.Component -eq 'Telemetry' -and $e.EventType -eq 'NetworkSummary' -and $e.NetworkTelemetryAvailable -and $e.TotalAverageMBPerSec -lt 1) {
        [pscustomobject]@{ File = $file; Action = $e.ActionName; TotalAvgMBps = [math]::Round($e.TotalAverageMBPerSec,3); Ts = $e.Timestamp }
      }
    }
  } | Select-Object -First 200
```

## Optional: simulate baseline school internet load

If you want results that better mirror normal lesson conditions, generate representative background traffic while running the simulator (for example via a carefully configured `iperf3` setup that approximates baseline site usage). Keep the traffic model consistent across runs so the comparison remains fair.

## Detailed reference

### What It Does

The script in `main.ps1` implements the workflow described in `SPEC.md`:

- launches two Chrome windows before Premiere automation starts (to simulate a tutorial stream plus concurrent Spotify/background media usage)
- launches a configured Premiere project
- waits for Premiere readiness
- focuses the Premiere window before every keyboard-driven action
- simulates a short playback/editing workflow with jittered timing
- samples ping telemetry at a configurable interval per action
- samples system CPU and memory load at the same telemetry cadence per action
- samples network throughput at the same telemetry cadence per action
- writes text and JSONL logs with per-action telemetry summaries

### Requirements

- Windows PowerShell 5.1 in an interactive Windows desktop session
- Adobe Premiere Pro installed and able to open the target project
- Google Chrome installed
- a valid `.prproj` path configured in `main.ps1`
- Premiere, Chrome, and the PowerShell session running at the same privilege level for full desktop automation

### Configuration

Edit the script-top constants and the top-level `$Config` object in `main.ps1` before live execution.

Telemetry cadence is controlled by `$Config.Telemetry.TelemetrySampleIntervalSec`. The same interval is used for ping, system load, and network throughput sampling within each action, and it can be set to a fractional number of seconds.
Telemetry samples are gathered by a shared background timer while each action is running.

**Minimum required changes:**

- usually keep the default two values in `$ChromeUrls` unchanged (they already simulate tutorial + Spotify-style concurrent streaming)
- if needed, set `$PingTarget` (or `$Config.Telemetry.PingTarget`, which is initialised from `$PingTarget`)
- set `$Config.Premiere.ProjectPath`
- if needed, set `$Config.Browser.ExecutablePath`
- if needed, set `$Config.Premiere.ExecutablePath`
- if needed, set `$Config.Telemetry.NetworkAdapterName` to pin throughput sampling to a specific adapter
- adjust `$Config.Premiere.ProcessName`, `$Config.Premiere.ProcessNames`, or `$Config.Premiere.WindowTitleRegex` if your Premiere install differs

For live runs, the script now prefers a Premiere window whose title matches both the configured window regex and the configured project name when possible. If your environment uses a different process name variant, add it to `$Config.Premiere.ProcessNames`.

### Run Modes

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

This runs the full controller path with simulated launches, focus, key input, ping samples, system load samples, and network throughput samples so you can inspect the generated logs safely.

In `-DryRun`, ping samples, system load samples, and network throughput samples are synthetic by design. They are generated inside the script and do not represent real network reachability or workstation load.

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

Live desktop automation should still be validated in Windows PowerShell 5.1 because SendKeys and UI automation behaviour are host-sensitive.

If the host is running in PowerShell Constrained Language Mode, the script now falls back to a degraded live mode instead of failing immediately. In that mode it will:

- launch Chrome and Premiere normally
- wait for Premiere readiness using constrained-safe checks
- collect timing, ping, CPU, and memory telemetry
- skip focus automation, integrity enforcement, and actual keyboard injection
- mark keyboard-driven actions as simulated in the logs and final summary

Use a full language mode session if you need real foreground focus control and actual SendKeys input.

### Logs

Each run writes logs under `logs`:

- `run-<guid>.log`
- `run-<guid>.jsonl`

The JSONL log contains structured event entries and, when enabled, per-sample ping details and per-sample system load details.

At startup, the script logs the effective ping target so the active telemetry host is explicit in the text log, console output, and JSONL log.

Per-action ping summaries, per-action system load summaries, and per-action network throughput summaries are also written as human-readable summary lines to the console and text log, while the JSONL log retains the structured telemetry payload.

For live execution, the logs also include additional readiness and focus diagnostics such as:

- `Premiere/Waiting` while the main window is still loading or the project cannot yet be confirmed
- `Focus/Attempt` and `Focus/MissingWindow` during retry loops
- `Focus/IntegrityCheck` and `Focus/IntegrityWarning` when checking privilege alignment between the script, Premiere, and Chrome

In constrained live mode, the logs also record when focus, integrity checks, and key sends were intentionally skipped.

On Windows live runs, the script now uses `ping.exe` for network telemetry sampling instead of `Test-Connection` to avoid host-specific and resource-related issues in restricted Windows PowerShell environments. If ping telemetry still reports failures, the remaining causes are usually DNS resolution problems, ICMP policy blocks, or unreachable targets rather than Constrained Language Mode itself. The script logs the first ping failure for each action and summarizes the rest to reduce noise.

System load telemetry is collected separately from ping telemetry. Each action now produces a dedicated system load summary with CPU min, median, average, and max figures plus memory-used min, median, average, and max figures.

Network throughput telemetry is collected separately from ping and system load telemetry. Each action now produces a dedicated throughput summary with receive, send, and total MB/s figures.

When no adapter name is configured, the script automatically prefers the first active ethernet adapter for throughput sampling. If your workstation has more than one active adapter, set `$Config.Telemetry.NetworkAdapterName` to avoid ambiguity.

### Testing Strategy

Recommended order:

1. run `-DryRun` to confirm config structure and workflow logging
2. run `-ValidateOnly` after setting real paths
3. run `-Preflight` to confirm live prerequisites and identify blockers
4. run a live session on the target Windows workstation
5. review the latest files in `logs`

### Project Files

- `main.ps1` - entry point and full workflow implementation
- `SPEC.md` - technical specification
- `.github/copilot-instructions.md` - workspace instructions
