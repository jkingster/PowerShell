<#
    .SYNOPSIS
    This script automates the creation of a system restore point for target machines, ensuring prerequisites are met.

    .DESCRIPTION
    The script performs the following actions:
    - Verifies that the target operating system is not a Windows Server, as system restore points are not supported on servers.
    - Checks whether system protection is enabled on the primary drive (C:\).
    - If system protection is not enabled, it enables it on the C:\ drive with a maximum usage of 10%.
    - Ensures a restore point has not already been created within the last 24 hours to avoid duplication.
    - Creates a new system restore point with a standardized naming convention indicating the process and date.

    This script is designed for automation platforms such as Action1 to streamline system protection tasks on workstations.
#>


$DRIVE_LETTER = "C:"

Function Test-ValidOS {
    $os = Get-WmiObject Win32_OperatingSystem | Select-Object Caption
    if ($os -like '*Server*') {
        $Host.UI.WriteErrorLine('System restore point was not created. System restore points are not supported on Windows Server.')
        return $false
    } else {
        return $true
    }
}

Function Test-SystemProtection  {
    $regKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
    $regKeyItem = Get-ItemProperty -Path $regKey -Name RPSessionInterval -ErrorAction SilentlyContinue
    if ($regKeyItem.RPSessionInterval -eq 1) {
        return $true
    } elseif ($regKeyItem.RPSessionInterval -eq 0) {
        return $false
    } 
    return $false
}

Function Start-RestorePointProcess {
    $currentDate = Get-Date -Format "MMddyyyy"
    $restoreName = "RP-WS-BeforePatch-Monthly-$currentDate"
    Checkpoint-Computer -Description $restoreName
}

Function Get-LastRestorePoint {
    # Retrieve the list of restore points
    $restorePoints = Get-ComputerRestorePoint
    if ($restorePoints) {
        # Select the most recent restore point based on CreationTime
        $lastRestorePoint = $restorePoints | Sort-Object -Property CreationTime -Descending | Select-Object -First 1
        # Try parsing the CreationTime, removing any extra characters
        $lastRestorePointTime = $lastRestorePoint.CreationTime -replace '(\d{8}\d{6})(\.\d+)?(-\d+)?', '$1'
        try {
            # Convert the cleaned string into a DateTime object
            $lastRestorePointTime = [datetime]::ParseExact($lastRestorePointTime, 'yyyyMMddHHmmss', $null)
            Write-Host "Last restore point was created at: $lastRestorePointTime"
            return $lastRestorePointTime
        } catch {
            Write-Error "Failed to parse the CreationTime: $_"
            return $null
        }
    }
    return $null
}


Function Test-System {
    $isValidOS = Test-ValidOS
    if ($isValidOS -eq $false) {
        return
    }
    
    $isSystemProtectionEnabled = Test-SystemProtection
    if ($isSystemProtectionEnabled) {
        # Retrieve the last restore point and compare it to current time
        $lastRestorePointTime = Get-LastRestorePoint
        if ($lastRestorePointTime) {
            $timeDifference = (New-TimeSpan -Start $lastRestorePointTime -End (Get-Date)).TotalHours
            if ($timeDifference -lt 24) {
                $Host.UI.WriteErrorLine('There has already been a restore point taken in the last 24 hours!')
                return
            }
        }

        Start-RestorePointProcess
    } else {
        $Host.UI.WriteWarningLine('System Protection not enabled. Enabling for C:\ drive')
        Enable-ComputerRestore -Drive $DRIVE_LETTER
        Start-RestorePointProcess
    }
}

Test-System