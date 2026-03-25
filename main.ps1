[CmdletBinding()]
param(
	[switch]$ValidateOnly,
	[switch]$DryRun,
	[switch]$Preflight,
	[string]$RunId = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ChromeUrls = @(
	'https://www.youtube.com/watch?v=xm3YgoEiEDc'
	'https://www.youtube.com/watch?v=HIcSWuKMwOw'
)

$PingTarget = 'google.com'

$Config = @{
	Browser = @{
		ExecutablePath = $null
		Urls = $ChromeUrls
		LaunchCount = 2
		LaunchDelayMs = 1500
		RequireSuccessfulLaunch = $true
	}
	Premiere = @{
		ExecutablePath = $null
		Arguments = @()
		UseFileAssociation = $true
		ProcessName = 'Adobe Premiere Pro'
		ProcessNames = @('Adobe Premiere Pro')
		WindowTitleRegex = 'Premiere Pro'
		ProjectPath = 'C:\path\to\prem_proj.proj'
		InitialLoadDelayMs = 10000
	}
	Focus = @{
		RetryCount = 5
		RetryDelayMs = 750
		VerifyDelayMs = 400
		RequireSameIntegrityLevel = $true
	}
	Timing = @{
		Micro = @{ MinMs = 100; MaxMs = 300 }
		Normal = @{ MinMs = 400; MaxMs = 1500 }
		Think = @{ MinMs = 2000; MaxMs = 6000 }
	}
	Workflow = @{
		MaxRunTimeSec = 900
		LoopCount = 1
		ReadyTimeoutSec = 120
	}
	Keyboard = @{
		PlayPause = 'k'
		StepForward = 'l'
		StepBack = 'j'
	}
	Logging = @{
		LogPath = (Join-Path -Path $PSScriptRoot -ChildPath 'logs')
		LogLevel = 'Information'
		EnableConsole = $true
		EnableJsonLog = $true
		IncludePingDetail = $true
		IncludeSystemLoadDetail = $true
		IncludeNetworkDetail = $true
	}
	Telemetry = @{
		PingTarget = $PingTarget
		TelemetrySampleIntervalSec = 1
		PingTimeoutMs = 1000
		SampleOnStart = $true
		FailureWarningLimitPerAction = 1
		NetworkAdapterName = $null
	}
	Safety = @{
		AbortOnFocusFailure = $true
		MaxConsecutiveErrors = 3
	}
}

$Scenario = @(
	@{
		Type = 'KeyPress'
		Name = 'Play'
		Keys = $Config.Keyboard.PlayPause
		JitterProfile = 'Normal'
		RepeatCount = 1
		FocusRequired = $true
		AbortOnFailure = $true
		PreDelayMs = 0
		PostDelayMs = 0
	}
	@{
		Type = 'Wait'
		Name = 'ObservePlayback'
		Keys = $null
		JitterProfile = 'Think'
		RepeatCount = 1
		FocusRequired = $false
		AbortOnFailure = $false
		DurationMs = 10000
		PreDelayMs = 0
		PostDelayMs = 0
	}
	@{
		Type = 'KeyPress'
		Name = 'PauseAfterObservation'
		Keys = $Config.Keyboard.PlayPause
		JitterProfile = 'Normal'
		RepeatCount = 1
		FocusRequired = $true
		AbortOnFailure = $true
		PreDelayMs = 0
		PostDelayMs = 250
	}
	@{
		Type = 'Burst'
		Name = 'StepBackBurst'
		Keys = $null
		JitterProfile = 'Micro'
		RepeatCount = 1
		FocusRequired = $true
		AbortOnFailure = $true
		Sequence = @(
			@{
				Type = 'KeyPress'
				Name = 'StepBack'
				Keys = $Config.Keyboard.StepBack
				JitterProfile = 'Micro'
				RepeatCount = 2
				FocusRequired = $true
				AbortOnFailure = $true
				PreDelayMs = 0
				PostDelayMs = 50
			}
		)
		PreDelayMs = 0
		PostDelayMs = 0
	}
	@{
		Type = 'Burst'
		Name = 'StepForwardBurst'
		Keys = $null
		JitterProfile = 'Micro'
		RepeatCount = 2
		FocusRequired = $true
		AbortOnFailure = $true
		Sequence = @(
			@{
				Type = 'KeyPress'
				Name = 'StepForward'
				Keys = $Config.Keyboard.StepForward
				JitterProfile = 'Micro'
				RepeatCount = 1
				FocusRequired = $true
				AbortOnFailure = $true
				PreDelayMs = 0
				PostDelayMs = 500
			}
		)
		PreDelayMs = 0
		PostDelayMs = 0
	}
	@{
		Type = 'Burst'
		Name = 'FinalStepBackBurst'
		Keys = $null
		JitterProfile = 'Micro'
		RepeatCount = 1
		FocusRequired = $true
		AbortOnFailure = $true
		Sequence = @(
			@{
				Type = 'KeyPress'
				Name = 'StepBack'
				Keys = $Config.Keyboard.StepBack
				JitterProfile = 'Micro'
				RepeatCount = 3
				FocusRequired = $true
				AbortOnFailure = $true
				PreDelayMs = 0
				PostDelayMs = 50
			}
		)
		PreDelayMs = 0
		PostDelayMs = 0
	}
	@{
		Type = 'KeyPress'
		Name = 'PauseBeforeFinalPlayback'
		Keys = $Config.Keyboard.PlayPause
		JitterProfile = 'Normal'
		RepeatCount = 1
		FocusRequired = $true
		AbortOnFailure = $true
		PreDelayMs = 0
		PostDelayMs = 0
	}
	@{
		Type = 'KeyPress'
		Name = 'FinalPlay'
		Keys = $Config.Keyboard.PlayPause
		JitterProfile = 'Normal'
		RepeatCount = 1
		FocusRequired = $true
		AbortOnFailure = $true
		PreDelayMs = 0
		PostDelayMs = 0
	}
	@{
		Type = 'Wait'
		Name = 'FinalObservePlayback'
		Keys = $null
		JitterProfile = 'Think'
		RepeatCount = 1
		FocusRequired = $false
		AbortOnFailure = $false
		DurationMs = 15000
		PreDelayMs = 0
		PostDelayMs = 0
	}
	@{
		Type = 'KeyPress'
		Name = 'FinalPause'
		Keys = $Config.Keyboard.PlayPause
		JitterProfile = 'Normal'
		RepeatCount = 1
		FocusRequired = $true
		AbortOnFailure = $true
		PreDelayMs = 0
		PostDelayMs = 0
	}
)

$script:RunState = $null
$script:AppActivator = $null

function Test-IsWindows {
	return $env:OS -eq 'Windows_NT'
}

function Test-IsConstrainedLanguageMode {
	return $ExecutionContext.SessionState.LanguageMode -eq 'ConstrainedLanguage'
}

function Test-DesktopAutomationAvailable {
	return (Test-IsWindows) -and (-not (Test-IsConstrainedLanguageMode))
}

function Test-CanInjectInput {
	return $script:RunState.ExecutionMode -eq 'FullLive'
}

function Invoke-NativePingSample {
	param(
		[Parameter(Mandatory = $true)]
		[psobject]$TelemetrySession,

		[Parameter(Mandatory = $true)]
		[datetime]$SampleTimestamp
	)

	$pingCommand = Get-Command -Name 'ping.exe' -ErrorAction SilentlyContinue
	if (-not $pingCommand) {
		throw 'ping.exe could not be resolved.'
	}

	$timeout = [int]$TelemetrySession.TimeoutMs
	if ($timeout -le 0) {
		$timeout = 1000
	}

	$output = & $pingCommand.Source '-n' '1' '-w' ([string]$timeout) $TelemetrySession.Target 2>&1
	$exitCode = $LASTEXITCODE
	$text = @($output) -join [Environment]::NewLine
	if ($exitCode -ne 0) {
		throw $text
	}

	$latencyMatch = [regex]::Match($text, 'time(?:=|<)(\d+)ms', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
	if (-not $latencyMatch.Success) {
		$latencyMatch = [regex]::Match($text, 'Average\s*=\s*(\d+)ms', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
	}

	if (-not $latencyMatch.Success) {
		throw 'ping.exe completed successfully but latency could not be parsed from its output.'
	}

	return [ordered]@{
		Timestamp = (Get-Date -Date $SampleTimestamp -Format o)
		Success = $true
		LatencyMs = [double]$latencyMatch.Groups[1].Value
		Error = $null
	}
}

function Get-Now {
	return Get-Date -Format o
}

function New-RunIdValue {
	return ('run-{0}-{1}' -f (Get-Date -Format 'yyyyMMddHHmmss'), (Get-Random -Minimum 1000 -Maximum 9999))
}

function Get-ElapsedMilliseconds {
	param(
		[Parameter(Mandatory = $true)]
		[datetime]$StartedAt
	)

	return ((Get-Date) - $StartedAt).TotalMilliseconds
}

function Get-UpperSeverity {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Severity
	)

	switch ($Severity) {
		'debug' { return 'DEBUG' }
		'information' { return 'INFORMATION' }
		'warning' { return 'WARNING' }
		'error' { return 'ERROR' }
		default { return $Severity }
	}
}

function Get-ExecutionPolicySnapshot {
	$entries = @()
	foreach ($policy in (Get-ExecutionPolicy -List)) {
		$entries += [ordered]@{
			Scope = [string]$policy.Scope
			ExecutionPolicy = [string]$policy.ExecutionPolicy
		}
	}

	return $entries
}

function Test-LogLevelEnabled {
	param(
		[Parameter(Mandatory = $true)]
		[string]$ConfiguredLevel,

		[Parameter(Mandatory = $true)]
		[string]$MessageLevel
	)

	$levelMap = @{
		Debug = 0
		Information = 1
		Warning = 2
		Error = 3
	}

	return $levelMap[$MessageLevel] -ge $levelMap[$ConfiguredLevel]
}

function Initialize-WindowsAutomation {
	if (-not (Test-IsWindows)) {
		return
	}

	Add-Type -AssemblyName System.Windows.Forms

	try {
		Add-Type -AssemblyName UIAutomationClient
	}
	catch {
		throw 'UIAutomationClient could not be loaded. Windows PowerShell 5.1 is the supported host for this script.'
	}

	if (-not ('WorkflowAutomation.NativeMethods' -as [type])) {
		Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace WorkflowAutomation {
	public static class NativeMethods {
		public const int SW_RESTORE = 9;
		public const int TOKEN_QUERY = 0x0008;
		public const int TokenElevation = 20;

		[StructLayout(LayoutKind.Sequential)]
		public struct TOKEN_ELEVATION {
			public int TokenIsElevated;
		}

		[DllImport("user32.dll")]
		public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

		[DllImport("user32.dll")]
		public static extern bool SetForegroundWindow(IntPtr hWnd);

		[DllImport("user32.dll")]
		public static extern IntPtr GetForegroundWindow();

		[DllImport("user32.dll")]
		public static extern bool IsWindowVisible(IntPtr hWnd);

		[DllImport("user32.dll")]
		public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

		[DllImport("advapi32.dll", SetLastError = true)]
		public static extern bool OpenProcessToken(IntPtr processHandle, int desiredAccess, out IntPtr tokenHandle);

		[DllImport("advapi32.dll", SetLastError = true)]
		public static extern bool GetTokenInformation(IntPtr tokenHandle, int tokenInformationClass, out TOKEN_ELEVATION tokenInformation, int tokenInformationLength, out int returnLength);

		[DllImport("kernel32.dll", SetLastError = true)]
		public static extern bool CloseHandle(IntPtr handle);
	}
}
"@
	}

	if (-not $script:AppActivator) {
		try {
			$script:AppActivator = New-Object -ComObject 'WScript.Shell'
		}
		catch {
			$script:AppActivator = $null
		}
	}
}

function New-RunState {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$Configuration,

		[Parameter(Mandatory = $true)]
		[string]$Id,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	$logDirectory = $Configuration.Logging.LogPath
	if (-not (Test-Path -LiteralPath $logDirectory)) {
		New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
	}

	$textLogPath = Join-Path -Path $logDirectory -ChildPath ("run-{0}.log" -f $Id)
	$jsonLogPath = Join-Path -Path $logDirectory -ChildPath ("run-{0}.jsonl" -f $Id)

	return [ordered]@{
		RunId = $Id
		StartedAt = Get-Date
		TextLogPath = $textLogPath
		JsonLogPath = $jsonLogPath
		DryRun = $SimulationOnly
		ExecutionMode = if ($SimulationOnly) { 'SimulationOnly' } else { 'PendingLive' }
		ActionResults = @()
		ChromeLaunches = @()
		Errors = @()
		ConsecutiveErrors = 0
		PremiereProcess = $null
	}
}

function Write-Log {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Component,

		[Parameter(Mandatory = $true)]
		[string]$EventType,

		[Parameter(Mandatory = $true)]
		[ValidateSet('Debug', 'Information', 'Warning', 'Error')]
		[string]$Severity,

		[string]$Message,
		[string]$ConsoleMessage = '',
		[hashtable]$Data = @{}
	)

	$entry = [ordered]@{
		Timestamp = Get-Now
		RunId = $script:RunState.RunId
		Component = $Component
		EventType = $EventType
		Severity = $Severity
		Message = $Message
	}

	foreach ($key in $Data.Keys) {
		$entry[$key] = $Data[$key]
	}

	$line = '{0} [{1}] {2}/{3} - {4}' -f $entry.Timestamp, (Get-UpperSeverity -Severity $entry.Severity), $Component, $EventType, $Message
	Add-Content -LiteralPath $script:RunState.TextLogPath -Value $line

	if ($Config.Logging.EnableJsonLog) {
		Add-Content -LiteralPath $script:RunState.JsonLogPath -Value (($entry | ConvertTo-Json -Depth 8 -Compress))
	}

	if ($Config.Logging.EnableConsole -and (Test-LogLevelEnabled -ConfiguredLevel $Config.Logging.LogLevel -MessageLevel $Severity)) {
		if ($ConsoleMessage) {
			Write-Host $ConsoleMessage
		}
		else {
			Write-Host $line
		}
	}
}

function Write-ActionLog {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$Action,

		[Parameter(Mandatory = $true)]
		[string]$Result,

		[Parameter(Mandatory = $true)]
		[double]$DurationMs,

		[hashtable]$TelemetrySummary = @{},
		[string]$ErrorMessage = ''
	)

	$payload = @{
		ActionName = $Action.Name
		Result = $Result
		Duration = $DurationMs
		ErrorMessage = $ErrorMessage
	}

	foreach ($key in $TelemetrySummary.Keys) {
		$payload[$key] = $TelemetrySummary[$key]
	}

	Write-Log -Component 'Workflow' -EventType 'ActionResult' -Severity 'Information' -Message ("Action '{0}' completed with result '{1}'." -f $Action.Name, $Result) -Data $payload
}

function Write-ErrorLog {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Component,

		[Parameter(Mandatory = $true)]
		[System.Exception]$Exception,

		[string]$ActionName = ''
	)

	$record = [ordered]@{
		Timestamp = Get-Now
		Component = $Component
		ActionName = $ActionName
		Message = $Exception.Message
	}

	$script:RunState.Errors += $record
	Write-Log -Component $Component -EventType 'Error' -Severity 'Error' -Message $Exception.Message -Data @{ ActionName = $ActionName }
}

function Resolve-ExecutablePath {
	param(
		[string]$ConfiguredPath,
		[string[]]$CandidatePaths
	)

	if ($ConfiguredPath) {
		if (Test-Path -LiteralPath $ConfiguredPath) {
			return $ConfiguredPath
		}

		$command = Get-Command -Name $ConfiguredPath -ErrorAction SilentlyContinue
		if ($command) {
			return $command.Source
		}

		throw "Executable path '$ConfiguredPath' could not be resolved."
	}

	foreach ($candidate in $CandidatePaths) {
		if ($candidate -and (Test-Path -LiteralPath $candidate)) {
			return $candidate
		}
	}

	return $null
}

function Test-UrlValue {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Value
	)

	return $Value -match '^https?://\S+$'
}

function Test-ChromeLaunchConfiguration {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$BrowserConfig,

		[bool]$SimulationOnly = $false
	)

	if ($BrowserConfig.Urls.Count -ne 2) {
		throw 'Exactly two Chrome URLs are required by the specification.'
	}

	foreach ($url in $BrowserConfig.Urls) {
		if (($null -eq $url) -or ($url -match '^\s*$') -or -not (Test-UrlValue -Value $url)) {
			throw "Invalid Chrome URL configured: '$url'."
		}
	}

	$resolvedChrome = Resolve-ExecutablePath -ConfiguredPath $BrowserConfig.ExecutablePath -CandidatePaths @(
		'C:\Program Files\Google\Chrome\Application\chrome.exe',
		'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
	)

	if (-not $resolvedChrome -and $BrowserConfig.RequireSuccessfulLaunch -and -not $SimulationOnly) {
		throw 'Chrome executable could not be resolved and successful Chrome launch is required.'
	}

	return $resolvedChrome
}

function Start-ChromeInstance {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Url,

		[string]$ExecutablePath,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	$startedAt = Get-Date
	if ($SimulationOnly) {
		return [ordered]@{
			Success = $true
			Url = $Url
			ProcessId = $null
			DurationMs = (Get-ElapsedMilliseconds -StartedAt $startedAt)
			ErrorReason = $null
		}
	}

	if (-not $ExecutablePath) {
		throw 'Chrome launch was requested but the Chrome executable path could not be resolved.'
	}

	$process = Start-Process -FilePath $ExecutablePath -ArgumentList @('--new-window', $Url) -PassThru

	return [ordered]@{
		Success = $true
		Url = $Url
		ProcessId = $process.Id
		DurationMs = (Get-ElapsedMilliseconds -StartedAt $startedAt)
		ErrorReason = $null
	}
}

function Start-ChromeLoad {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$BrowserConfig,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	$chromePath = Test-ChromeLaunchConfiguration -BrowserConfig $BrowserConfig -SimulationOnly $SimulationOnly
	$launchResults = @()

	for ($index = 0; $index -lt $BrowserConfig.Urls.Count; $index++) {
		$url = $BrowserConfig.Urls[$index]
		try {
			$result = Start-ChromeInstance -Url $url -ExecutablePath $chromePath -SimulationOnly $SimulationOnly
			$launchResults += $result
			$script:RunState.ChromeLaunches += $result

			Write-Log -Component 'Browser' -EventType 'Launch' -Severity 'Information' -Message ("Chrome instance {0} launched for {1}." -f ($index + 1), $url) -Data @{
				Url = $url
				Result = 'Success'
				Duration = $result.DurationMs
				ProcessId = $result.ProcessId
			}
		}
		catch {
			$failure = [ordered]@{
				Success = $false
				Url = $url
				ProcessId = $null
				DurationMs = 0
				ErrorReason = $_.Exception.Message
			}
			$launchResults += $failure
			$script:RunState.ChromeLaunches += $failure

			Write-Log -Component 'Browser' -EventType 'Launch' -Severity 'Error' -Message ("Chrome instance {0} failed for {1}." -f ($index + 1), $url) -Data @{
				Url = $url
				Result = 'Failed'
				ErrorMessage = $_.Exception.Message
			}
		}

		if ($index -lt ($BrowserConfig.Urls.Count - 1)) {
			Start-Sleep -Milliseconds $BrowserConfig.LaunchDelayMs
		}
	}

	$successfulLaunches = @($launchResults | Where-Object { $_.Success }).Count
	if ($BrowserConfig.RequireSuccessfulLaunch -and $successfulLaunches -ne $BrowserConfig.LaunchCount) {
		throw "Chrome launch preconditions failed. Expected $($BrowserConfig.LaunchCount) successful launches but observed $successfulLaunches."
	}

	return $launchResults
}

function Resolve-PremiereExecutablePath {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$PremiereConfig
	)

	return Resolve-ExecutablePath -ConfiguredPath $PremiereConfig.ExecutablePath -CandidatePaths @(
		'C:\Program Files\Adobe\Adobe Premiere Pro 2025\Adobe Premiere Pro.exe',
		'C:\Program Files\Adobe\Adobe Premiere Pro 2024\Adobe Premiere Pro.exe',
		'C:\Program Files\Adobe\Adobe Premiere Pro 2023\Adobe Premiere Pro.exe'
	)
}

function Get-ConfiguredPremiereProcessNames {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$PremiereConfig
	)

	$names = @()
	if ($PremiereConfig['ProcessNames']) {
		$names += @($PremiereConfig.ProcessNames)
	}
	if ($PremiereConfig['ProcessName']) {
		$names += $PremiereConfig.ProcessName
	}

	$filteredNames = @()
	foreach ($name in $names) {
		if (($null -ne $name) -and ($name -notmatch '^\s*$') -and ($filteredNames -notcontains $name)) {
			$filteredNames += $name
		}
	}

	return $filteredNames
}

function Get-PremiereProjectName {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$PremiereConfig
	)

	if (($null -eq $PremiereConfig.ProjectPath) -or ($PremiereConfig.ProjectPath -match '^\s*$')) {
		return ''
	}

	$leafName = Split-Path -Path $PremiereConfig.ProjectPath -Leaf
	if (($null -eq $leafName) -or ($leafName -match '^\s*$')) {
		return ''
	}

	return ($leafName -replace '\.[^\.]+$','')
}

function Test-ProjectPathConfiguration {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$PremiereConfig,

		[bool]$SimulationOnly = $false
	)

	if (($null -eq $PremiereConfig.ProjectPath) -or ($PremiereConfig.ProjectPath -match '^\s*$')) {
		throw 'Premiere.ProjectPath must be configured before execution.'
	}

	if (-not $SimulationOnly -and -not (Test-Path -LiteralPath $PremiereConfig.ProjectPath)) {
		throw "Premiere project path '$($PremiereConfig.ProjectPath)' does not exist."
	}
}

function Start-PremiereSession {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$PremiereConfig,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	Test-ProjectPathConfiguration -PremiereConfig $PremiereConfig -SimulationOnly $SimulationOnly

	if ($SimulationOnly) {
		Write-Log -Component 'Premiere' -EventType 'Launch' -Severity 'Information' -Message 'Dry-run mode enabled; Premiere launch skipped.' -Data @{
			ProjectPath = $PremiereConfig.ProjectPath
			Result = 'Simulated'
		}

		return [ordered]@{
			Id = $null
			ProcessName = $PremiereConfig.ProcessName
			MainWindowHandle = 0
			MainWindowTitle = 'DryRun Premiere Window'
		}
	}

	$resolvedExecutable = Resolve-PremiereExecutablePath -PremiereConfig $PremiereConfig
	$process = $null
	$launchMode = 'FileAssociation'

	if ($PremiereConfig.UseFileAssociation) {
		$process = Start-Process -FilePath $PremiereConfig.ProjectPath -PassThru
	}
	else {
		if (-not $resolvedExecutable) {
			throw 'Premiere executable could not be resolved.'
		}

		$argumentList = @($PremiereConfig.Arguments)
		$argumentList += $PremiereConfig.ProjectPath
		$process = Start-Process -FilePath $resolvedExecutable -ArgumentList $argumentList -PassThru
		$launchMode = 'ExecutablePath'
	}

	Write-Log -Component 'Premiere' -EventType 'Launch' -Severity 'Information' -Message 'Premiere launch requested.' -Data @{
		ProcessId = $process.Id
		ProjectPath = $PremiereConfig.ProjectPath
		LaunchMode = $launchMode
		ExecutablePath = $resolvedExecutable
	}

	return $process
}

function Test-PremiereRunning {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$PremiereConfig
	)

	$processNames = Get-ConfiguredPremiereProcessNames -PremiereConfig $PremiereConfig
	foreach ($processName in $processNames) {
		$processes = @(Get-Process -Name $processName -ErrorAction SilentlyContinue)
		if ($processes.Count -gt 0) {
			return $true
		}
	}

	return $false
}

function Get-PremiereProcess {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$PremiereConfig
	)

	$processes = @()
	$processNames = Get-ConfiguredPremiereProcessNames -PremiereConfig $PremiereConfig
	foreach ($processName in $processNames) {
		$processes += @(Get-Process -Name $processName -ErrorAction SilentlyContinue)
	}
	if (-not $processes) {
		return $null
	}

	$projectName = Get-PremiereProjectName -PremiereConfig $PremiereConfig
	$windowedProcesses = @()
	foreach ($process in $processes) {
		try {
			$currentProcess = $process
			if (-not (Test-DesktopAutomationAvailable)) {
				$currentProcess = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
			}
			else {
				$process.Refresh()
			}

			if (($null -ne $currentProcess) -and ($currentProcess.MainWindowHandle -ne 0)) {
				$windowedProcesses += $currentProcess
			}
		}
		catch {
		}
	}

	$matchingProcesses = @()
	foreach ($process in $windowedProcesses) {
		if ($process.MainWindowTitle -match $PremiereConfig.WindowTitleRegex) {
			$matchingProcesses += $process
		}
	}

	if ($projectName) {
		foreach ($process in $matchingProcesses) {
			if ($process.MainWindowTitle -match [regex]::Escape($projectName)) {
				return $process
			}
		}
	}

	if ($matchingProcesses.Count -gt 0) {
		return ($matchingProcesses | Sort-Object -Property StartTime -Descending | Select-Object -First 1)
	}

	if ($windowedProcesses.Count -gt 0) {
		return ($windowedProcesses | Sort-Object -Property StartTime -Descending | Select-Object -First 1)
	}

	return ($processes | Sort-Object -Property StartTime -Descending | Select-Object -First 1)
}

function Get-PremiereReadinessSnapshot {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$PremiereConfig,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	if ($SimulationOnly) {
		return [ordered]@{
			Running = $true
			WindowFound = $true
			WindowVisible = $true
			ProjectLoaded = $true
			BlockingDialogDetected = $false
			WindowTitle = 'DryRun Premiere Window'
			ProcessId = 0
			Reason = 'Ready'
		}
	}

	$window = Get-PremiereWindow -PremiereConfig $PremiereConfig -SimulationOnly $SimulationOnly
	$running = Test-PremiereRunning -PremiereConfig $PremiereConfig
	$windowFound = $null -ne $window
	$windowVisible = $windowFound -and [bool]$window.Visible
	$blockingDialogDetected = $false
	$projectLoaded = $false
	$reason = ''

	if (-not $running) {
		$reason = 'ProcessNotRunning'
	}
	elseif (-not $windowFound) {
		$reason = 'WindowNotFound'
	}
	elseif (-not $windowVisible) {
		$reason = 'WindowNotVisible'
	}
	else {
		$blockingDialogDetected = Test-BlockingPremiereDialog -PremiereWindow $window -SimulationOnly $SimulationOnly
		if ($blockingDialogDetected) {
			$reason = 'BlockingDialogDetected'
		}
		else {
			$projectLoaded = Test-ProjectLoaded -PremiereConfig $PremiereConfig -PremiereWindow $window -SimulationOnly $SimulationOnly
			if ($projectLoaded) {
				$reason = 'Ready'
			}
			else {
				$reason = 'ProjectNotConfirmed'
			}
		}
	}

	return [ordered]@{
		Running = $running
		WindowFound = $windowFound
		WindowVisible = $windowVisible
		ProjectLoaded = $projectLoaded
		BlockingDialogDetected = $blockingDialogDetected
		WindowTitle = if ($windowFound) { $window.Title } else { '' }
		ProcessId = if ($windowFound) { $window.Process.Id } else { $null }
		Reason = $reason
	}
}

function Get-PremiereWindow {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$PremiereConfig,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	if ($SimulationOnly) {
		return [ordered]@{
			Handle = 0
			Title = 'DryRun Premiere Window'
			Process = [ordered]@{ Id = 0; ProcessName = $PremiereConfig.ProcessName }
			Visible = $true
		}
	}

	$process = Get-PremiereProcess -PremiereConfig $PremiereConfig
	if (-not $process) {
		return $null
	}

	if (-not (Test-DesktopAutomationAvailable)) {
		$process = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
		if (-not $process) {
			return $null
		}
	}
	else {
		$process.Refresh()
	}

	if ($process.MainWindowHandle -eq 0) {
		return $null
	}

	if (-not (Test-DesktopAutomationAvailable)) {
		return [ordered]@{
			Handle = $process.MainWindowHandle
			Title = $process.MainWindowTitle
			Process = $process
			Visible = $true
		}
	}

	return [ordered]@{
		Handle = [IntPtr]$process.MainWindowHandle
		Title = $process.MainWindowTitle
		Process = $process
		Visible = [WorkflowAutomation.NativeMethods]::IsWindowVisible([IntPtr]$process.MainWindowHandle)
	}
}

function Test-BlockingPremiereDialog {
	param(
		[Parameter(Mandatory = $true)]
		[psobject]$PremiereWindow,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	if ($SimulationOnly) {
		return $false
	}

	if (-not (Test-DesktopAutomationAvailable)) {
		return $false
	}

	$foregroundHandle = [WorkflowAutomation.NativeMethods]::GetForegroundWindow()
	if ($foregroundHandle -eq [IntPtr]::Zero) {
		return $false
	}

	[uint32]$foregroundProcessId = 0
	[void][WorkflowAutomation.NativeMethods]::GetWindowThreadProcessId($foregroundHandle, [ref]$foregroundProcessId)

	return ($foregroundProcessId -eq $PremiereWindow.Process.Id) -and ($foregroundHandle -ne $PremiereWindow.Handle)
}

function Test-ProjectLoaded {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$PremiereConfig,

		[Parameter(Mandatory = $true)]
		[psobject]$PremiereWindow,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	if ($SimulationOnly) {
		return $true
	}

	$projectName = Get-PremiereProjectName -PremiereConfig $PremiereConfig
	if (($null -eq $projectName) -or ($projectName -match '^\s*$')) {
		return $false
	}

	return $PremiereWindow.Title -match [regex]::Escape($projectName)
}

function Wait-PremiereWindowReady {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$PremiereConfig,

		[Parameter(Mandatory = $true)]
		[int]$ReadyTimeoutSec,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	$deadline = (Get-Date).AddSeconds($ReadyTimeoutSec)
	$attempt = 0
	do {
		$attempt++
		$snapshot = Get-PremiereReadinessSnapshot -PremiereConfig $PremiereConfig -SimulationOnly $SimulationOnly
		if ($snapshot.Reason -eq 'Ready') {
				if ($PremiereConfig.InitialLoadDelayMs -gt 0) {
					Write-Log -Component 'Premiere' -EventType 'Settling' -Severity 'Information' -Message 'Premiere is ready; waiting for the configured post-ready settle delay before starting workflow actions.' -Data @{
						DelayMs = $PremiereConfig.InitialLoadDelayMs
						WindowTitle = $snapshot.WindowTitle
						ProcessId = $snapshot.ProcessId
					}
				}
			Start-Sleep -Milliseconds $PremiereConfig.InitialLoadDelayMs
			$window = Get-PremiereWindow -PremiereConfig $PremiereConfig -SimulationOnly $SimulationOnly
			Write-Log -Component 'Premiere' -EventType 'Ready' -Severity 'Information' -Message 'Premiere window readiness checks passed.' -Data @{
				WindowTitle = $snapshot.WindowTitle
				ProcessId = $snapshot.ProcessId
				Attempts = $attempt
			}
			return $window
		}

		Write-Log -Component 'Premiere' -EventType 'Waiting' -Severity 'Debug' -Message 'Premiere is not ready yet.' -Data @{
			Attempt = $attempt
			Reason = $snapshot.Reason
			WindowTitle = $snapshot.WindowTitle
			ProcessId = $snapshot.ProcessId
			Running = $snapshot.Running
			WindowFound = $snapshot.WindowFound
			WindowVisible = $snapshot.WindowVisible
			ProjectLoaded = $snapshot.ProjectLoaded
			BlockingDialogDetected = $snapshot.BlockingDialogDetected
		}

		Start-Sleep -Milliseconds 500
	}
	while ((Get-Date) -lt $deadline)

	$finalSnapshot = Get-PremiereReadinessSnapshot -PremiereConfig $PremiereConfig -SimulationOnly $SimulationOnly
	throw ("Premiere did not become ready before the configured timeout elapsed. LastReason={0}; WindowTitle='{1}'; ProcessId={2}." -f $finalSnapshot.Reason, $finalSnapshot.WindowTitle, $finalSnapshot.ProcessId)
}

function Get-ProcessElevationState {
	param(
		[Parameter(Mandatory = $true)]
		[System.Diagnostics.Process]$Process
	)

	$tokenHandle = [IntPtr]::Zero
	if (-not [WorkflowAutomation.NativeMethods]::OpenProcessToken($Process.Handle, [WorkflowAutomation.NativeMethods]::TOKEN_QUERY, [ref]$tokenHandle)) {
		throw "Could not query token information for process $($Process.Id)."
	}

	try {
		$tokenElevation = New-Object WorkflowAutomation.NativeMethods+TOKEN_ELEVATION
		$returnLength = 0
		$success = [WorkflowAutomation.NativeMethods]::GetTokenInformation(
			$tokenHandle,
			[WorkflowAutomation.NativeMethods]::TokenElevation,
			[ref]$tokenElevation,
			[System.Runtime.InteropServices.Marshal]::SizeOf($tokenElevation),
			[ref]$returnLength
		)

		if (-not $success) {
			throw "Could not read token elevation for process $($Process.Id)."
		}

		return ($tokenElevation.TokenIsElevated -eq 1)
	}
	finally {
		if ($tokenHandle -ne [IntPtr]::Zero) {
			[void][WorkflowAutomation.NativeMethods]::CloseHandle($tokenHandle)
		}
	}
}

function Test-SameIntegrityLevel {
	param(
		[Parameter(Mandatory = $true)]
		[System.Diagnostics.Process]$PremiereProcess,

		[Parameter(Mandatory = $true)]
		[object[]]$ChromeLaunches,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	if ($SimulationOnly) {
		return $true
	}

	if (-not (Test-DesktopAutomationAvailable)) {
		Write-Log -Component 'Focus' -EventType 'IntegrityCheckSkipped' -Severity 'Warning' -Message 'Integrity verification skipped because desktop automation is not available in the current PowerShell language mode.'
		return $true
	}

	$currentProcess = Get-Process -Id $PID
	$currentElevation = Get-ProcessElevationState -Process $currentProcess
	$premiereElevation = Get-ProcessElevationState -Process $PremiereProcess
	$checkedChromeProcesses = 0
	$foundChromeProcesses = 0
	if ($currentElevation -ne $premiereElevation) {
		return $false
	}

	foreach ($launch in $ChromeLaunches) {
		if ($launch.Success -and $launch.ProcessId) {
			$checkedChromeProcesses++
			$chromeProcess = Get-Process -Id $launch.ProcessId -ErrorAction SilentlyContinue
			if ($chromeProcess) {
				$foundChromeProcesses++
				$chromeElevation = Get-ProcessElevationState -Process $chromeProcess
				if ($chromeElevation -ne $currentElevation) {
					return $false
				}
			}
			else {
				Write-Log -Component 'Focus' -EventType 'IntegrityWarning' -Severity 'Warning' -Message 'Chrome process could not be found during integrity verification.' -Data @{
					ProcessId = $launch.ProcessId
					ChromeProcessesChecked = $checkedChromeProcesses
					ChromeProcessesFound = $foundChromeProcesses
				}
			}
		}
	}

	Write-Log -Component 'Focus' -EventType 'IntegrityCheck' -Severity 'Information' -Message 'Integrity verification completed.' -Data @{
		ChromeProcessesChecked = $checkedChromeProcesses
		ChromeProcessesFound = $foundChromeProcesses
	}

	return $true
}

function Test-PremiereFocused {
	param(
		[Parameter(Mandatory = $true)]
		[psobject]$PremiereWindow,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	if ($SimulationOnly) {
		return $true
	}

	if (-not (Test-DesktopAutomationAvailable)) {
		return $true
	}

	$foregroundHandle = [WorkflowAutomation.NativeMethods]::GetForegroundWindow()
	if ($foregroundHandle -eq $PremiereWindow.Handle) {
		return $true
	}

	if ($foregroundHandle -eq [IntPtr]::Zero) {
		return $false
	}

	[uint32]$foregroundProcessId = 0
	[void][WorkflowAutomation.NativeMethods]::GetWindowThreadProcessId($foregroundHandle, [ref]$foregroundProcessId)
	return $foregroundProcessId -eq $PremiereWindow.Process.Id
}

function Invoke-AppActivateFocus {
	param(
		[Parameter(Mandatory = $true)]
		[psobject]$PremiereWindow
	)

	if (-not $script:AppActivator) {
		return $false
	}

	try {
		if ($PremiereWindow.Process.Id) {
			if ($script:AppActivator.AppActivate([int]$PremiereWindow.Process.Id)) {
				return $true
			}
		}

		if ($PremiereWindow.Title) {
			return [bool]$script:AppActivator.AppActivate([string]$PremiereWindow.Title)
		}
	}
	catch {
		return $false
	}

	return $false
}

function Set-PremiereWindowFocus {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$PremiereConfig,

		[Parameter(Mandatory = $true)]
		[hashtable]$FocusConfig,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	for ($attempt = 1; $attempt -le $FocusConfig.RetryCount; $attempt++) {
		Write-Log -Component 'Focus' -EventType 'Attempt' -Severity 'Debug' -Message 'Attempting to focus Premiere.' -Data @{ Attempt = $attempt }
		$window = Get-PremiereWindow -PremiereConfig $PremiereConfig -SimulationOnly $SimulationOnly
		if (-not $window) {
			Write-Log -Component 'Focus' -EventType 'MissingWindow' -Severity 'Warning' -Message 'Premiere window was not available during focus attempt.' -Data @{ Attempt = $attempt }
			Start-Sleep -Milliseconds $FocusConfig.RetryDelayMs
			continue
		}

		if ($SimulationOnly) {
			Write-Log -Component 'Focus' -EventType 'Acquire' -Severity 'Information' -Message 'Dry-run mode enabled; focus check simulated as successful.' -Data @{ RetryCount = ($attempt - 1) }
			return $window
		}

		if (-not (Test-DesktopAutomationAvailable)) {
			Write-Log -Component 'Focus' -EventType 'Acquire' -Severity 'Warning' -Message 'Constrained live mode enabled; focus automation skipped and treated as successful.' -Data @{ RetryCount = ($attempt - 1) }
			return $window
		}

		[void][WorkflowAutomation.NativeMethods]::ShowWindowAsync($window.Handle, [WorkflowAutomation.NativeMethods]::SW_RESTORE)
		[void][WorkflowAutomation.NativeMethods]::SetForegroundWindow($window.Handle)

		try {
			$element = [System.Windows.Automation.AutomationElement]::FromHandle($window.Handle)
			if ($element) {
				$element.SetFocus()
			}
		}
		catch {
		}

		Start-Sleep -Milliseconds $FocusConfig.VerifyDelayMs
		if (Test-PremiereFocused -PremiereWindow $window -SimulationOnly $SimulationOnly) {
			Write-Log -Component 'Focus' -EventType 'Acquire' -Severity 'Information' -Message 'Premiere focus acquired.' -Data @{ RetryCount = ($attempt - 1) }
			return $window
		}

		if (Invoke-AppActivateFocus -PremiereWindow $window) {
			Write-Log -Component 'Focus' -EventType 'AppActivateFallback' -Severity 'Debug' -Message 'AppActivate fallback invoked for Premiere.' -Data @{ Attempt = $attempt; ProcessId = $window.Process.Id; WindowTitle = $window.Title }
			Start-Sleep -Milliseconds $FocusConfig.VerifyDelayMs
			if (Test-PremiereFocused -PremiereWindow $window -SimulationOnly $SimulationOnly) {
				Write-Log -Component 'Focus' -EventType 'Acquire' -Severity 'Information' -Message 'Premiere focus acquired through AppActivate fallback.' -Data @{ RetryCount = ($attempt - 1) }
				return $window
			}
		}

		Write-Log -Component 'Focus' -EventType 'Retry' -Severity 'Warning' -Message ("Premiere focus attempt {0} failed." -f $attempt) -Data @{ RetryCount = $attempt }
		Start-Sleep -Milliseconds $FocusConfig.RetryDelayMs
	}

	throw 'Premiere focus could not be acquired within the configured retry budget.'
}

function Get-JitterDelay {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$TimingConfig,

		[Parameter(Mandatory = $true)]
		[string]$ProfileName
	)

	$timingProfile = $TimingConfig[$ProfileName]
	if ($null -eq $timingProfile) {
		throw "Unknown jitter profile '$ProfileName'."
	}
	return Get-Random -Minimum $timingProfile.MinMs -Maximum ($timingProfile.MaxMs + 1)
}

function New-TelemetryCollectorState {
	param(
		[Parameter(Mandatory = $true)]
		[string]$ActionName,

		[Parameter(Mandatory = $true)]
		[int]$FailureWarningLimitPerAction,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly,

		[hashtable]$State = @{}
	)

	$collector = [ordered]@{
		ActionName = $ActionName
		Samples = @()
		DryRun = $SimulationOnly
		FailureCount = 0
		FailureWarningsLogged = 0
		FailureWarningLimitPerAction = $FailureWarningLimitPerAction
		FirstFailureMessage = ''
	}

	foreach ($key in $State.Keys) {
		$collector[$key] = $State[$key]
	}

	return $collector
}

function Write-TelemetryFailureWarning {
	param(
		[Parameter(Mandatory = $true)]
		[System.Collections.IDictionary]$TelemetryCollector,

		[Parameter(Mandatory = $true)]
		[string]$EventType,

		[Parameter(Mandatory = $true)]
		[string]$Message,

		[Parameter(Mandatory = $true)]
		[string]$ErrorMessage,

		[hashtable]$Data = @{}
	)

	$TelemetryCollector.FailureCount++
	if (($TelemetryCollector.FirstFailureMessage -eq '') -and ($ErrorMessage -ne '')) {
		$TelemetryCollector.FirstFailureMessage = $ErrorMessage
	}

	if ($TelemetryCollector.FailureWarningsLogged -ge $TelemetryCollector.FailureWarningLimitPerAction) {
		return
	}

	$payload = @{ ActionName = $TelemetryCollector.ActionName; ErrorMessage = $ErrorMessage }
	foreach ($key in $Data.Keys) {
		$payload[$key] = $Data[$key]
	}

	Write-Log -Component 'Telemetry' -EventType $EventType -Severity 'Warning' -Message $Message -Data $payload
	$TelemetryCollector.FailureWarningsLogged++
}

function New-ActionTelemetrySession {
	param(
		[Parameter(Mandatory = $true)]
		[string]$ActionName,

		[Parameter(Mandatory = $true)]
		[hashtable]$TelemetryConfig,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	$failureWarningLimit = [int]$TelemetryConfig.FailureWarningLimitPerAction
	$simulatedMemoryTotalMb = 32768

	return [ordered]@{
		ActionName = $ActionName
		IntervalMs = [double]$TelemetryConfig.TelemetrySampleIntervalSec * 1000
		SampleOnStart = [bool]$TelemetryConfig.SampleOnStart
		UseBackgroundSampler = ((-not $SimulationOnly) -and (-not (Test-IsConstrainedLanguageMode)))
		LastSampleAt = $null
		SampleInProgress = $false
		StartedAt = Get-Date
		Ping = New-TelemetryCollectorState -ActionName $ActionName -FailureWarningLimitPerAction $failureWarningLimit -SimulationOnly $SimulationOnly -State @{
			Target = $TelemetryConfig.PingTarget
			TimeoutMs = $TelemetryConfig.PingTimeoutMs
		}
		SystemLoad = New-TelemetryCollectorState -ActionName $ActionName -FailureWarningLimitPerAction $failureWarningLimit -SimulationOnly $SimulationOnly -State @{
			SimulatedTotalMemoryMB = $simulatedMemoryTotalMb
		}
		Network = New-TelemetryCollectorState -ActionName $ActionName -FailureWarningLimitPerAction $failureWarningLimit -SimulationOnly $SimulationOnly -State @{
			PreferredAdapterName = $TelemetryConfig.NetworkAdapterName
			AdapterName = $null
			AdapterDescription = $null
			PreviousSentBytes = $null
			PreviousReceivedBytes = $null
			PreviousSampleAt = $null
		}
		TelemetryTimer = $null
		TelemetryTimerSubscription = $null
		TelemetryTimerSourceId = $null
	}
}

function Add-PingSample {
	param(
		[Parameter(Mandatory = $true)]
		[System.Collections.IDictionary]$TelemetrySession,

		[Parameter(Mandatory = $true)]
		[datetime]$SampleTimestamp
	)

	if ($TelemetrySession.DryRun) {
		$latency = Get-Random -Minimum 12 -Maximum 45
		$sample = [ordered]@{
			Timestamp = (Get-Date -Date $sampleTimestamp -Format o)
			Success = $true
			LatencyMs = $latency
			Error = $null
		}
		$TelemetrySession.Samples += $sample
		return $sample
	}

	try {
		if (Test-IsWindows) {
			$sample = Invoke-NativePingSample -TelemetrySession $TelemetrySession -SampleTimestamp $sampleTimestamp
		}
		elseif ($PSVersionTable.PSVersion.Major -ge 6) {
			$reply = Test-Connection -TargetName $TelemetrySession.Target -Count 1 -TimeoutMilliseconds $TelemetrySession.TimeoutMs -ErrorAction Stop
			$sample = [ordered]@{
				Timestamp = (Get-Date -Date $sampleTimestamp -Format o)
				Success = $true
				LatencyMs = [double]($reply | Select-Object -First 1 -ExpandProperty Latency)
				Error = $null
			}
		}
		else {
			$reply = Test-Connection -ComputerName $TelemetrySession.Target -Count 1 -ErrorAction Stop
			$sample = [ordered]@{
				Timestamp = (Get-Date -Date $sampleTimestamp -Format o)
				Success = $true
				LatencyMs = [double]($reply | Select-Object -First 1 -ExpandProperty ResponseTime)
				Error = $null
			}
		}
	}
	catch {
		$sample = [ordered]@{
			Timestamp = (Get-Date -Date $sampleTimestamp -Format o)
			Success = $false
			LatencyMs = $null
			Error = $_.Exception.Message
		}
	}

	$TelemetrySession.Samples += $sample

	if (-not $sample.Success) {
		Write-TelemetryFailureWarning -TelemetryCollector $TelemetrySession -EventType 'PingFailure' -Message ("Ping sample failed for action '{0}'. Additional failures for this action will be summarized only." -f $TelemetrySession.ActionName) -ErrorMessage ([string]$sample.Error) -Data @{ PingTarget = $TelemetrySession.Target }
	}

	return $sample
}

function Add-SystemLoadSample {
	param(
		[Parameter(Mandatory = $true)]
		[System.Collections.IDictionary]$TelemetrySession,

		[Parameter(Mandatory = $true)]
		[datetime]$SampleTimestamp
	)

	if ($TelemetrySession.DryRun) {
		$cpuUsagePercent = Get-Random -Minimum 8 -Maximum 72
		$memoryUsedPercent = Get-Random -Minimum 28 -Maximum 82
		$memoryTotalMb = [double]$TelemetrySession.SimulatedTotalMemoryMB
		$memoryUsedMb = ($memoryTotalMb * $memoryUsedPercent) / 100
		$sample = [ordered]@{
			Timestamp = (Get-Date -Date $SampleTimestamp -Format o)
			Success = $true
			CpuUsagePercent = [double]$cpuUsagePercent
			MemoryUsedPercent = [double]$memoryUsedPercent
			MemoryUsedMB = [double]$memoryUsedMb
			MemoryAvailableMB = [double]($memoryTotalMb - $memoryUsedMb)
			MemoryTotalMB = $memoryTotalMb
			Error = $null
		}
		$TelemetrySession.Samples += $sample
		return $sample
	}

	try {
		$cpuSnapshot = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction Stop | Select-Object -First 1
		$memorySnapshot = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
		$totalMemoryKb = [double]$memorySnapshot.TotalVisibleMemorySize
		$freeMemoryKb = [double]$memorySnapshot.FreePhysicalMemory
		$usedMemoryKb = $totalMemoryKb - $freeMemoryKb
		$memoryUsedPercent = $null
		if ($totalMemoryKb -gt 0) {
			$memoryUsedPercent = ($usedMemoryKb / $totalMemoryKb) * 100
		}

		$sample = [ordered]@{
			Timestamp = (Get-Date -Date $SampleTimestamp -Format o)
			Success = $true
			CpuUsagePercent = [double]$cpuSnapshot.PercentProcessorTime
			MemoryUsedPercent = $memoryUsedPercent
			MemoryUsedMB = $usedMemoryKb / 1024
			MemoryAvailableMB = $freeMemoryKb / 1024
			MemoryTotalMB = $totalMemoryKb / 1024
			Error = $null
		}
	}
	catch {
		$sample = [ordered]@{
			Timestamp = (Get-Date -Date $SampleTimestamp -Format o)
			Success = $false
			CpuUsagePercent = $null
			MemoryUsedPercent = $null
			MemoryUsedMB = $null
			MemoryAvailableMB = $null
			MemoryTotalMB = $null
			Error = $_.Exception.Message
		}
	}

	$TelemetrySession.Samples += $sample
	if (-not $sample.Success) {
		Write-TelemetryFailureWarning -TelemetryCollector $TelemetrySession -EventType 'SystemLoadFailure' -Message ("System load sample failed for action '{0}'. Additional failures for this action will be summarized only." -f $TelemetrySession.ActionName) -ErrorMessage ([string]$sample.Error)
	}

	return $sample
}

function Resolve-NetworkThroughputAdapter {
	param(
		[string]$PreferredAdapterName = ''
	)

	if ($PreferredAdapterName) {
		$preferredAdapter = @(Get-NetAdapter -Name $PreferredAdapterName -ErrorAction Stop | Select-Object -First 1)
		if ($preferredAdapter.Count -gt 0) {
			return $preferredAdapter[0]
		}
	}

	$adapters = @(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object { $_.Status -eq 'Up' } | Sort-Object ifIndex)
	if (-not $adapters) {
		$adapters = @(Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Status -eq 'Up' } | Sort-Object ifIndex)
	}

	$ethernetAdapters = @($adapters | Where-Object { ($_.Name -match 'Ethernet') -or ($_.InterfaceDescription -match 'Ethernet') })
	if ($ethernetAdapters.Count -gt 0) {
		return $ethernetAdapters[0]
	}

	if ($adapters.Count -gt 0) {
		return $adapters[0]
	}

	throw 'No active network adapter could be selected for throughput telemetry.'
}

function Add-NetworkThroughputSample {
	param(
		[Parameter(Mandatory = $true)]
		[System.Collections.IDictionary]$TelemetrySession,

		[Parameter(Mandatory = $true)]
		[datetime]$SampleTimestamp
	)

	if ($TelemetrySession.DryRun) {
		$receivedBytesPerSec = Get-Random -Minimum 250000 -Maximum 6000000
		$sentBytesPerSec = Get-Random -Minimum 125000 -Maximum 3000000
		$sample = [ordered]@{
			Timestamp = (Get-Date -Date $SampleTimestamp -Format o)
			Success = $true
			IsBaseline = $false
			AdapterName = if ($TelemetrySession.AdapterName) { $TelemetrySession.AdapterName } else { 'SimulatedEthernet' }
			AdapterDescription = if ($TelemetrySession.AdapterDescription) { $TelemetrySession.AdapterDescription } else { 'Simulated ethernet adapter' }
			BytesReceived = [double]$receivedBytesPerSec
			BytesSent = [double]$sentBytesPerSec
			BytesTotal = [double]($receivedBytesPerSec + $sentBytesPerSec)
			BytesReceivedPerSec = [double]$receivedBytesPerSec
			BytesSentPerSec = [double]$sentBytesPerSec
			BytesTotalPerSec = [double]($receivedBytesPerSec + $sentBytesPerSec)
			SampleIntervalSec = 1
			Error = $null
		}
		$TelemetrySession.Samples += $sample
		return $sample
	}

	try {
		if (-not $TelemetrySession.AdapterName) {
			$adapter = Resolve-NetworkThroughputAdapter -PreferredAdapterName $TelemetrySession.PreferredAdapterName
			$TelemetrySession.AdapterName = $adapter.Name
			$TelemetrySession.AdapterDescription = $adapter.InterfaceDescription
		}

		$statistics = Get-NetAdapterStatistics -Name $TelemetrySession.AdapterName -ErrorAction Stop
		$currentReceivedBytes = [double]$statistics.ReceivedBytes
		$currentSentBytes = [double]$statistics.SentBytes
		$sample = [ordered]@{
			Timestamp = (Get-Date -Date $SampleTimestamp -Format o)
			Success = $true
			IsBaseline = $false
			AdapterName = $TelemetrySession.AdapterName
			AdapterDescription = $TelemetrySession.AdapterDescription
			BytesReceived = $currentReceivedBytes
			BytesSent = $currentSentBytes
			BytesTotal = ($currentReceivedBytes + $currentSentBytes)
			BytesReceivedPerSec = $null
			BytesSentPerSec = $null
			BytesTotalPerSec = $null
			SampleIntervalSec = $null
			Error = $null
		}

		if (($null -ne $TelemetrySession.PreviousReceivedBytes) -and ($null -ne $TelemetrySession.PreviousSentBytes) -and $TelemetrySession.PreviousSampleAt) {
			$elapsedSeconds = ($SampleTimestamp - $TelemetrySession.PreviousSampleAt).TotalSeconds
			if ($elapsedSeconds -le 0) {
				$elapsedSeconds = 1
			}

			$receivedDelta = $currentReceivedBytes - [double]$TelemetrySession.PreviousReceivedBytes
			if ($receivedDelta -lt 0) {
				$receivedDelta = 0
			}

			$sentDelta = $currentSentBytes - [double]$TelemetrySession.PreviousSentBytes
			if ($sentDelta -lt 0) {
				$sentDelta = 0
			}

			$sample.BytesReceivedPerSec = ($receivedDelta / $elapsedSeconds)
			$sample.BytesSentPerSec = ($sentDelta / $elapsedSeconds)
			$sample.BytesTotalPerSec = (($receivedDelta + $sentDelta) / $elapsedSeconds)
			$sample.SampleIntervalSec = [double]$elapsedSeconds
		}
		else {
			$sample.IsBaseline = $true
		}

		$TelemetrySession.PreviousReceivedBytes = $currentReceivedBytes
		$TelemetrySession.PreviousSentBytes = $currentSentBytes
		$TelemetrySession.PreviousSampleAt = $SampleTimestamp
	}
	catch {
		$sample = [ordered]@{
			Timestamp = (Get-Date -Date $SampleTimestamp -Format o)
			Success = $false
			IsBaseline = $false
			AdapterName = $TelemetrySession.AdapterName
			AdapterDescription = $TelemetrySession.AdapterDescription
			BytesReceived = $null
			BytesSent = $null
			BytesTotal = $null
			BytesReceivedPerSec = $null
			BytesSentPerSec = $null
			BytesTotalPerSec = $null
			SampleIntervalSec = $null
			Error = $_.Exception.Message
		}
	}

	$TelemetrySession.Samples += $sample
	if (-not $sample.Success) {
		Write-TelemetryFailureWarning -TelemetryCollector $TelemetrySession -EventType 'NetworkFailure' -Message ("Network throughput sample failed for action '{0}'. Additional failures for this action will be summarized only." -f $TelemetrySession.ActionName) -ErrorMessage ([string]$sample.Error)
	}

	return $sample
}

function Add-ActionTelemetrySample {
	param(
		[Parameter(Mandatory = $true)]
		[System.Collections.IDictionary]$TelemetrySession
	)

	$sampleTimestamp = Get-Date
	[void](Add-PingSample -TelemetrySession $TelemetrySession.Ping -SampleTimestamp $sampleTimestamp)
	[void](Add-SystemLoadSample -TelemetrySession $TelemetrySession.SystemLoad -SampleTimestamp $sampleTimestamp)
	[void](Add-NetworkThroughputSample -TelemetrySession $TelemetrySession.Network -SampleTimestamp $sampleTimestamp)
	$TelemetrySession.LastSampleAt = $sampleTimestamp
}

function Start-ActionTelemetrySampler {
	param(
		[Parameter(Mandatory = $true)]
		[psobject]$TelemetrySession
	)

	if (-not $TelemetrySession.UseBackgroundSampler) {
		return
	}

	if ($TelemetrySession.TelemetryTimer) {
		return
	}

	$timerInterval = [double]$TelemetrySession.IntervalMs
	if ($timerInterval -lt 1) {
		$timerInterval = 1
	}

	$timer = New-Object System.Timers.Timer
	$timer.Interval = $timerInterval
	$timer.AutoReset = $true
	$timer.Enabled = $false

	$sourceIdentifier = 'TelemetrySampler.{0}.{1}' -f $TelemetrySession.ActionName, $TelemetrySession.StartedAt.Ticks
	$subscription = Register-ObjectEvent -InputObject $timer -EventName Elapsed -SourceIdentifier $sourceIdentifier -MessageData $TelemetrySession -Action {
		$session = $event.MessageData
		if (-not $session) {
			return
		}

		if ($session.SampleInProgress) {
			return
		}

		$session.SampleInProgress = $true
		try {
			[void](Add-ActionTelemetrySample -TelemetrySession $session)
		}
		catch {
		}
		finally {
			$session.SampleInProgress = $false
		}
	}

	$TelemetrySession.TelemetryTimer = $timer
	$TelemetrySession.TelemetryTimerSubscription = $subscription
	$TelemetrySession.TelemetryTimerSourceId = $sourceIdentifier
	$timer.Start()
}

function Stop-ActionTelemetrySampler {
	param(
		[Parameter(Mandatory = $true)]
		[psobject]$TelemetrySession
	)

	if ($TelemetrySession.TelemetryTimer) {
		try {
			$TelemetrySession.TelemetryTimer.Stop()
		}
		catch {
		}

		try {
			$TelemetrySession.TelemetryTimer.Dispose()
		}
		catch {
		}

		$TelemetrySession.TelemetryTimer = $null
	}

	if ($TelemetrySession.TelemetryTimerSourceId) {
		try {
			Unregister-Event -SourceIdentifier $TelemetrySession.TelemetryTimerSourceId -ErrorAction SilentlyContinue
		}
		catch {
		}

		if ($TelemetrySession.TelemetryTimerSubscription) {
			try {
				Remove-Job -Id $TelemetrySession.TelemetryTimerSubscription.Id -Force -ErrorAction SilentlyContinue
			}
			catch {
			}
		}

		$TelemetrySession.TelemetryTimerSourceId = $null
	}

	$TelemetrySession.TelemetryTimerSubscription = $null
}

function Start-ActionTelemetry {
	param(
		[Parameter(Mandatory = $true)]
		[string]$ActionName,

		[Parameter(Mandatory = $true)]
		[hashtable]$TelemetryConfig,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	$session = New-ActionTelemetrySession -ActionName $ActionName -TelemetryConfig $TelemetryConfig -SimulationOnly $SimulationOnly
	Write-Log -Component 'Telemetry' -EventType 'PingStart' -Severity 'Information' -Message ("Ping telemetry started for action '{0}'." -f $ActionName) -Data @{ PingTarget = $TelemetryConfig.PingTarget }
	Write-Log -Component 'Telemetry' -EventType 'SystemLoadStart' -Severity 'Information' -Message ("System load telemetry started for action '{0}'." -f $ActionName)
	Write-Log -Component 'Telemetry' -EventType 'NetworkStart' -Severity 'Information' -Message ("Network throughput telemetry started for action '{0}'." -f $ActionName) -Data @{ PreferredAdapterName = $TelemetryConfig.NetworkAdapterName }

	if ($session.SampleOnStart) {
		[void](Add-ActionTelemetrySample -TelemetrySession $session)
	}

	Start-ActionTelemetrySampler -TelemetrySession $session
	if ($session.UseBackgroundSampler) {
		Write-Log -Component 'Telemetry' -EventType 'SamplerMode' -Severity 'Information' -Message ("Background telemetry sampler enabled for action '{0}'." -f $ActionName)
	}
	else {
		Write-Log -Component 'Telemetry' -EventType 'SamplerMode' -Severity 'Information' -Message ("Cooperative telemetry sampler enabled for action '{0}'." -f $ActionName)
	}

	return $session
}

function Get-NumericStatistics {
	param(
		[object[]]$Values
	)

	$numericValues = @($Values | Where-Object { $null -ne $_ } | ForEach-Object { [double]$_ } | Sort-Object)
	if (-not $numericValues) {
		return @{
			SampleCount = 0
			Lowest = $null
			Highest = $null
			Median = $null
			Average = $null
			HasData = $false
		}
	}

	$median = 0
	if ($numericValues.Count % 2 -eq 1) {
		$median = $numericValues[[int]($numericValues.Count / 2)]
	}
	else {
		$upperIndex = [int]($numericValues.Count / 2)
		$lowerIndex = $upperIndex - 1
		$median = ($numericValues[$lowerIndex] + $numericValues[$upperIndex]) / 2
	}

	return @{
		SampleCount = $numericValues.Count
		Lowest = (($numericValues | Measure-Object -Minimum).Minimum)
		Highest = (($numericValues | Measure-Object -Maximum).Maximum)
		Median = $median
		Average = (($numericValues | Measure-Object -Average).Average)
		HasData = $true
	}
}

function New-TelemetrySummaryConsoleMessage {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Headline,

		[Parameter(Mandatory = $true)]
		[string[]]$DetailLines
	)

	$lines = @($Headline)
	foreach ($detailLine in $DetailLines) {
		if ($detailLine) {
			$lines += ('  {0}' -f $detailLine)
		}
	}

	return ($lines -join [Environment]::NewLine)
}

function Invoke-ActionTelemetryCheckpoint {
	param(
		[psobject]$TelemetrySession
	)

	if ((-not $TelemetrySession) -or $TelemetrySession.UseBackgroundSampler) {
		return
	}

	if (-not $TelemetrySession.LastSampleAt) {
		[void](Add-ActionTelemetrySample -TelemetrySession $TelemetrySession)
		return
	}

	$elapsedSinceSample = ((Get-Date) - $TelemetrySession.LastSampleAt).TotalMilliseconds
	if ($elapsedSinceSample -ge $TelemetrySession.IntervalMs) {
		[void](Add-ActionTelemetrySample -TelemetrySession $TelemetrySession)
	}
}

function Invoke-TelemetryAwareWait {
	param(
		[Parameter(Mandatory = $true)]
		[int]$DurationMs,

		[psobject]$TelemetrySession
	)

	if ($DurationMs -le 0) {
		return
	}

	$startedAt = Get-Date
	while ((Get-ElapsedMilliseconds -StartedAt $startedAt) -lt $DurationMs) {
		$remainingMs = $DurationMs - [int](Get-ElapsedMilliseconds -StartedAt $startedAt)
		$sleepMs = 100
		if ($remainingMs -lt $sleepMs) {
			$sleepMs = $remainingMs
		}
		if ($sleepMs -gt 0) {
			Start-Sleep -Milliseconds $sleepMs
		}

		Invoke-ActionTelemetryCheckpoint -TelemetrySession $TelemetrySession
	}
}

function Get-PingStatistics {
	param(
		[Parameter(Mandatory = $true)]
		[psobject]$TelemetrySession
	)

	$latencyStatistics = Get-NumericStatistics -Values @($TelemetrySession.Samples | Where-Object { $_.Success -and $null -ne $_.LatencyMs } | ForEach-Object { [double]$_.LatencyMs })
	if (-not $latencyStatistics.HasData) {
		return @{
			PingTarget = $TelemetrySession.Target
			PingSampleCount = 0
			PingLowestMs = $null
			PingHighestMs = $null
			PingMedianMs = $null
			PingAverageMs = $null
			PingTelemetryAvailable = $false
		}
	}

	return @{
		PingTarget = $TelemetrySession.Target
		PingSampleCount = $latencyStatistics.SampleCount
		PingLowestMs = $latencyStatistics.Lowest
		PingHighestMs = $latencyStatistics.Highest
		PingMedianMs = $latencyStatistics.Median
		PingAverageMs = $latencyStatistics.Average
		PingTelemetryAvailable = $true
	}
}

function Get-SystemLoadStatistics {
	param(
		[Parameter(Mandatory = $true)]
		[psobject]$TelemetrySession
	)

	$successfulSamples = @($TelemetrySession.Samples | Where-Object { $_.Success })
	if (-not $successfulSamples) {
		return @{
			SystemLoadSampleCount = 0
			CpuLowestPercent = $null
			CpuHighestPercent = $null
			CpuMedianPercent = $null
			CpuAveragePercent = $null
			MemoryUsedLowestPercent = $null
			MemoryUsedHighestPercent = $null
			MemoryUsedMedianPercent = $null
			MemoryUsedAveragePercent = $null
			MemoryUsedAverageMB = $null
			MemoryTotalMB = $null
			SystemLoadTelemetryAvailable = $false
		}
	}

	$cpuStatistics = Get-NumericStatistics -Values @($successfulSamples | ForEach-Object { $_.CpuUsagePercent })
	$memoryPercentStatistics = Get-NumericStatistics -Values @($successfulSamples | ForEach-Object { $_.MemoryUsedPercent })
	$memoryUsageMbStatistics = Get-NumericStatistics -Values @($successfulSamples | ForEach-Object { $_.MemoryUsedMB })
	$latestSuccessfulSample = $successfulSamples[-1]

	return @{
		SystemLoadSampleCount = $successfulSamples.Count
		CpuLowestPercent = $cpuStatistics.Lowest
		CpuHighestPercent = $cpuStatistics.Highest
		CpuMedianPercent = $cpuStatistics.Median
		CpuAveragePercent = $cpuStatistics.Average
		MemoryUsedLowestPercent = $memoryPercentStatistics.Lowest
		MemoryUsedHighestPercent = $memoryPercentStatistics.Highest
		MemoryUsedMedianPercent = $memoryPercentStatistics.Median
		MemoryUsedAveragePercent = $memoryPercentStatistics.Average
		MemoryUsedAverageMB = $memoryUsageMbStatistics.Average
		MemoryTotalMB = $latestSuccessfulSample.MemoryTotalMB
		SystemLoadTelemetryAvailable = $true
	}
}

function Get-NetworkThroughputStatistics {
	param(
		[Parameter(Mandatory = $true)]
		[psobject]$TelemetrySession
	)

	$throughputSamples = @($TelemetrySession.Samples | Where-Object { $_.Success -and (-not $_.IsBaseline) -and ($null -ne $_.BytesTotalPerSec) })
	if (-not $throughputSamples) {
		return @{
			NetworkSampleCount = 0
			NetworkAdapterName = $TelemetrySession.AdapterName
			NetworkAdapterDescription = $TelemetrySession.AdapterDescription
			ReceiveLowestMBPerSec = $null
			ReceiveHighestMBPerSec = $null
			ReceiveMedianMBPerSec = $null
			ReceiveAverageMBPerSec = $null
			SendLowestMBPerSec = $null
			SendHighestMBPerSec = $null
			SendMedianMBPerSec = $null
			SendAverageMBPerSec = $null
			TotalLowestMBPerSec = $null
			TotalHighestMBPerSec = $null
			TotalMedianMBPerSec = $null
			TotalAverageMBPerSec = $null
			NetworkTelemetryAvailable = $false
		}
	}

	$receiveStatistics = Get-NumericStatistics -Values @($throughputSamples | ForEach-Object { $_.BytesReceivedPerSec / 1MB })
	$sendStatistics = Get-NumericStatistics -Values @($throughputSamples | ForEach-Object { $_.BytesSentPerSec / 1MB })
	$totalStatistics = Get-NumericStatistics -Values @($throughputSamples | ForEach-Object { $_.BytesTotalPerSec / 1MB })

	return @{
		NetworkSampleCount = $throughputSamples.Count
		NetworkAdapterName = $TelemetrySession.AdapterName
		NetworkAdapterDescription = $TelemetrySession.AdapterDescription
		ReceiveLowestMBPerSec = $receiveStatistics.Lowest
		ReceiveHighestMBPerSec = $receiveStatistics.Highest
		ReceiveMedianMBPerSec = $receiveStatistics.Median
		ReceiveAverageMBPerSec = $receiveStatistics.Average
		SendLowestMBPerSec = $sendStatistics.Lowest
		SendHighestMBPerSec = $sendStatistics.Highest
		SendMedianMBPerSec = $sendStatistics.Median
		SendAverageMBPerSec = $sendStatistics.Average
		TotalLowestMBPerSec = $totalStatistics.Lowest
		TotalHighestMBPerSec = $totalStatistics.Highest
		TotalMedianMBPerSec = $totalStatistics.Median
		TotalAverageMBPerSec = $totalStatistics.Average
		NetworkTelemetryAvailable = $true
	}
}

function Write-PingSummary {
	param(
		[Parameter(Mandatory = $true)]
		[string]$ActionName,

		[Parameter(Mandatory = $true)]
		[psobject]$TelemetrySession
	)

	$stats = Get-PingStatistics -TelemetrySession $TelemetrySession
	$severity = if ($stats.PingTelemetryAvailable) { 'Information' } else { 'Warning' }

	$payload = @{}
	foreach ($key in $stats.Keys) {
		$payload[$key] = $stats[$key]
	}
	$payload.PingFailureCount = $TelemetrySession.FailureCount
	$payload.FirstFailureMessage = $TelemetrySession.FirstFailureMessage

	if ($Config.Logging.IncludePingDetail) {
		$payload.PingSamples = @($TelemetrySession.Samples)
	}

	if ($stats.PingTelemetryAvailable) {
		$message = ("Ping summary for action '{0}': target={1}; samples={2}; min={3}ms; median={4}ms; avg={5:N2}ms; max={6}ms; failures={7}." -f $ActionName, $stats.PingTarget, $stats.PingSampleCount, $stats.PingLowestMs, $stats.PingMedianMs, [double]$stats.PingAverageMs, $stats.PingHighestMs, $TelemetrySession.FailureCount)
		$consoleMessage = New-TelemetrySummaryConsoleMessage -Headline ("Ping summary for action '{0}'" -f $ActionName) -DetailLines @(
			("Target: {0}" -f $stats.PingTarget)
			("Samples: {0}" -f $stats.PingSampleCount)
			("Latency ms: min={0}; median={1:N2}; avg={2:N2}; max={3}" -f $stats.PingLowestMs, [double]$stats.PingMedianMs, [double]$stats.PingAverageMs, $stats.PingHighestMs)
			("Failures: {0}" -f $TelemetrySession.FailureCount)
		)
	}
	else {
		$message = ("Ping summary for action '{0}': target={1}; samples=0; failures={2}; telemetry unavailable." -f $ActionName, $stats.PingTarget, $TelemetrySession.FailureCount)
		$detailLines = @(
			("Target: {0}" -f $stats.PingTarget)
			'Samples: 0'
			("Failures: {0}" -f $TelemetrySession.FailureCount)
			'Telemetry unavailable.'
		)
		if ($TelemetrySession.FirstFailureMessage) {
			$message = "{0} FirstFailure='{1}'." -f $message, $TelemetrySession.FirstFailureMessage
			$detailLines += ("First failure: {0}" -f $TelemetrySession.FirstFailureMessage)
		}
		$consoleMessage = New-TelemetrySummaryConsoleMessage -Headline ("Ping summary for action '{0}'" -f $ActionName) -DetailLines $detailLines
	}

	Write-Log -Component 'Telemetry' -EventType 'PingSummary' -Severity $severity -Message $message -ConsoleMessage $consoleMessage -Data $payload
	return $stats
}

function Write-SystemLoadSummary {
	param(
		[Parameter(Mandatory = $true)]
		[string]$ActionName,

		[Parameter(Mandatory = $true)]
		[psobject]$TelemetrySession
	)

	$stats = Get-SystemLoadStatistics -TelemetrySession $TelemetrySession
	$severity = if ($stats.SystemLoadTelemetryAvailable) { 'Information' } else { 'Warning' }

	$payload = @{}
	foreach ($key in $stats.Keys) {
		$payload[$key] = $stats[$key]
	}
	$payload.SystemLoadFailureCount = $TelemetrySession.FailureCount
	$payload.FirstFailureMessage = $TelemetrySession.FirstFailureMessage

	if ($Config.Logging.IncludeSystemLoadDetail) {
		$payload.SystemLoadSamples = @($TelemetrySession.Samples)
	}

	if ($stats.SystemLoadTelemetryAvailable) {
		$message = ("System load summary for action '{0}': samples={1}; cpu min={2:N2}%; median={3:N2}%; avg={4:N2}%; max={5:N2}%; memory used min={6:N2}%; median={7:N2}%; avg={8:N2}%; max={9:N2}%; avg-used={10:N2}MB; total={11:N2}MB; failures={12}." -f $ActionName, $stats.SystemLoadSampleCount, [double]$stats.CpuLowestPercent, [double]$stats.CpuMedianPercent, [double]$stats.CpuAveragePercent, [double]$stats.CpuHighestPercent, [double]$stats.MemoryUsedLowestPercent, [double]$stats.MemoryUsedMedianPercent, [double]$stats.MemoryUsedAveragePercent, [double]$stats.MemoryUsedHighestPercent, [double]$stats.MemoryUsedAverageMB, [double]$stats.MemoryTotalMB, $TelemetrySession.FailureCount)
		$consoleMessage = New-TelemetrySummaryConsoleMessage -Headline ("System load summary for action '{0}'" -f $ActionName) -DetailLines @(
			("Samples: {0}" -f $stats.SystemLoadSampleCount)
			("CPU %: min={0:N2}; median={1:N2}; avg={2:N2}; max={3:N2}" -f [double]$stats.CpuLowestPercent, [double]$stats.CpuMedianPercent, [double]$stats.CpuAveragePercent, [double]$stats.CpuHighestPercent)
			("Memory used %: min={0:N2}; median={1:N2}; avg={2:N2}; max={3:N2}" -f [double]$stats.MemoryUsedLowestPercent, [double]$stats.MemoryUsedMedianPercent, [double]$stats.MemoryUsedAveragePercent, [double]$stats.MemoryUsedHighestPercent)
			("Memory used MB: avg={0:N2}; total={1:N2}" -f [double]$stats.MemoryUsedAverageMB, [double]$stats.MemoryTotalMB)
			("Failures: {0}" -f $TelemetrySession.FailureCount)
		)
	}
	else {
		$message = ("System load summary for action '{0}': samples=0; failures={1}; telemetry unavailable." -f $ActionName, $TelemetrySession.FailureCount)
		$detailLines = @(
			'Samples: 0'
			("Failures: {0}" -f $TelemetrySession.FailureCount)
			'Telemetry unavailable.'
		)
		if ($TelemetrySession.FirstFailureMessage) {
			$message = "{0} FirstFailure='{1}'." -f $message, $TelemetrySession.FirstFailureMessage
			$detailLines += ("First failure: {0}" -f $TelemetrySession.FirstFailureMessage)
		}
		$consoleMessage = New-TelemetrySummaryConsoleMessage -Headline ("System load summary for action '{0}'" -f $ActionName) -DetailLines $detailLines
	}

	Write-Log -Component 'Telemetry' -EventType 'SystemLoadSummary' -Severity $severity -Message $message -ConsoleMessage $consoleMessage -Data $payload
	return $stats
}

function Write-NetworkThroughputSummary {
	param(
		[Parameter(Mandatory = $true)]
		[string]$ActionName,

		[Parameter(Mandatory = $true)]
		[psobject]$TelemetrySession
	)

	$stats = Get-NetworkThroughputStatistics -TelemetrySession $TelemetrySession
	$severity = if ($stats.NetworkTelemetryAvailable) { 'Information' } else { 'Warning' }
	$adapterLabel = if ($stats.NetworkAdapterDescription) { '{0} ({1})' -f $stats.NetworkAdapterName, $stats.NetworkAdapterDescription } elseif ($stats.NetworkAdapterName) { $stats.NetworkAdapterName } else { 'Unresolved' }

	$payload = @{}
	foreach ($key in $stats.Keys) {
		$payload[$key] = $stats[$key]
	}
	$payload.NetworkFailureCount = $TelemetrySession.FailureCount
	$payload.FirstFailureMessage = $TelemetrySession.FirstFailureMessage

	if ($Config.Logging.IncludeNetworkDetail) {
		$payload.NetworkSamples = @($TelemetrySession.Samples)
	}

	if ($stats.NetworkTelemetryAvailable) {
		$message = ("Network throughput summary for action '{0}': adapter={1}; samples={2}; receive min={3:N2}MB/s; median={4:N2}MB/s; avg={5:N2}MB/s; max={6:N2}MB/s; send min={7:N2}MB/s; median={8:N2}MB/s; avg={9:N2}MB/s; max={10:N2}MB/s; total min={11:N2}MB/s; median={12:N2}MB/s; avg={13:N2}MB/s; max={14:N2}MB/s; failures={15}." -f $ActionName, $adapterLabel, $stats.NetworkSampleCount, [double]$stats.ReceiveLowestMBPerSec, [double]$stats.ReceiveMedianMBPerSec, [double]$stats.ReceiveAverageMBPerSec, [double]$stats.ReceiveHighestMBPerSec, [double]$stats.SendLowestMBPerSec, [double]$stats.SendMedianMBPerSec, [double]$stats.SendAverageMBPerSec, [double]$stats.SendHighestMBPerSec, [double]$stats.TotalLowestMBPerSec, [double]$stats.TotalMedianMBPerSec, [double]$stats.TotalAverageMBPerSec, [double]$stats.TotalHighestMBPerSec, $TelemetrySession.FailureCount)
		$consoleMessage = New-TelemetrySummaryConsoleMessage -Headline ("Network throughput summary for action '{0}'" -f $ActionName) -DetailLines @(
			("Adapter: {0}" -f $adapterLabel)
			("Samples: {0}" -f $stats.NetworkSampleCount)
			("Receive MB/s: min={0:N2}; median={1:N2}; avg={2:N2}; max={3:N2}" -f [double]$stats.ReceiveLowestMBPerSec, [double]$stats.ReceiveMedianMBPerSec, [double]$stats.ReceiveAverageMBPerSec, [double]$stats.ReceiveHighestMBPerSec)
			("Send MB/s: min={0:N2}; median={1:N2}; avg={2:N2}; max={3:N2}" -f [double]$stats.SendLowestMBPerSec, [double]$stats.SendMedianMBPerSec, [double]$stats.SendAverageMBPerSec, [double]$stats.SendHighestMBPerSec)
			("Total MB/s: min={0:N2}; median={1:N2}; avg={2:N2}; max={3:N2}" -f [double]$stats.TotalLowestMBPerSec, [double]$stats.TotalMedianMBPerSec, [double]$stats.TotalAverageMBPerSec, [double]$stats.TotalHighestMBPerSec)
			("Failures: {0}" -f $TelemetrySession.FailureCount)
		)
	}
	else {
		$message = ("Network throughput summary for action '{0}': adapter={1}; samples=0; failures={2}; telemetry unavailable." -f $ActionName, $adapterLabel, $TelemetrySession.FailureCount)
		$detailLines = @(
			("Adapter: {0}" -f $adapterLabel)
			'Samples: 0'
			("Failures: {0}" -f $TelemetrySession.FailureCount)
			'Telemetry unavailable.'
		)
		if ($TelemetrySession.FirstFailureMessage) {
			$message = "{0} FirstFailure='{1}'." -f $message, $TelemetrySession.FirstFailureMessage
			$detailLines += ("First failure: {0}" -f $TelemetrySession.FirstFailureMessage)
		}
		$consoleMessage = New-TelemetrySummaryConsoleMessage -Headline ("Network throughput summary for action '{0}'" -f $ActionName) -DetailLines $detailLines
	}

	Write-Log -Component 'Telemetry' -EventType 'NetworkSummary' -Severity $severity -Message $message -ConsoleMessage $consoleMessage -Data $payload
	return $stats
}

function Stop-ActionTelemetry {
	param(
		[Parameter(Mandatory = $true)]
		[psobject]$TelemetrySession
	)

	Stop-ActionTelemetrySampler -TelemetrySession $TelemetrySession

	return [ordered]@{
		Ping = Write-PingSummary -ActionName $TelemetrySession.ActionName -TelemetrySession $TelemetrySession.Ping
		SystemLoad = Write-SystemLoadSummary -ActionName $TelemetrySession.ActionName -TelemetrySession $TelemetrySession.SystemLoad
		Network = Write-NetworkThroughputSummary -ActionName $TelemetrySession.ActionName -TelemetrySession $TelemetrySession.Network
	}
}

function Send-HumanKeys {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Keys,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	if ($SimulationOnly) {
		Write-Log -Component 'Input' -EventType 'SendKeys' -Severity 'Information' -Message ("Dry-run: simulated key send '{0}'." -f $Keys)
		return
	}

	if ($script:RunState.ExecutionMode -eq 'ConstrainedLive') {
		Write-Log -Component 'Input' -EventType 'SendKeys' -Severity 'Warning' -Message ("Constrained live mode: key send skipped for '{0}'." -f $Keys)
		return
	}

	[System.Windows.Forms.SendKeys]::SendWait($Keys)
}

function Invoke-KeyAction {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$Action,

		[Parameter(Mandatory = $true)]
		[psobject]$TelemetrySession,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	if ($Action.PreDelayMs -gt 0) {
		Invoke-TelemetryAwareWait -DurationMs $Action.PreDelayMs -TelemetrySession $TelemetrySession
	}
	Invoke-ActionTelemetryCheckpoint -TelemetrySession $TelemetrySession
	$canInjectInput = Test-CanInjectInput

	for ($iteration = 1; $iteration -le $Action.RepeatCount; $iteration++) {
		Invoke-ActionTelemetryCheckpoint -TelemetrySession $TelemetrySession
		Send-HumanKeys -Keys $Action.Keys -SimulationOnly $SimulationOnly
		$messagePrefix = 'Sent'
		if ($SimulationOnly -or (-not $canInjectInput)) {
			$messagePrefix = 'Simulated'
		}

		Write-Log -Component 'Input' -EventType 'KeyAction' -Severity 'Information' -Message ("{0} key action '{1}' iteration {2}." -f $messagePrefix, $Action.Name, $iteration) -Data @{
			ActionName = $Action.Name
			Keys = $Action.Keys
			Iteration = $iteration
			InputInjected = [bool]$canInjectInput
		}

		if ($iteration -lt $Action.RepeatCount) {
			$repeatDelay = Get-JitterDelay -TimingConfig $Config.Timing -ProfileName $Action.JitterProfile
			Invoke-TelemetryAwareWait -DurationMs $repeatDelay -TelemetrySession $TelemetrySession
		}
	}
	Invoke-ActionTelemetryCheckpoint -TelemetrySession $TelemetrySession

	if ($Action.PostDelayMs -gt 0) {
		Invoke-TelemetryAwareWait -DurationMs $Action.PostDelayMs -TelemetrySession $TelemetrySession
	}
}

function Invoke-ActionSequence {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$Action,

		[Parameter(Mandatory = $true)]
		[psobject]$TelemetrySession,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	if ($Action.PreDelayMs -gt 0) {
		Invoke-TelemetryAwareWait -DurationMs $Action.PreDelayMs -TelemetrySession $TelemetrySession
	}
	Invoke-ActionTelemetryCheckpoint -TelemetrySession $TelemetrySession

	for ($iteration = 1; $iteration -le $Action.RepeatCount; $iteration++) {
		foreach ($childAction in $Action.Sequence) {
			Invoke-ActionTelemetryCheckpoint -TelemetrySession $TelemetrySession
			Invoke-Action -Action $childAction -TelemetrySession $TelemetrySession -SimulationOnly $SimulationOnly
		}
		Invoke-ActionTelemetryCheckpoint -TelemetrySession $TelemetrySession
	}
	Invoke-ActionTelemetryCheckpoint -TelemetrySession $TelemetrySession

	if ($Action.PostDelayMs -gt 0) {
		Invoke-TelemetryAwareWait -DurationMs $Action.PostDelayMs -TelemetrySession $TelemetrySession
	}
}

function Invoke-Action {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$Action,

		[psobject]$TelemetrySession,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	switch ($Action.Type) {
		'KeyPress' {
			Invoke-KeyAction -Action $Action -TelemetrySession $TelemetrySession -SimulationOnly $SimulationOnly
		}
		'Wait' {
			for ($iteration = 1; $iteration -le $Action.RepeatCount; $iteration++) {
				$waitDuration = $Action.DurationMs
				if ($waitDuration -le 0) {
					$waitDuration = Get-JitterDelay -TimingConfig $Config.Timing -ProfileName $Action.JitterProfile
				}
				Write-Log -Component 'Workflow' -EventType 'Wait' -Severity 'Information' -Message ("Waiting for action '{0}' iteration {1} for {2} ms." -f $Action.Name, $iteration, $waitDuration) -Data @{ ActionName = $Action.Name; Iteration = $iteration; Duration = $waitDuration }
				Invoke-TelemetryAwareWait -DurationMs $waitDuration -TelemetrySession $TelemetrySession
			}
		}
		'Burst' {
			Invoke-ActionSequence -Action $Action -TelemetrySession $TelemetrySession -SimulationOnly $SimulationOnly
		}
		default {
			throw "Unsupported action type '$($Action.Type)'."
		}
	}
}

function Invoke-WorkflowAction {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$Action,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	$startedAt = Get-Date
	$telemetrySession = Start-ActionTelemetry -ActionName $Action.Name -TelemetryConfig $Config.Telemetry -SimulationOnly $SimulationOnly
	$result = 'Passed'
	$errorMessage = ''
	$shouldAbort = $false

	try {
		if ($Action.FocusRequired) {
			$window = Set-PremiereWindowFocus -PremiereConfig $Config.Premiere -FocusConfig $Config.Focus -SimulationOnly $SimulationOnly
			if (-not (Test-PremiereFocused -PremiereWindow $window -SimulationOnly $SimulationOnly)) {
				throw 'Focus verification failed before input dispatch.'
			}
		}

		Invoke-ActionTelemetryCheckpoint -TelemetrySession $telemetrySession
		Invoke-Action -Action $Action -TelemetrySession $telemetrySession -SimulationOnly $SimulationOnly
		Invoke-ActionTelemetryCheckpoint -TelemetrySession $telemetrySession
		$jitterDelay = Get-JitterDelay -TimingConfig $Config.Timing -ProfileName $Action.JitterProfile
		Invoke-TelemetryAwareWait -DurationMs $jitterDelay -TelemetrySession $telemetrySession
		Invoke-ActionTelemetryCheckpoint -TelemetrySession $telemetrySession

		if ((-not (Test-CanInjectInput)) -and (($Action.Type -eq 'KeyPress') -or ($Action.Type -eq 'Burst'))) {
			if (($Action.Type -eq 'KeyPress') -or ($Action.Type -eq 'Burst')) {
				$result = 'Simulated'
			}
		}
	}
	catch {
		$result = 'Failed'
		$errorMessage = $_.Exception.Message
		if ($Action.AbortOnFailure) {
			$shouldAbort = $true
		}
		else {
			Write-Log -Component 'Workflow' -EventType 'ActionWarning' -Severity 'Warning' -Message ("Action '{0}' failed but execution will continue." -f $Action.Name) -Data @{ ErrorMessage = $errorMessage }
		}
	}

	$telemetrySummary = Stop-ActionTelemetry -TelemetrySession $telemetrySession
	$actionRecord = [ordered]@{
		ActionName = $Action.Name
		Result = $result
		DurationMs = (Get-ElapsedMilliseconds -StartedAt $startedAt)
		ErrorMessage = $errorMessage
		Telemetry = $telemetrySummary
	}
	$script:RunState.ActionResults += $actionRecord

	Write-ActionLog -Action $Action -Result $result -DurationMs (Get-ElapsedMilliseconds -StartedAt $startedAt) -TelemetrySummary $telemetrySummary -ErrorMessage $errorMessage
	if ($shouldAbort) {
		throw $errorMessage
	}

	return $actionRecord
}

function Stop-PremiereSession {
	param(
		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	Write-Log -Component 'Premiere' -EventType 'Stop' -Severity 'Information' -Message 'Workflow run finished. Premiere was left running for operator review.' -Data @{ SimulationOnly = $SimulationOnly }
}

function Write-RunSummary {
	param(
		[string]$StatusOverride = ''
	)

	$duration = (Get-Date) - $script:RunState.StartedAt
	$passedActions = @($script:RunState.ActionResults | Where-Object { $_.Result -eq 'Passed' }).Count
	$failedActions = @($script:RunState.ActionResults | Where-Object { $_.Result -eq 'Failed' }).Count
	$simulatedActions = @($script:RunState.ActionResults | Where-Object { $_.Result -eq 'Simulated' }).Count
	$status = if ($StatusOverride) { $StatusOverride } elseif (($failedActions -gt 0) -or ($simulatedActions -gt 0)) { 'Degraded' } else { 'Pass' }

	Write-Log -Component 'Workflow' -EventType 'Summary' -Severity 'Information' -Message ("Workflow completed with status '{0}'." -f $status) -Data @{
		Result = $status
		Duration = $duration.TotalSeconds
		PassedActions = $passedActions
		FailedActions = $failedActions
		SimulatedActions = $simulatedActions
		ExecutionMode = $script:RunState.ExecutionMode
		TextLogPath = $script:RunState.TextLogPath
		JsonLogPath = $script:RunState.JsonLogPath
	}
}

function Test-NonNegativeIntegerValue {
	param(
		[object]$Value
	)

	return ($Value -is [int]) -and ($Value -ge 0)
}

function Test-PositiveIntegerValue {
	param(
		[object]$Value
	)

	return ($Value -is [int]) -and ($Value -ge 1)
}

function Test-PositiveNumberValue {
	param(
		[object]$Value
	)

	try {
		return ([double]$Value -gt 0)
	}
	catch {
		return $false
	}
}

function Test-ActionDefinition {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$Action,

		[Parameter(Mandatory = $true)]
		[hashtable]$TimingConfig,

		[Parameter(Mandatory = $true)]
		[string]$ActionPath
	)

	if ($null -eq $Action['Type']) {
		throw "Action at $ActionPath is missing Type."
	}

	if ($null -eq $Action['Name']) {
		throw "Action at $ActionPath is missing Name."
	}

	if (-not (Test-PositiveIntegerValue -Value $Action['RepeatCount'])) {
		throw "Action '$($Action.Name)' at $ActionPath must define RepeatCount as an integer greater than or equal to 1."
	}

	if (-not (Test-NonNegativeIntegerValue -Value $Action['PreDelayMs'])) {
		throw "Action '$($Action.Name)' at $ActionPath must define PreDelayMs as a non-negative integer."
	}

	if (-not (Test-NonNegativeIntegerValue -Value $Action['PostDelayMs'])) {
		throw "Action '$($Action.Name)' at $ActionPath must define PostDelayMs as a non-negative integer."
	}

	$profileName = $Action['JitterProfile']
	if (($null -eq $profileName) -or ($null -eq $TimingConfig[$profileName])) {
		throw "Action '$($Action.Name)' at $ActionPath references unknown jitter profile '$profileName'."
	}

	switch ($Action.Type) {
		'KeyPress' {
			if (($null -eq $Action['Keys']) -or (-not ($Action['Keys'] -is [string])) -or ($Action['Keys'] -eq '')) {
				throw "KeyPress action '$($Action.Name)' at $ActionPath must define non-empty Keys."
			}
		}
		'Wait' {
			if (-not (Test-NonNegativeIntegerValue -Value $Action['DurationMs'])) {
				throw "Wait action '$($Action.Name)' at $ActionPath must define DurationMs as a non-negative integer."
			}
		}
		'Burst' {
			$sequence = @($Action['Sequence'])
			if ($sequence.Count -eq 0) {
				throw "Burst action '$($Action.Name)' at $ActionPath must define at least one child action in Sequence."
			}

			for ($index = 0; $index -lt $sequence.Count; $index++) {
				$childPath = '{0}.Sequence[{1}]' -f $ActionPath, $index
				Test-ActionDefinition -Action $sequence[$index] -TimingConfig $TimingConfig -ActionPath $childPath
			}
		}
		default {
			throw "Action '$($Action.Name)' at $ActionPath uses unsupported Type '$($Action.Type)'."
		}
	}

	Write-Log -Component 'Workflow' -EventType 'ActionValidation' -Severity 'Debug' -Message ("Validated action '{0}'." -f $Action.Name) -Data @{ ActionPath = $ActionPath; ActionType = $Action.Type }
}

function Invoke-PreflightChecks {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$Configuration
	)

	$executionPolicies = Get-ExecutionPolicySnapshot
	$chromePath = $null
	$premierePath = $null
	$projectExists = $false
	$blockers = @()
	$warnings = @()
	try {
		$chromePath = Test-ChromeLaunchConfiguration -BrowserConfig $Configuration.Browser -SimulationOnly $true
	}
	catch {
		$blockers += $_.Exception.Message
	}

	try {
		$premierePath = Resolve-PremiereExecutablePath -PremiereConfig $Configuration.Premiere
	}
	catch {
		$blockers += $_.Exception.Message
	}

	if (($null -ne $Configuration.Premiere.ProjectPath) -and ($Configuration.Premiere.ProjectPath -notmatch '^\s*$')) {
		$projectExists = Test-Path -LiteralPath $Configuration.Premiere.ProjectPath
	}

	if (-not (Test-IsWindows)) {
		$blockers += 'Live execution requires Windows.'
	}

	if (Test-IsConstrainedLanguageMode) {
		$warnings += 'PowerShell session is running in Constrained Language Mode; desktop automation will be skipped and keyboard-driven actions will be simulated.'
	}

	if (-not $projectExists) {
		$blockers += 'Configured Premiere project path does not exist.'
	}

	if ((-not $Configuration.Premiere.UseFileAssociation) -and (-not $premierePath)) {
		$blockers += 'Premiere executable could not be resolved for explicit launch mode.'
	}

	if ($Configuration.Browser.RequireSuccessfulLaunch -and (-not $chromePath)) {
		$blockers += 'Chrome executable could not be resolved while successful Chrome launch is required.'
	}

	$summary = [ordered]@{
		WindowsHost = Test-IsWindows
		LanguageMode = [string]$ExecutionContext.SessionState.LanguageMode
		DesktopAutomationAvailable = (Test-DesktopAutomationAvailable)
		ExecutionPolicies = $executionPolicies
		ProjectPath = $Configuration.Premiere.ProjectPath
		ProjectExists = $projectExists
		ChromeExecutablePath = $chromePath
		PremiereExecutablePath = $premierePath
		PremiereUseFileAssociation = [bool]$Configuration.Premiere.UseFileAssociation
		PremiereProcessNames = @(Get-ConfiguredPremiereProcessNames -PremiereConfig $Configuration.Premiere)
		WindowTitleRegex = $Configuration.Premiere.WindowTitleRegex
		LiveReady = ($blockers.Count -eq 0) -and (Test-DesktopAutomationAvailable)
		DegradedLiveReady = ($blockers.Count -eq 0)
		Blockers = $blockers
		Warnings = $warnings
	}

	$severity = if ($summary.LiveReady) { 'Information' } elseif ($summary.DegradedLiveReady) { 'Warning' } else { 'Error' }
	Write-Log -Component 'Workflow' -EventType 'Preflight' -Severity $severity -Message 'Preflight checks completed.' -Data $summary

	if ($summary.LiveReady) {
		Write-Host 'Preflight: live execution prerequisites look satisfied.'
	}
	elseif ($summary.DegradedLiveReady) {
		Write-Host 'Preflight: constrained-compatible live simulation is available with these warnings:'
		foreach ($warning in $warnings) {
			Write-Host (' - {0}' -f $warning)
		}
	}
	else {
		Write-Host 'Preflight: live execution is currently blocked by:'
		foreach ($blocker in $blockers) {
			Write-Host (' - {0}' -f $blocker)
		}
	}

	return $summary
}

function Invoke-SyntheticWorkflow {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$Configuration,

		[Parameter(Mandatory = $true)]
		[object[]]$WorkflowScenario,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	$workflowDeadline = (Get-Date).AddSeconds($Configuration.Workflow.MaxRunTimeSec)

	Write-Log -Component 'Workflow' -EventType 'State' -Severity 'Information' -Message 'State: LaunchingBrowser.'
	Start-ChromeLoad -BrowserConfig $Configuration.Browser -SimulationOnly $SimulationOnly | Out-Null

	Write-Log -Component 'Workflow' -EventType 'State' -Severity 'Information' -Message 'State: LaunchingPremiere.'
	$script:RunState.PremiereProcess = Start-PremiereSession -PremiereConfig $Configuration.Premiere -SimulationOnly $SimulationOnly

	$window = Wait-PremiereWindowReady -PremiereConfig $Configuration.Premiere -ReadyTimeoutSec $Configuration.Workflow.ReadyTimeoutSec -SimulationOnly $SimulationOnly
	if ($Configuration.Focus.RequireSameIntegrityLevel -and -not $SimulationOnly -and (Test-DesktopAutomationAvailable)) {
		$hasSameIntegrity = Test-SameIntegrityLevel -PremiereProcess $window.Process -ChromeLaunches @($script:RunState.ChromeLaunches) -SimulationOnly $SimulationOnly
		if (-not $hasSameIntegrity) {
			throw 'Script, Premiere, and Chrome are not running at the same integrity level.'
		}
	}
	elseif ($Configuration.Focus.RequireSameIntegrityLevel -and -not $SimulationOnly) {
		Write-Log -Component 'Focus' -EventType 'IntegrityCheckSkipped' -Severity 'Warning' -Message 'Integrity check skipped because no keyboard input will be sent in constrained live mode.'
	}

	for ($loop = 1; $loop -le $Configuration.Workflow.LoopCount; $loop++) {
		Write-Log -Component 'Workflow' -EventType 'LoopStart' -Severity 'Information' -Message ("Starting workflow loop {0} of {1}." -f $loop, $Configuration.Workflow.LoopCount)

		foreach ($action in $WorkflowScenario) {
			if ((Get-Date) -gt $workflowDeadline) {
				throw 'Workflow exceeded the configured maximum runtime.'
			}

			try {
				[void](Invoke-WorkflowAction -Action $action -SimulationOnly $SimulationOnly)
				$script:RunState.ConsecutiveErrors = 0
			}
			catch {
				$script:RunState.ConsecutiveErrors++
				Write-ErrorLog -Component 'Workflow' -Exception $_.Exception -ActionName $action.Name

				$mustAbort = [bool]$action.AbortOnFailure
				if (-not $mustAbort -and $Configuration.Safety.AbortOnFocusFailure -and $_.Exception.Message -match 'focus') {
					$mustAbort = $true
				}

				if ($mustAbort) {
					throw
				}

				if ($script:RunState.ConsecutiveErrors -ge $Configuration.Safety.MaxConsecutiveErrors) {
					throw "Maximum consecutive error threshold reached ($($Configuration.Safety.MaxConsecutiveErrors))."
				}
			}
		}
	}
}

function Test-Configuration {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$Configuration,

		[Parameter(Mandatory = $true)]
		[object[]]$WorkflowScenario,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	if (-not (Test-PositiveNumberValue -Value $Configuration.Telemetry.TelemetrySampleIntervalSec)) {
		throw 'Telemetry.TelemetrySampleIntervalSec must be configured as a number greater than 0.'
	}

	[void](Test-ChromeLaunchConfiguration -BrowserConfig $Configuration.Browser -SimulationOnly $SimulationOnly)
	Test-ProjectPathConfiguration -PremiereConfig $Configuration.Premiere -SimulationOnly $SimulationOnly

	if (-not $WorkflowScenario -or $WorkflowScenario.Count -eq 0) {
		throw 'The workflow scenario must contain at least one action.'
	}

	for ($index = 0; $index -lt $WorkflowScenario.Count; $index++) {
		$actionPath = 'Scenario[{0}]' -f $index
		Test-ActionDefinition -Action $WorkflowScenario[$index] -TimingConfig $Configuration.Timing -ActionPath $actionPath
	}

	if (-not (Test-IsWindows) -and -not $SimulationOnly) {
		throw 'Live execution is only supported on Windows interactive desktop sessions.'
	}
}

try {
	$simulationOnly = [bool]($DryRun -or $ValidateOnly -or $Preflight)
	if (-not $RunId) {
		$RunId = New-RunIdValue
	}
	$script:RunState = New-RunState -Configuration $Config -Id $RunId -SimulationOnly $simulationOnly
	if ($simulationOnly) {
		$script:RunState.ExecutionMode = 'SimulationOnly'
	}
	elseif (Test-IsConstrainedLanguageMode) {
		$script:RunState.ExecutionMode = 'ConstrainedLive'
	}
	else {
		$script:RunState.ExecutionMode = 'FullLive'
	}
	Write-Log -Component 'Workflow' -EventType 'State' -Severity 'Information' -Message 'State: Initialising.' -Data @{ DryRun = $DryRun; ValidateOnly = $ValidateOnly }
	Write-Log -Component 'Telemetry' -EventType 'Configuration' -Severity 'Information' -Message ("Effective telemetry configuration loaded with ping target '{0}'." -f $Config.Telemetry.PingTarget) -Data @{
		PingTarget = $Config.Telemetry.PingTarget
		TelemetrySampleIntervalSec = $Config.Telemetry.TelemetrySampleIntervalSec
		SampleOnStart = [bool]$Config.Telemetry.SampleOnStart
		SystemLoadEnabled = $true
		NetworkThroughputEnabled = $true
		NetworkAdapterName = $Config.Telemetry.NetworkAdapterName
	}

	if ($Preflight) {
		[void](Invoke-PreflightChecks -Configuration $Config)
		return
	}

	if ((-not $simulationOnly) -and (Test-IsConstrainedLanguageMode)) {
		Write-Log -Component 'Workflow' -EventType 'Mode' -Severity 'Warning' -Message 'Running in constrained-compatible live mode without a desktop helper. Premiere and Chrome will launch, but focus automation and key injection will be skipped.'
	}

	if ((-not $simulationOnly) -and (Test-IsWindows)) {
		if (Test-DesktopAutomationAvailable) {
			Initialize-WindowsAutomation
		}
	}

	Test-Configuration -Configuration $Config -WorkflowScenario $Scenario -SimulationOnly $simulationOnly

	if ($ValidateOnly) {
		Write-Log -Component 'Workflow' -EventType 'Validation' -Severity 'Information' -Message 'Configuration validation completed successfully.'
		return
	}

	Invoke-SyntheticWorkflow -Configuration $Config -WorkflowScenario $Scenario -SimulationOnly $simulationOnly
	Stop-PremiereSession -SimulationOnly $simulationOnly
	Write-RunSummary
}
catch {
	if ($script:RunState) {
		Write-ErrorLog -Component 'Workflow' -Exception $_.Exception
		Write-RunSummary -StatusOverride 'Failed'
	}
	throw
}
