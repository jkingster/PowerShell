Write-Host "Finding Administrators..."

$adminList = @()

Get-LocalGroupMember -Group "Administrators" | Select-Object -ExpandProperty Name | ForEach-Object {
    $adminList += $_
}

$result = $adminList -join ", "

Write-Host "Found Administrator(s): $result"