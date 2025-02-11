$TARGET_OU = ""

$credential = Get-Credential 

$computers = Get-ADComputer -SearchBase $TARGET_OU -Filter * | Select-Object Name

if ($computers.Count -le 0) {
    Write-Host -ForegroundColor Red "No workstations found in target OU: $TARGET_OU"
    return
}

foreach ($computer in $computers) {
   try {
    $session = New-PSSession -ComputerName $computer.Name -Credential $credential
    if (-Not($session) -and $session.State -ne 'Opened') {
        Write-Host -ForegroundColor Yellow "Could not establish PS-Remote Session: $($computer.Name)"
        continue
    }

    Write-Host -ForegroundColor Green "PS-Remote Session Established: $($computer.Name)"
    Write-Host -ForegroundColor Yellow "Beginning Local Administrator Checks... $($computer.Name)"
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
    
    Remove-PSSession $session
   } catch {
    Write-Host -ForegroundColor Red "Could not esatblish PS-Session with $($computer.Name) ($_)"
   }
}

Write-Host "Local Admin Removal Completed..."
