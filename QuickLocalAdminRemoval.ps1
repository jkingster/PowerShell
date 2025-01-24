<#
.SYNOPSIS
This script removes local administrators from the "Administrators" group on a specified computer via PowerShell remoting (PS-Remote).

.DESCRIPTION
- Prompts the user to input a computer name.
- Establishes a remote PowerShell session to the specified computer using the provided credentials.
- Retrieves all members of the "Administrators" group on the target computer.
- Removes all administrators except those explicitly listed in the `$ignoredAdministrators` variable.
- Skips built-in accounts like "Administrator" for safety.

.PARAMETERS
$ignoredAdministrators
- An array of account names or groups that should be excluded from removal.
- This is defined within the scriptblock executed remotely on the target computer.

$CREDENTIAL_USERNAME
- Specifies the username to authenticate the remote session.
- The user must have local administrator privileges on the target computer.

.NOTES
- Ensure PowerShell remoting (WinRM) is configured and enabled on the target machine.
- The appropriate firewall rules must be in place to allow PS-Remote communication.
- This script requires sufficient permissions to modify group membership on the target machine.

.EXAMPLE
# Run the script
Start-RemovalProcess

# Enter the computer name when prompted to initiate the admin removal process.
# The `$ignoredAdministrators` array determines which accounts/groups are excluded from removal.
# Ensure `$CREDENTIAL_USERNAME` is set to a user with local administrator privileges on the target machine.
#>
$CREDENTIAL_USERNAME = ""

Function Read-ComputerName {
    $computerName = Read-Host -Prompt "Please enter the computer name for ps-remote"

    if ([string]::IsNullOrWhiteSpace($computerName)) {
        return $null
    }

    return $computerName
}

Function Invoke-PSSession {
    param(
        [string]$computerName,
        [PSCustomObject]$credential
    )

    $session = New-PSSession -ComputerName $computerName -Credential $credential
    if ($session -and $session.State -eq 'Opened') {
        return $session
    }

    return $null
}

Function Invoke-LocalAdminRemoval {
    param(
        [PSCustomObject]$session,
        [Array]$ignoredAdmins
    )

    if ($null -eq $session) {
        Write-Host "Could not start PS-Remote session with $($session.ComputerName)" -ForegroundColor Red
        return
    }

    Write-Host "Invoking Command Script Block..."
    Invoke-Command -Session $session -ScriptBlock {
        $ignoredAdministrators = @("Domain Admins", "Administrator") # This needs to be set here for the PS-remote hop.
    
        $administrators = Get-LocalGroupMember -Group "Administrators" | Select-Object -ExpandProperty Name
    
        if ($administrators.Count -le 0) {
            Write-Host "There are no objects under the Administrators group for this computer: $env:ComputerName" -ForegroundColor Yellow
            return
        }
    
        foreach ($administrator in $administrators) {
            # Normalize name
            $adminName = $administrator -replace '^.*\\', ''  # Remove domain or workgroup prefix
    
            # Skip ignored accounts
            if ($ignoredAdministrators -contains $adminName) {
                Write-Host "Ignoring Group: $($adminName)" -ForegroundColor Yellow
                continue
            }
    
            # Skip built-in accounts
            if ($adminName -eq 'Administrator') {
                Write-Host "Skipping built-in account: Administrator" -ForegroundColor Yellow
                continue
            }
    
            Write-Host "Removing Group: $($adminName)" -ForegroundColor Red
            Remove-LocalGroupMember -Group "Administrators" -Member $administrator
        }
    } 
}

Function Start-RemovalProcess {
    Write-Host "Reading Input Computer Name..."
    $computerName = Read-ComputerName

    Write-Host "Attempting to establish PS-Remote session.."
    $session = Invoke-PSSession -computerName $computerName -credential $CREDENTIAL_USERNAME
    
    Write-Host "Invoking Local Admin Removal Process..."
    Invoke-LocalAdminRemoval -session $session -ignoredAdmins $IGNORED_ADMINISTRATORS
}

Start-RemovalProcess