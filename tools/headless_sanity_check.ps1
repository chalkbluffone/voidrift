$ErrorActionPreference = 'Stop'

$godotExe = "C:\git\godot\Godot_v4.6-stable_win64\Godot_v4.6-stable_win64.exe"
$projectPath = "C:\git\voidrift"
$stdoutLog = Join-Path $projectPath "debug_log_headless_stdout.txt"
$stderrLog = Join-Path $projectPath "debug_log_headless_stderr.txt"

if (!(Test-Path $godotExe)) {
    Write-Error "Godot executable not found: $godotExe"
    exit 1
}

if (Test-Path $stdoutLog) {
    Remove-Item $stdoutLog -Force
}
if (Test-Path $stderrLog) {
    Remove-Item $stderrLog -Force
}

$startProcessArgs = @{
    FilePath = $godotExe
    ArgumentList = @('--headless','--path',$projectPath,'--import','--quit')
    PassThru = $true
    Wait = $true
    WindowStyle = 'Hidden'
    RedirectStandardOutput = $stdoutLog
    RedirectStandardError = $stderrLog
}

$process = Start-Process @startProcessArgs

Write-Output "Godot headless sanity check exit code: $($process.ExitCode)"
Write-Output "stdout log: $stdoutLog"
Write-Output "stderr log: $stderrLog"

if ($process.ExitCode -ne 0) {
    Write-Error "Headless sanity check failed with exit code $($process.ExitCode)."
    exit $process.ExitCode
}

exit 0
