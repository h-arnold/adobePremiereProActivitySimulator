# Premiere Pro Performance Test Tool

**What this does:** Opens a Premiere project on your Windows computer, simulates timeline editing (play, skip forward/back), and measures network speed and computer performance while working.

**Why use this:** You're troubleshooting why Premiere is slow. This tool shows you exactly where the slowness comes from.

---

## 3-Minute Quick Start

### Step 1: Edit the project path

Open `main.ps1` in a text editor and find line 31:

```powershell
ProjectPath = 'C:\path\to\prem_proj.proj'
```

Change it to your actual Premiere project file:

```powershell
ProjectPath = 'C:\Users\YourName\Documents\MyProject.prproj'
```

### Step 2: (Optional) Edit the ping target

Find line 16 in `main.ps1`:

```powershell
$PingTarget = 'google.com'
```

Change `google.com` to your actual media server or file server hostname:

```powershell
$PingTarget = 'fileserver.company.local'
```

(If you don't know the server, leave it as is. You can change it later.)

### Step 3: Run it

Open PowerShell and paste this:

```powershell
cd "C:\path\to\adobePremiereProActivitySimulator"
powershell -ExecutionPolicy Bypass -File .\main.ps1
```

The script will:
1. Open two Chrome windows automatically
2. Open your Premiere project
3. Simulate editing (pressing play, skipping forward, pausing, etc.)
4. **Measure network speed and computer load while it does this**
5. Write results to a `logs` folder when done

---

## Check Before You Run

- [ ] Adobe Premiere Pro is installed on this computer
- [ ] Google Chrome is installed
- [ ] You are logged into Adobe (Premiere is enabled)
- [ ] The file path you entered actually exists
- [ ] This is the actual computer having the performance problem

---

## After It Runs

Results are in the `logs` folder:

- **`run-*.log`** = readable text file (you can open in Notepad)
- **`run-*.jsonl`** = data file for importing into Excel/analysis tools

To find your latest results, run this in PowerShell:

```powershell
Get-ChildItem .\logs\run-*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Invoke-Item
```

---

## Want to test safely first? (Without opening Premiere)

If you want to make sure the script works before actually launching applications:

```powershell
powershell -ExecutionPolicy Bypass -File .\main.ps1 -DryRun
```

This creates fake results so you can see what the output looks like.

---

## Check your edits before running

If you want to validate you didn't make any typos:

```powershell
powershell -ExecutionPolicy Bypass -File .\main.ps1 -ValidateOnly
```

---

## What the results mean

The script measures these numbers during each editing action:

| Measurement | What it means |
|---|---|
| **Ping (ms)** | Network latency to your server (lower is better; >50ms is usually slow) |
| **CPU %** | How hard your computer is working (>80% = struggling) |
| **Memory (MB)** | RAM being used |
| **Network (MB/s)** | Download speed from your server (lower = bottleneck) |

**High numbers that repeat every time** = that's your bottleneck.

---

## Troubleshooting

### "Premiere won't open" or "Script says to close Premiere"
Close any existing Premiere windows first. The script reopens it automatically.

### "Script can't find Chrome"
Install Google Chrome. Or in main.ps1, set `Browser.ExecutablePath` to your actual chrome.exe path.

### "Cannot open file" error for the ProjectPath
Make sure:
- You used the full path (don't use shortcuts like `~` or `.`)
- The file name is spelled exactly right, including the `.prproj` extension
- The path exists and you have permission to access it

### "Focus failure" errors
This means PowerShell couldn't click on the Premiere window. Common fixes:
- Make sure Premiere and PowerShell are both running at the same privilege level (e.g., both as admin or both as user)
- Try closing all Adobe popups before running

---

## Want to customize it? (Advanced)

See these guides:
- [Full configuration reference](docs/configuration-guide.md) — all tunable settings explained
- [How to edit workflow actions](docs/scenario-editing-guide.md) — change which keyboard commands run

Otherwise, **the defaults work fine**. Most people don't need to change anything except the project path.

---

## Run modes summary

| Command | What it does |
|---|---|
| `main.ps1` | Runs the full test (opens Chrome, Premiere, simulates editing) |
| `main.ps1 -ValidateOnly` | Checks your config for typos (no apps open) |
| `main.ps1 -DryRun` | Runs the whole test but with fake data |
| `main.ps1 -Preflight` | Checks if your system is ready to run |

---

## When you have results from multiple computers

To compare performance across machines:

```powershell
# In PowerShell, from the scripts root folder:

# Find actions with slow network (>25ms latency):
Get-ChildItem .\logs -Filter *.jsonl -Recurse |
  ForEach-Object { Get-Content $_.FullName } |
  ForEach-Object { $_ | ConvertFrom-Json } |
  Where-Object { $_.PingAverageMs -gt 25 } |
  Select-Object ActionName, PingAverageMs, @{n='Computer';e={Split-Path (Split-Path $_.LogPath) -Leaf}} |
  Sort-Object PingAverageMs -Descending
```

---

## Full Reference (if you need more details)

1. Download [this script](main.ps1)
2. Set `$Config.Premiere.ProjectPath` to the real `.prproj` used for testing.
3. Set the telemetry ping target to the actual CIFS/SMB file server hosting project/media files. In `main.ps1`, `$Config.Telemetry.PingTarget` is initialised from `$PingTarget`, so you can change either.
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

For a complete field-by-field guide (including tuning recipes by operational goal), see [`docs/configuration-guide.md`](docs/configuration-guide.md).
For scenario/action editing examples, see [`docs/scenario-editing-guide.md`](docs/scenario-editing-guide.md).

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
