# Original credits to Joe W. from Noventech. Changed some things around for deployment with Action1.

Function Invoke-DellUpdates {
    Write-Host -ForegroundColor Yellow "Starting Dell Command Update Check"

    try {
        $computerSystem = Get-WmiObject Win32_ComputerSystem
        if ($computerSystem.Manufacturer -notlike "*Dell*") {
            Write-Host -ForegroundColor Red "Computer is not a Dell system. Exiting."
            return
        }

        $dcuPath = "${env:ProgramFiles}\Dell\CommandUpdate\dcu-cli.exe" # Find Dell Command Update CLI
        if (-Not (Test-Path -Path $dcuPath)) {
            Write-Host -ForegroundColor Red "Computer does not have Dell Command Update installed."
            return
        }

        $dellLogPath = "C:\Dell\Logs"
        if (-Not (Test-Path -Path $dellLogPath)) {
            New-Item -ItemType Directory -Path $dellLogPath -Force | Out-Null
            Write-Host -ForegroundColor Cyan "Created dell logs directory: $dellLogPath"
        }
        
        Write-Host -ForegroundColor Yellow "Attempting to configure DCU CLI."
    
        $process = Start-Process -FilePath $dcuPath -ArgumentList "/scan -outputLog=$dellLogPath\dcu-cli.log" -Wait -PassThru
    
        if ($process.ExitCode -ne 0) {
            Write-Host -ForegroundColor Red "Scan failed to complete."
            return
        }
    
        $updateProcess = Start-Process -FilePath $dcuPath -ArgumentList "/applyupdates -outputLog=$dellLogPath\dcu-cli.log" -Wait -PassThru
        if ($updateProcess.ExitCode -eq 0) {
            Write-Host -Foreground Green "Dell Command Update Completed."
        } elseif ($updateProcess.ExitCode -eq 5) {
            Write-Host -ForegroundColor Yellow "No dell updates available."
        } else {
            Write-Host -ForegroundColor Red "Dell update failed."
        }
    } catch {
        Write-Host "Error running dell update: $_"
    }
}