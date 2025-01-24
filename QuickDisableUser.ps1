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


