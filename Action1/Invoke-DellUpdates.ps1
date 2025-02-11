$SUCCESS = 0
$FAILURE = 1

Write-Host "Starting Dell Command Update Check"

try {
    $computerSystem = Get-WmiObject Win32_ComputerSystem
    if ($computerSystem.Manufacturer -notlike "*Dell*") {
        Write-Error "Computer is not a Dell System. Exiting."
        exit $FAILURE
    }

    $dcuPath = "${env:ProgramFiles}\Dell\CommandUpdate\dcu-cli.exe"
    if (-Not (Test-Path -Path $dcuPath)) {
        Write-Error "Computer does not have Dell Command Update installed. Exiting."
        exit $FAILURE
    }

    $dellLogsPath = "C:\Dell\Logs"
    if (-Not (Test-Path -Path $dellLogsPath)) {
        Write-Host "Creating Dell Logs Directory: $dellsLogPath"
        New-Item -ItemType Directory -Path $dellLogsPath -Force | Out-Null
    }

    Write-Host "Configuring Dell Command Update..."
    $process = Start-Process -FilePath $dcuPath -ArgumentList "/configure -silent -autoSuspendBitLocker=enable -userConsent=disable" -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Error "Failed to configure DEll Command Update (Exit Code: $($process.ExitCode))"
        exit $FAILURE
    }

    Write-Host "Running Dell Command Update Scan"
    $process = Start-Process -FilePath $dcuPath -ArgumentList "/scan -outputLog=$dellsLogPath\scan.log" -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Error "Dell Command Update Scan Failed."
        exit $FAILURE
    }

    Write-Host "Dell Command Update Scan Completed. Applying updates."
    $process = Start-Process -FilePath $dcuPath -ArgumentList "/applyupdates -outputLog=$dellLogsPath\updates.log" -Wait -PassThru
    if ($process.ExitCode -eq 0) {
        Write-Host "Dell Updates Applied Successfully."
        exit $SUCCESS
    } elseif ($process.ExitCode -eq 5) {
        Write-Host "No Dell Updates Available."
        exit $SUCCESS
    } else {
        Write-Host "Dell Command Update Completed with Exit Code: $($process.ExitCode)"
        exit $FAILURE
    }

} catch {
    Write-Host "Error Running DDell updates: $_"
    return $FAILURE
}