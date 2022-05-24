# download the scoop installer
iwr -useb get.scoop.sh -outfile 'install_scoop.ps1'

# add -RunAsAdmin if you *must* run as Administrator
.\install_scoop.ps1

# remove the scoop installer
Remove-Item .\install_scoop.ps1

# bootstrap bare minimum (let msys and/or development_setup.sh do the rest)
scoop install main/msys2 main/git main/ln

# enable permission to create symlinks
# from https://dbondarchuk.com/2016/09/23/adding-permission-for-creating-symlink-using-powershell/

function addSymLinkPermissions($accountToAdd) {
    Write-Host "Checking symlink permissions ..."
    $sidstr = $null
    try {
        $ntprincipal = new-object System.Security.Principal.NTAccount "$accountToAdd"
        $sid = $ntprincipal.Translate([System.Security.Principal.SecurityIdentifier])
        $sidstr = $sid.Value.ToString()
    } catch {
        $sidstr = $null
    }
    Write-Host "Account: $($accountToAdd)" -ForegroundColor DarkCyan
    if ([string]::IsNullOrEmpty($sidstr)) {
        Write-Host "Account not found!" -ForegroundColor Red
        exit -1
    }
    Write-Host "Account SID: $($sidstr)" -ForegroundColor DarkCyan

    $tmp = [System.IO.Path]::GetTempFileName()
    Write-Host "Exporting current Local Security Policy ..." -ForegroundColor DarkCyan
    secedit.exe /export /cfg "$($tmp)"
    $c = Get-Content -Path $tmp
    $currentSetting = ""
    foreach ($s in $c) {
        if ($s -like "SECreateSymbolicLinkPrivilege*") {
            $x = $s.split("=",[System.StringSplitOptions]::RemoveEmptyEntries)
            $currentSetting = $x[1].Trim()
        }
    }

    if ($currentSetting -notlike "*$($sidstr)*") {
        Write-Host "Need to add symlink permissions" -ForegroundColor Yellow
        Write-Host "Modify setting ""Create SymLink""" -ForegroundColor DarkCyan

        if ([string]::IsNullOrEmpty($currentSetting)) {
            $currentSetting = "*$($sidstr)"
        } else {
            $currentSetting = "*$($sidstr),$($currentSetting)"
        }
        Write-Host "$currentSetting"

    $outfile = @"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[Privilege Rights]
SECreateSymbolicLinkPrivilege = $($currentSetting)
"@
    $tmp2 = [System.IO.Path]::GetTempFileName()
        Write-Host "Importing new settings to Local Security Policy ..." -ForegroundColor DarkCyan
        $outfile | Set-Content -Path $tmp2 -Encoding Unicode -Force
        Push-Location (Split-Path $tmp2)
        try {
            secedit.exe /configure /db "secedit.sdb" /cfg "$($tmp2)" /areas USER_RIGHTS
        } finally {
            Pop-Location
        }

    } else {
        Write-Host "NO ACTION REQUIRED!" -ForegroundColor DarkCyan
        Write-Host "Account $accountToAdd already has symlink permissions" -ForegroundColor Green
        return $true;
    }
}

addSymLinkPermissions $ENV:USERNAME