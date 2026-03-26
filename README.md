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

## For more details

- [Full technical specification](SPEC.md) — how the tool works internally
- [Full configuration reference](docs/configuration-guide.md) — every setting explained
- [How to edit workflow actions](docs/scenario-editing-guide.md) — add or change keyboard actions

Start with the Quick Start section above. Only read the detailed guides if you need to customize behavior.
