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
	'https://example-1'
	'https://example-2'
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
		ProjectPath = 'C:\PremiereProjects\SampleProject.prproj'
		InitialLoadDelayMs = 17000
	}
	Focus = @{
		RetryCount = 5
		RetryDelayMs = 750
		VerifyDelayMs = 400
		RequireSameIntegrityLevel = $true
	}
	Timing = @{
		Micro = @{ MinMs = 100; MaxMs = 350 }
		Normal = @{ MinMs = 400; MaxMs = 1500 }
		Think = @{ MinMs = 2000; MaxMs = 6000 }
	}
	Workflow = @{
		MaxRunTimeSec = 900
		LoopCount = 1
		ReadyTimeoutSec = 120
	}
	Keyboard = @{
		PlayPause = ' '
		StepForward = '{RIGHT}'
		StepBack = '{LEFT}'
	}
	Logging = @{
		LogPath = (Join-Path -Path $PSScriptRoot -ChildPath 'logs')
		LogLevel = 'Information'
		EnableConsole = $true
		EnableJsonLog = $true
		IncludePingDetail = $true
	}
	Telemetry = @{
		PingTarget = $PingTarget
		PingIntervalSec = 1
		PingTimeoutMs = 1000
		SampleOnStart = $true
		FailureWarningLimitPerAction = 1
	}
	Safety = @{
		AbortOnFocusFailure = $true
		MaxConsecutiveErrors = 3
	}
}

$Scenario = @(
	@{
		Type = 'KeyPress'
		Name = 'Pause'
		Keys = $Config.Keyboard.PlayPause
		JitterProfile = 'Think'
		RepeatCount = 1
		FocusRequired = $true
		AbortOnFailure = $true
		PreDelayMs = 0
		PostDelayMs = 0
	}
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
		Type = 'Burst'
		Name = 'StepForwardBurst'
		Keys = $null
		JitterProfile = 'Micro'
		RepeatCount = 1
		FocusRequired = $true
		AbortOnFailure = $true
		Sequence = @(
			@{
				Type = 'KeyPress'
				Name = 'StepForward'
				Keys = $Config.Keyboard.StepForward
				JitterProfile = 'Micro'
				RepeatCount = 10
				FocusRequired = $true
				AbortOnFailure = $true
				PreDelayMs = 0
				PostDelayMs = 0
			}
		)
		PreDelayMs = 0
		PostDelayMs = 0
	}
	@{
		Type = 'KeyPress'
		Name = 'PauseAgain'
		Keys = $Config.Keyboard.PlayPause
		JitterProfile = 'Normal'
		RepeatCount = 1
		FocusRequired = $true
		AbortOnFailure = $true
		PreDelayMs = 0
		PostDelayMs = 0
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
				RepeatCount = 10
				FocusRequired = $true
				AbortOnFailure = $true
				PreDelayMs = 0
				PostDelayMs = 0
			}
		)
		PreDelayMs = 0
		PostDelayMs = 0
	}
	@{
		Type = 'KeyPress'
		Name = 'ResumePlay'
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
		Name = 'ExtendedObservePlayback'
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
		Write-Host $line
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

	return [WorkflowAutomation.NativeMethods]::GetForegroundWindow() -eq $PremiereWindow.Handle
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

function New-PingTelemetrySession {
	param(
		[Parameter(Mandatory = $true)]
		[string]$ActionName,

		[Parameter(Mandatory = $true)]
		[hashtable]$TelemetryConfig,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	return [ordered]@{
		ActionName = $ActionName
		Target = $TelemetryConfig.PingTarget
		IntervalMs = $TelemetryConfig.PingIntervalSec * 1000
		TimeoutMs = $TelemetryConfig.PingTimeoutMs
		SampleOnStart = [bool]$TelemetryConfig.SampleOnStart
		FailureWarningLimitPerAction = [int]$TelemetryConfig.FailureWarningLimitPerAction
		Samples = @()
		LastSampleAt = $null
		StartedAt = Get-Date
		DryRun = $SimulationOnly
		FailureCount = 0
		FailureWarningsLogged = 0
		FirstFailureMessage = ''
	}
}

function Add-PingSample {
	param(
		[Parameter(Mandatory = $true)]
		[psobject]$TelemetrySession
	)

	$sampleTimestamp = Get-Date

	if ($TelemetrySession.DryRun) {
		$latency = Get-Random -Minimum 12 -Maximum 45
		$sample = [ordered]@{
			Timestamp = (Get-Date -Date $sampleTimestamp -Format o)
			Success = $true
			LatencyMs = $latency
			Error = $null
		}
		$TelemetrySession.Samples += $sample
		$TelemetrySession.LastSampleAt = $sampleTimestamp
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
	$TelemetrySession.LastSampleAt = $sampleTimestamp

	if (-not $sample.Success) {
		$TelemetrySession.FailureCount++
		if (($TelemetrySession.FirstFailureMessage -eq '') -and ($null -ne $sample.Error)) {
			$TelemetrySession.FirstFailureMessage = [string]$sample.Error
		}

		if ($TelemetrySession.FailureWarningsLogged -lt $TelemetrySession.FailureWarningLimitPerAction) {
			Write-Log -Component 'Telemetry' -EventType 'PingFailure' -Severity 'Warning' -Message ("Ping sample failed for action '{0}'. Additional failures for this action will be summarized only." -f $TelemetrySession.ActionName) -Data @{
				ActionName = $TelemetrySession.ActionName
				PingTarget = $TelemetrySession.Target
				ErrorMessage = $sample.Error
			}
			$TelemetrySession.FailureWarningsLogged++
		}
	}

	return $sample
}

function Start-PingTelemetry {
	param(
		[Parameter(Mandatory = $true)]
		[string]$ActionName,

		[Parameter(Mandatory = $true)]
		[hashtable]$TelemetryConfig,

		[Parameter(Mandatory = $true)]
		[bool]$SimulationOnly
	)

	$session = New-PingTelemetrySession -ActionName $ActionName -TelemetryConfig $TelemetryConfig -SimulationOnly $SimulationOnly
	Write-Log -Component 'Telemetry' -EventType 'Start' -Severity 'Information' -Message ("Ping telemetry started for action '{0}'." -f $ActionName) -Data @{ PingTarget = $TelemetryConfig.PingTarget }

	if ($session.SampleOnStart) {
		[void](Add-PingSample -TelemetrySession $session)
	}

	return $session
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

		if ($TelemetrySession) {
			$shouldSample = $false
			if (-not $TelemetrySession.LastSampleAt) {
				$shouldSample = $true
			}
			else {
				$elapsedSinceSample = ((Get-Date) - $TelemetrySession.LastSampleAt).TotalMilliseconds
				if ($elapsedSinceSample -ge $TelemetrySession.IntervalMs) {
					$shouldSample = $true
				}
			}

			if ($shouldSample) {
				[void](Add-PingSample -TelemetrySession $TelemetrySession)
			}
		}
	}
}

function Get-PingStatistics {
	param(
		[Parameter(Mandatory = $true)]
		[psobject]$TelemetrySession
	)

	$successfulSamples = @($TelemetrySession.Samples | Where-Object { $_.Success -and $null -ne $_.LatencyMs } | ForEach-Object { [double]$_.LatencyMs } | Sort-Object)
	if (-not $successfulSamples) {
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

	$median = 0
	if ($successfulSamples.Count % 2 -eq 1) {
		$median = $successfulSamples[[int]($successfulSamples.Count / 2)]
	}
	else {
		$upperIndex = [int]($successfulSamples.Count / 2)
		$lowerIndex = $upperIndex - 1
		$median = ($successfulSamples[$lowerIndex] + $successfulSamples[$upperIndex]) / 2
	}

	return @{
		PingTarget = $TelemetrySession.Target
		PingSampleCount = $successfulSamples.Count
		PingLowestMs = (($successfulSamples | Measure-Object -Minimum).Minimum)
		PingHighestMs = (($successfulSamples | Measure-Object -Maximum).Maximum)
		PingMedianMs = $median
		PingAverageMs = (($successfulSamples | Measure-Object -Average).Average)
		PingTelemetryAvailable = $true
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
	}
	else {
		$message = ("Ping summary for action '{0}': target={1}; samples=0; failures={2}; telemetry unavailable." -f $ActionName, $stats.PingTarget, $TelemetrySession.FailureCount)
		if ($TelemetrySession.FirstFailureMessage) {
			$message = "{0} FirstFailure='{1}'." -f $message, $TelemetrySession.FirstFailureMessage
		}
	}

	Write-Log -Component 'Telemetry' -EventType 'Summary' -Severity $severity -Message $message -Data $payload
	return $stats
}

function Stop-PingTelemetry {
	param(
		[Parameter(Mandatory = $true)]
		[psobject]$TelemetrySession
	)

	return Write-PingSummary -ActionName $TelemetrySession.ActionName -TelemetrySession $TelemetrySession
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
	$canInjectInput = Test-CanInjectInput

	for ($iteration = 1; $iteration -le $Action.RepeatCount; $iteration++) {
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

	for ($iteration = 1; $iteration -le $Action.RepeatCount; $iteration++) {
		foreach ($childAction in $Action.Sequence) {
			Invoke-Action -Action $childAction -TelemetrySession $TelemetrySession -SimulationOnly $SimulationOnly
		}
	}

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
	$telemetrySession = Start-PingTelemetry -ActionName $Action.Name -TelemetryConfig $Config.Telemetry -SimulationOnly $SimulationOnly
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

		Invoke-Action -Action $Action -TelemetrySession $telemetrySession -SimulationOnly $SimulationOnly
		$jitterDelay = Get-JitterDelay -TimingConfig $Config.Timing -ProfileName $Action.JitterProfile
		Invoke-TelemetryAwareWait -DurationMs $jitterDelay -TelemetrySession $telemetrySession

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

	$telemetrySummary = Stop-PingTelemetry -TelemetrySession $telemetrySession
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

	if ($Configuration.Telemetry.PingIntervalSec -ne 1) {
		throw 'Telemetry.PingIntervalSec must remain fixed at 1 second for v1.'
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
	Write-Log -Component 'Telemetry' -EventType 'Configuration' -Severity 'Information' -Message ("Effective ping target configured as '{0}'." -f $Config.Telemetry.PingTarget) -Data @{
		PingTarget = $Config.Telemetry.PingTarget
		PingIntervalSec = $Config.Telemetry.PingIntervalSec
		SampleOnStart = [bool]$Config.Telemetry.SampleOnStart
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
