<#
.SYNOPSIS
This script disables an Active Directory user account by removing it from all non-ignored AD groups and moving it to a designated "Disabled" Organizational Unit (OU).

.DESCRIPTION
The script performs the following actions:
1. Prompts the administrator to input a username.
2. Searches Active Directory for the specified username.
3. Retrieves all AD groups the user is a member of.
4. Removes the user from all groups, except those specified in the `$IGNORED_AD_GROUP` array (e.g., "Domain Users").
5. Disables the user's account in Active Directory.
6. Moves the disabled user account to a predefined "Disabled" OU (`$DISABLED_OU`).

.PARAMETER $DISABLED_OU
Specifies the Distinguished Name (DN) of the OU where disabled users will be moved. Must be set prior to running the script.

.PARAMETER $IGNORED_AD_GROUP
Defines a list of AD groups that the user will not be removed from during the group removal process.
- Default is Domain Users.

.NOTES
- This script requires the Active Directory PowerShell module to be installed and imported.
- Ensure the script is executed with appropriate permissions to manage AD user accounts and groups.
- The `$DISABLED_OU` variable must be set with the target OU's DN for the script to work correctly.
#>

$DISABLED_OU = ""
$IGNORED_AD_GROUP = @("Domain Users")

Function Read-UsernameInput {
    $username = Read-Host -Prompt "Please enter the username to disable "

    if ([string]::IsNullOrWhiteSpace(($username))) {
        Write-Host "Could not read username: $username" -ForegroundColor RED
        return $null
    }

    return $username
}

Function Get-TargetADUser {
    param(
        [string]$username
    )

    Import-Module ActiveDirectory
    $user = Get-ADUser -Identity $username
    if ($null -eq $user) {
        Write-Host "Could not find user with username: $username" -ForegroundColor RED
        return $null
    }

    Write-Host "User: $username found! Continuing disable process." -ForegroundColor GREEN
    return $user
}

Function Invoke-GroupRemoval {
    param(
        [Microsoft.ActiveDirectory.Management.ADUser]$user
    )

    $groups = Get-ADPrincipalGroupMembership -Identity $user.SamAccountName
    if ($groups.Count -le 0) {
        Write-Host "$($user.SamAccountName) is in 0 groups. Proceeding with disabling." -ForegroundColor Green
        Invoke-UserDisable -user $user
        return
    }

    foreach ($group in $groups) {
        $groupName = $group.Name
        if ($IGNORED_AD_GROUP -contains $groupName) {
            Write-Host "Skipping Group: $groupName (ignored)" -ForegroundColor Cyan
            continue
        }

        Write-Host "Removing Group: $groupName" -ForegroundColor Yellow
        Remove-ADGroupMember -Identity $group -Members $user -Confirm:$false
    }

    Invoke-UserDisable -user $user
}

Function Invoke-UserDisable {
    param(
        [Microsoft.ActiveDirectory.Management.ADUser]$user
    )

    Write-Host "Disabling User: $($user.SamAccountName)" -ForegroundColor Yellow
    Set-ADUser -Identity $user -Enabled $false

    Write-Host "Moving user to disabled OU: $DISABLED_OU" -ForegroundColor Yellow
    Move-ADObject -Identity $user.DistinguishedName -TargetPath $DISABLED_OU
}

Function Start-DisableProcess {
    $username = Read-UsernameInput
    if ($null -eq $username) {
        Write-Host "Could not read username." -ForegroundColor Red
        return
    }
    
    $user = Get-TargetADUser -username $username
    if ($null -eq $user) {
        Write-Host "Could not find AD User." -ForegroundColor RED
        return
    }
    
    Invoke-GroupRemoval -user $user
}

Start-DisableProcess


