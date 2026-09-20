param([switch]$Check)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Test-UpdateResult([int]$Code, [bool]$Upgrade) {
    return ($Code -eq 0 -or ($Upgrade -and $Code -in @(-1978335189, -1978335212)))
}

# Callbacks run in .NET so background threads do not need a PowerShell runspace.
Add-Type -TypeDefinition @'
using System;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Text;
public sealed class WingetRun : IDisposable {
    public readonly ConcurrentQueue<string> Lines = new ConcurrentQueue<string>();
    private Process process;
    public void Start(string executable, string arguments) {
        process = new Process();
        process.StartInfo = new ProcessStartInfo(executable, arguments) {
            UseShellExecute = false, CreateNoWindow = true,
            RedirectStandardOutput = true, RedirectStandardError = true,
            StandardOutputEncoding = Encoding.UTF8, StandardErrorEncoding = Encoding.UTF8
        };
        process.OutputDataReceived += (s,e) => { if (e.Data != null) Lines.Enqueue(e.Data); };
        process.ErrorDataReceived += (s,e) => { if (e.Data != null) Lines.Enqueue(e.Data); };
        process.Start();
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();
    }
    public bool Finished { get { return process.HasExited; } }
    public int Complete() { process.WaitForExit(); return process.ExitCode; }
    public void Dispose() { if (process != null) process.Dispose(); }
}
'@

$upgradeArgs = 'upgrade --all --include-pinned --force --include-unknown --silent --ignore-warnings --accept-package-agreements --accept-source-agreements --disable-interactivity --source '
$stages = @(
    @{Title='Refreshing package sources'; Args='source update --disable-interactivity --ignore-warnings'; Upgrade=$false},
    @{Title='Updating desktop apps'; Args=$upgradeArgs + 'winget'; Upgrade=$true},
    @{Title='Updating Microsoft Store apps'; Args=$upgradeArgs + 'msstore'; Upgrade=$true}
)
if ($Check) { return }

try {
    $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $command = "& '" + $PSCommandPath.Replace("'", "''") + "'"
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
        $child = Start-Process -FilePath "$PSHOME\powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -EncodedCommand $encoded" -Verb RunAs -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop
        exit $child.ExitCode
    }
} catch {
    [void][Windows.Forms.MessageBox]::Show("Could not start the updater with administrator privileges.`r`n$($_.Exception.Message)", 'App Updater', 'OK', 'Error')
    exit 1
}

$created = $false
$mutex = [Threading.Mutex]::new($true, 'Local\HalKaWingetGuiUpdater', [ref]$created)
if (-not $created) {
    [void][Windows.Forms.MessageBox]::Show('The updater is already running.', 'App Updater')
    $mutex.Dispose()
    exit 1
}

[Windows.Forms.Application]::EnableVisualStyles()
$form = [Windows.Forms.Form]::new()
$form.Text = 'App Updater'
$form.ClientSize = [Drawing.Size]::new(780, 530)
$form.MinimumSize = [Drawing.Size]::new(620, 420)
$form.StartPosition = 'CenterScreen'
$form.Font = [Drawing.Font]::new('Segoe UI', 10)
$form.BackColor = [Drawing.Color]::White
$title = [Windows.Forms.Label]::new()
$title.Text = 'Updating your apps'
$title.Font = [Drawing.Font]::new('Segoe UI', 20, [Drawing.FontStyle]::Bold)
$title.SetBounds(24, 20, 730, 44)
$title.Anchor = 'Top, Left, Right'
$status = [Windows.Forms.Label]::new()
$status.Text = 'Starting automatically...'
$status.SetBounds(26, 76, 725, 28)
$status.Anchor = 'Top, Left, Right'
$progress = [Windows.Forms.ProgressBar]::new()
$progress.SetBounds(26, 112, 728, 8)
$progress.Anchor = 'Top, Left, Right'
$progress.Style = 'Marquee'
$output = [Windows.Forms.RichTextBox]::new()
$output.SetBounds(26, 140, 728, 304)
$output.Anchor = 'Top, Bottom, Left, Right'
$output.ReadOnly = $true
$output.DetectUrls = $false
$output.Font = [Drawing.Font]::new('Consolas', 9)
$output.BackColor = [Drawing.Color]::FromArgb(246, 248, 250)
$output.BorderStyle = 'None'
$note = [Windows.Forms.Label]::new()
$note.Text = 'Updates run automatically. This window will show the results.'
$note.SetBounds(26, 466, 570, 42)
$note.Anchor = 'Bottom, Left, Right'
$close = [Windows.Forms.Button]::new()
$close.Text = 'Close'
$close.SetBounds(644, 464, 110, 36)
$close.Anchor = 'Bottom, Right'
$close.Enabled = $false
$close.Add_Click({ $form.Close() })
$form.Controls.AddRange(@($title, $status, $progress, $output, $note, $close))
$script:runner = $null
$script:index = -1
$script:failed = $false
$script:done = $false
$script:log = $null
$script:exitCode = 1
$timer = [Windows.Forms.Timer]::new()
$timer.Interval = 200

function Write-UpdateLog([string]$Text) {
    $clean = $Text -replace '\x1b\[[0-9;?]*[ -/]*[@-~]', ''
    if ($output.TextLength -gt 200000) { $output.Clear() }
    $output.AppendText($clean + "`r`n")
    $output.SelectionStart = $output.TextLength
    $output.ScrollToCaret()
    if ($script:log) {
        try { $script:log.WriteLine($clean) } catch {
            $script:log.Dispose()
            $script:log = $null
            $output.AppendText("WARNING: Could not write to the log file.`r`n")
        }
    }
}
function Complete-Updates {
    $timer.Stop()
    $script:done = $true
    $progress.Style = 'Continuous'
    $progress.Value = 100
    $close.Enabled = $true
    $script:exitCode = if ($script:failed) { 1 } else { 0 }
    $title.Text = if ($script:failed) { 'Finished with errors' } else { 'Updates complete' }
    $status.Text = if ($script:failed) { 'Some updates failed. Details are shown below.' } else { 'All update checks completed successfully.' }
    Write-UpdateLog ("`r`nRESULT: " + $status.Text)
    if ($script:log) { $script:log.Dispose(); $script:log = $null }
    $note.Text = 'Finished. You can close this window.'
}
function Start-NextStage {
    $script:index++
    if ($script:index -ge $stages.Count) { Complete-Updates; return }
    $stage = $stages[$script:index]
    $status.Text = ('Step {0} of {1}: {2}' -f ($script:index + 1), $stages.Count, $stage.Title)
    Write-UpdateLog ("`r`n" + $status.Text)
    $script:runner = [WingetRun]::new()
    $script:runner.Start($script:winget, $stage.Args)
}
function Drain-UpdateOutput {
    $line = $null
    while ($script:runner.Lines.TryDequeue([ref]$line)) { Write-UpdateLog $line }
}
$timer.Add_Tick({
    try {
        if (-not $script:runner) { return }
        Drain-UpdateOutput
        if ($script:runner.Finished) {
            $code = $script:runner.Complete()
            Drain-UpdateOutput
            if (-not (Test-UpdateResult $code $stages[$script:index].Upgrade)) {
                $script:failed = $true
                Write-UpdateLog "ERROR: This step failed with exit code $code."
            } elseif ($code -ne 0) { Write-UpdateLog 'No applicable updates for this source.' }
            $script:runner.Dispose()
            $script:runner = $null
            Start-NextStage
        }
    } catch {
        $script:failed = $true
        Write-UpdateLog ('ERROR: ' + $_.Exception.Message)
        Complete-Updates
    }
})
$form.Add_Shown({
    try {
        $logDir = Join-Path $env:LOCALAPPDATA 'WingetUpdater\Logs'
        [void][IO.Directory]::CreateDirectory($logDir)
        $logPath = Join-Path $logDir ('update-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $PID + '.log')
        $script:log = [IO.StreamWriter]::new($logPath, $false, [Text.UTF8Encoding]::new($false))
        $script:log.AutoFlush = $true
        Write-UpdateLog ('Started: ' + (Get-Date -Format o))
        Write-UpdateLog ('Log: ' + $logPath)
        $script:winget = (Get-Command winget.exe -CommandType Application -ErrorAction Stop).Source
        Start-NextStage
        $timer.Start()
    } catch {
        $script:failed = $true
        Write-UpdateLog ('ERROR: ' + $_.Exception.Message)
        Complete-Updates
    }
})
$form.Add_FormClosing({ param($sender, $eventArgs)
    if (-not $script:done) { $eventArgs.Cancel = $true }
})
try { [void]$form.ShowDialog() } finally {
    $timer.Dispose()
    if ($script:runner) { $script:runner.Dispose() }
    if ($script:log) { $script:log.Dispose() }
    $form.Dispose()
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
exit $script:exitCode
