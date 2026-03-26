# Premiere Pro Performance Test Tool

**What this does:** Opens a Premiere project on your Windows computer, simulates timeline editing (play, skip forward/back), and measures network speed and computer performance while working.

**Why use this:** You're troubleshooting why Premiere is slow over the network. This tool shows you exactly where the slowness comes from.

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
| **Ping (ms)** | Network latency to your server (lower is better; CIFS performance degrades significantly with pings over 20ms) |
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

The defaults work fine for most people. If you want to change behavior, see these guides:

- [Full configuration reference](docs/configuration-guide.md) — explains all tunable settings
- [How to edit workflow actions](docs/scenario-editing-guide.md) — change which keyboard commands run and how long each waits

**You don't need to read these unless you want to customize beyond the project path.**

---

## Run modes summary

These are the different ways you can run the script:

| Command | What it does | When to use |
|---|---|---|
| `powershell -ExecutionPolicy Bypass -File .\main.ps1` | Runs the full test | Normal usage |
| `powershell -ExecutionPolicy Bypass -File .\main.ps1 -ValidateOnly` | Checks your config for typos | Before running for the first time |
| `powershell -ExecutionPolicy Bypass -File .\main.ps1 -DryRun` | Runs with fake data | To see if the script works without actually testing |
| `powershell -ExecutionPolicy Bypass -File .\main.ps1 -Preflight` | Checks if your system is ready | To diagnose setup problems |

---

## Recommended Execution Sequence

Before running on all machines, follow this safe sequence:

```powershell
# 1) Validate your edits for typos (no apps launch)
powershell -ExecutionPolicy Bypass -File .\.main.ps1 -ValidateOnly

# 2) Dry-run to see output without real Premiere/Chrome (optional but recommended)
powershell -ExecutionPolicy Bypass -File .\.main.ps1 -DryRun

# 3) Preflight to verify system is ready
powershell -ExecutionPolicy Bypass -File .\.main.ps1 -Preflight

# 4) Live run if all steps above passed
powershell -ExecutionPolicy Bypass -File .\.main.ps1
```

**Never skip `-ValidateOnly` on the first run on each machine.** Typos in the project path will waste time and produce invalid results.

---

## Getting Started with Deployment

To deploy this script to multiple machines:

### Option A: Clone from repository (if you have git)

```powershell
git clone https://github.com/h-arnold/adobePremiereProActivitySimulator.git
cd .\adobePremiereProActivitySimulator
```

### Option B: Copy from a shared location

```powershell
Copy-Item \\\\<server>\\<share>\\adobePremiereProActivitySimulator .\ -Recurse -Force
cd .\adobePremiereProActivitySimulator
```

### If files came from the internet or email:

Remove the "downloaded from internet" block:

```powershell
Get-ChildItem .\*.ps1 | Unblock-File
```

**This is critical:** Windows blocks scripts downloaded from the internet. If you skip this, you'll get a confusing "cannot be loaded" error.

---

## Common Mistakes That Invalidate Results

Before deploying widely, watch out for these:

- **Placeholder project path left unchanged** — Script will fail or open the wrong project. Always validate with `-ValidateOnly`.
- **Ping target set to `google.com`** — Measures internet speed, not your file server. Set it to your actual CIFS/SMB server.
- **Running script elevated (as admin) while Premiere/Chrome are unelevated** (or vice versa) — Breaks window focus and keyboard input. All three must run at the same privilege level.
- **Adobe CC not licensed on the test machine** — Script will stall waiting for login. Sign in manually first.
- **Different project files on each test machine** — Results won't be comparable. Use the same `.prproj` across all machines.
- **Ignoring multiple network adapters** — If a machine has Wi-Fi + Ethernet + VPN, script may measure the wrong adapter. See `Telemetry.NetworkAdapterName` in [configuration guide](docs/configuration-guide.md).
- **Mixing dry-run and live logs during analysis** — Dry-run produces fake data. Separate them into different folders before comparing.

**Validation workflow:** If results look suspicious (all machines fast, or all slow), re-run `-Preflight` and check one machine manually before scaling to more.

---

## Comparing results from multiple computers

If you have results from several machines and want to see which one has the slowest network:

```powershell
# In PowerShell, from the script folder:

# Find actions with slow network (more than 25ms latency):
Get-ChildItem .\logs -Filter *.jsonl -Recurse |
  ForEach-Object { Get-Content $_.FullName } |
  ForEach-Object { $_ | ConvertFrom-Json } |
  Where-Object { $_.PingAverageMs -gt 25 } |
  Select-Object ActionName, PingAverageMs |
  Sort-Object PingAverageMs -Descending
```

---

## Log Analysis Reference

After runs complete, use these commands to find problems:

### Find the latest log file

```powershell
# Opens the most recent text log in Notepad
Get-ChildItem .\logs\run-*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Invoke-Item

# Or view it in PowerShell
Get-Content (Get-ChildItem .\logs\*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
```

### Tail a log in real-time (while the script is running)

```powershell
Get-Content (Get-ChildItem .\logs\*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName -Wait
```

### Find which machines have high network latency

```powershell
# Searches all logs for actions with ping > 20ms (CIFS threshold)
Get-ChildItem .\logs -Filter *.jsonl -Recurse |
  ForEach-Object {
    $file = $_.FullName
    Get-Content $file | ForEach-Object {
      $e = $_ | ConvertFrom-Json
      if ($e.PingAverageMs -gt 20) {
        [pscustomobject]@{
          'Computer' = Split-Path (Split-Path $file) -Leaf
          'Action' = $e.ActionName
          'Ping_ms' = $e.PingAverageMs
        }
      }
    }
  } | Sort-Object Ping_ms -Descending
```

### Find actions where network throughput is low (< 1 MB/s)

```powershell
Get-ChildItem .\logs -Filter *.jsonl -Recurse |
  ForEach-Object {
    $file = $_.FullName
    Get-Content $file | ForEach-Object {
      $e = $_ | ConvertFrom-Json
      if ($e.NetworkAverageMBPerSec -lt 1) {
        [pscustomobject]@{
          'Computer' = Split-Path (Split-Path $file) -Leaf
          'Action' = $e.ActionName
          'Network_MBps' = $e.NetworkAverageMBPerSec
        }
      }
    }
  } | Select-Object -First 50
```

### Find highest CPU usage moments

```powershell
Get-ChildItem .\logs -Filter *.jsonl -Recurse |
  ForEach-Object { Get-Content $_.FullName } |
  ForEach-Object { $_ | ConvertFrom-Json } |
  Where-Object { $_.CpuAveragePercent -gt 80 } |
  Select-Object ActionName, CpuAveragePercent, MemoryLargestMB |
  Sort-Object CpuAveragePercent -Descending
```

---

## Interpreting Results Across Multiple Machines

When comparing results, look for these patterns:

### Network is the bottleneck
- **Same action slow on multiple machines** → likely the file/project server, not the client.
- **Ping stays high (>20ms) during all actions** → consistent network latency problem.
- **Network throughput (MB/s) is low** → bandwidth limitation, check adapter/link speed.

### Local machine is the bottleneck
- **One machine slow on all actions, others fast** → check that machine's CPU, RAM, or local drive speed.
- **CPU spiking (>80%) during playback** → local encoding/analysis load, not network.
- **Memory usage growing during run** → possible memory leak in Premiere or a background process.

### User behaviour is affecting results
- **Random, intermittent slowness** → check if antivirus, backups, or updates are running on that machine.
- **Inconsistent results on same machine** → make sure Premiere is fully unloaded between runs (check Task Manager).

### Problem is systemic, not local
- **Same action name slow on ALL machines at the same time** (e.g., `ObservePlayback` is always slow) → infrastructure problem.
- **Different actions slow on different machines** → likely per-machine issues, check individually.

---

## Optional: Simulate Baseline Network Load

If you want results that reflect actual classroom/office conditions, you can generate background network traffic while the script runs:

```powershell
# In a separate PowerShell window on the same machine:
iperf3 -c <fileserver> -t 300 &

# Then in the main window:
powershell -ExecutionPolicy Bypass -File .\.main.ps1
```

This adds consistent background load (simulating other users on the network), making results more representative of real usage. **Keep the traffic load consistent across all test runs** so you can compare fairly.

For more advanced network simulation, use NetLimiter or TMN (Traffic Management Nexus) to enforce specific bandwidth/latency caps.

---

## For more details

- [Full technical specification](SPEC.md) — how the tool works internally
- [Full configuration reference](docs/configuration-guide.md) — every setting explained
- [How to edit workflow actions](docs/scenario-editing-guide.md) — add or change keyboard actions

Start with the Quick Start section above. Only read the detailed guides if you need to customize behavior.
