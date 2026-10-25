<#
.SYNOPSIS
Builds the lab's organisational units, groups and users from a CSV file.

.DESCRIPTION
Creates five department OUs (IT, HR, Finance, Sales, Operations), each with Users,
Groups and Workstations sub-OUs, a GG-<Department> security group in each Groups OU,
and a top-level Admins OU. Users in the CSV are created in their department's Users
OU and added to their department group. Rows marked IsAdmin also get a separate
adm-<name> account in the Admins OU, added to GG-IT-Admins.

Each password is random, 16 characters, and is never printed. All passwords are
written to one CSV file on this machine (default C:\LabSecrets), readable by
Administrators and SYSTEM only. Do not copy that file into the repository.

The script is safe to run again: OUs, groups and users that already exist are skipped.
Run it in an elevated PowerShell on the domain controller.

.PARAMETER CsvPath
Path to the user list (scripts\data\users.csv).

.PARAMETER Count
Use only the first N rows. The CSV is ordered so that any prefix has a mix of
departments. 0 (the default) uses every row.

.PARAMETER PasswordDir
Folder for the generated passwords file.

.PARAMETER DryRun
Show what would be created without changing anything.

.EXAMPLE
.\New-LabUsers.ps1 -CsvPath C:\Lab\users.csv -Count 10 -DryRun

.EXAMPLE
.\New-LabUsers.ps1 -CsvPath C:\Lab\users.csv -Count 10

.EXAMPLE
.\New-LabUsers.ps1 -CsvPath C:\Lab\users.csv
#>
[CmdletBinding()]
param(
    [string]$CsvPath = 'C:\Lab\users.csv',
    [int]$Count = 0,
    [string]$PasswordDir = 'C:\LabSecrets',
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$domainDn    = (Get-ADDomain).DistinguishedName
$departments = @('IT', 'HR', 'Finance', 'Sales', 'Operations')
$subOus      = @('Users', 'Groups', 'Workstations')
$requiredCols = @('GivenName', 'Surname', 'DisplayName', 'SamAccountName',
                  'UserPrincipalName', 'Department', 'Title', 'IsAdmin')

$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

function Get-SecureRandomInt {
    param([int]$Max)
    # Rejection sampling, so every value from 0 to Max-1 is equally likely.
    $bytes = New-Object byte[] 4
    $span  = [uint64]4294967296
    $limit = $span - ($span % [uint64]$Max)
    do {
        $rng.GetBytes($bytes)
        $value = [uint64][BitConverter]::ToUInt32($bytes, 0)
    } while ($value -ge $limit)
    return [int]($value % [uint64]$Max)
}

function New-RandomPassword {
    param([int]$Length = 16)
    $sets = @('ABCDEFGHJKLMNPQRSTUVWXYZ', 'abcdefghijkmnopqrstuvwxyz', '23456789', '!@#$%^&*-_=+')
    $all  = $sets -join ''
    $chars = New-Object System.Collections.Generic.List[char]
    foreach ($set in $sets) {
        $chars.Add($set[(Get-SecureRandomInt -Max $set.Length)])
    }
    while ($chars.Count -lt $Length) {
        $chars.Add($all[(Get-SecureRandomInt -Max $all.Length)])
    }
    # Fisher-Yates shuffle, so the guaranteed characters are not always first.
    for ($i = $chars.Count - 1; $i -gt 0; $i--) {
        $j = Get-SecureRandomInt -Max ($i + 1)
        $tmp = $chars[$i]; $chars[$i] = $chars[$j]; $chars[$j] = $tmp
    }
    return -join $chars
}

function Test-OuExists {
    param([string]$Name, [string]$Path)
    try {
        return $null -ne (Get-ADOrganizationalUnit -Filter "Name -eq '$Name'" -SearchBase $Path -SearchScope OneLevel)
    } catch {
        return $false
    }
}

function Test-GroupExists {
    param([string]$Name)
    try {
        return $null -ne (Get-ADGroup -Filter "Name -eq '$Name'")
    } catch {
        return $false
    }
}

function Test-UserExists {
    param([string]$Sam)
    return $null -ne (Get-ADUser -Filter "SamAccountName -eq '$Sam'")
}

function Initialize-LabOu {
    param([string]$Name, [string]$Path)
    if (Test-OuExists -Name $Name -Path $Path) { return }
    if ($DryRun) { Write-Host "[dry run] create OU $Name in $Path"; return }
    # Protection from accidental deletion stays on (the default).
    New-ADOrganizationalUnit -Name $Name -Path $Path
    Write-Host "Created OU $Name in $Path"
}

function Initialize-LabGroup {
    param([string]$Name, [string]$Path)
    if (Test-GroupExists -Name $Name) { return }
    if ($DryRun) { Write-Host "[dry run] create group $Name in $Path"; return }
    New-ADGroup -Name $Name -GroupScope Global -GroupCategory Security -Path $Path
    Write-Host "Created group $Name"
}

# --- Read and check the CSV --------------------------------------------------
if (-not (Test-Path -LiteralPath $CsvPath)) { throw "CSV not found: $CsvPath" }
$rows = @(Import-Csv -LiteralPath $CsvPath)
if ($rows.Count -eq 0) { throw "The CSV has no rows." }
$missing = $requiredCols | Where-Object { $rows[0].PSObject.Properties.Name -notcontains $_ }
if ($missing) { throw "The CSV is missing columns: $($missing -join ', ')" }
if ($Count -gt 0 -and $Count -lt $rows.Count) { $rows = @($rows | Select-Object -First $Count) }
Write-Host "Domain: $domainDn"
Write-Host "Users to process: $($rows.Count)"
if ($DryRun) { Write-Host "DRY RUN: nothing will be changed." }

# --- OUs and groups ----------------------------------------------------------
foreach ($dept in $departments) {
    Initialize-LabOu -Name $dept -Path $domainDn
    foreach ($sub in $subOus) {
        Initialize-LabOu -Name $sub -Path "OU=$dept,$domainDn"
    }
    Initialize-LabGroup -Name "GG-$dept" -Path "OU=Groups,OU=$dept,$domainDn"
}
Initialize-LabOu -Name 'Admins' -Path $domainDn
Initialize-LabGroup -Name 'GG-IT-Admins' -Path "OU=Admins,$domainDn"

# --- Users -------------------------------------------------------------------
$created  = 0
$skipped  = 0
$failed   = 0
$passwords = New-Object System.Collections.Generic.List[object]

function New-LabAccount {
    param(
        [string]$Sam, [string]$GivenName, [string]$Surname, [string]$DisplayName,
        [string]$Upn, [string]$Department, [string]$Title, [string]$Path,
        [string]$Description, [string]$Group
    )
    if (Test-UserExists -Sam $Sam) {
        $script:skipped++
        Write-Host "Skipped (already exists): $Sam"
        return
    }
    if ($DryRun) {
        Write-Host "[dry run] create user $Sam in $Path, group $Group"
        return
    }
    $password = New-RandomPassword
    try {
        $params = @{
            Name                  = $DisplayName
            GivenName             = $GivenName
            Surname               = $Surname
            DisplayName           = $DisplayName
            SamAccountName        = $Sam
            UserPrincipalName     = $Upn
            Department            = $Department
            Title                 = $Title
            Path                  = $Path
            AccountPassword       = (ConvertTo-SecureString -String $password -AsPlainText -Force)
            Enabled               = $true
            ChangePasswordAtLogon = $false
        }
        if ($Description) { $params['Description'] = $Description }
        New-ADUser @params
        Add-ADGroupMember -Identity $Group -Members $Sam
        $script:passwords.Add([pscustomobject]@{ SamAccountName = $Sam; Password = $password })
        $script:created++
    } catch {
        $script:failed++
        Write-Warning "Failed for ${Sam}: $($_.Exception.Message)"
    }
}

foreach ($row in $rows) {
    $dept = $row.Department
    if ($departments -notcontains $dept) {
        $failed++
        Write-Warning "Unknown department '$dept' for $($row.SamAccountName)"
        continue
    }
    New-LabAccount -Sam $row.SamAccountName -GivenName $row.GivenName -Surname $row.Surname `
        -DisplayName $row.DisplayName -Upn $row.UserPrincipalName -Department $dept `
        -Title $row.Title -Path "OU=Users,OU=$dept,$domainDn" -Description '' -Group "GG-$dept"

    if ($row.IsAdmin -eq 'Yes') {
        $adminSam = ('adm-' + $row.GivenName.Substring(0, 1) + $row.Surname).ToLower()
        if ($adminSam.Length -gt 20) { $adminSam = $adminSam.Substring(0, 20) }
        New-LabAccount -Sam $adminSam -GivenName $row.GivenName -Surname $row.Surname `
            -DisplayName "$($row.DisplayName) (Admin)" -Upn "$adminSam@lab.internal" `
            -Department $dept -Title 'Administrator account' -Path "OU=Admins,$domainDn" `
            -Description "Admin account for $($row.SamAccountName)" -Group 'GG-IT-Admins'
    }
}

# --- Passwords file (not part of the repository) -----------------------------
if ($passwords.Count -gt 0) {
    if (-not (Test-Path -LiteralPath $PasswordDir)) {
        New-Item -ItemType Directory -Path $PasswordDir | Out-Null
    }
    & icacls.exe $PasswordDir /inheritance:r /grant:r 'Administrators:(OI)(CI)F' 'SYSTEM:(OI)(CI)F' | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Warning "icacls failed on $PasswordDir (exit code $LASTEXITCODE). Check the folder permissions." }
    $file = Join-Path $PasswordDir ("initial-passwords-{0:yyyyMMdd-HHmmss}.csv" -f (Get-Date))
    $passwords | Export-Csv -LiteralPath $file -NoTypeInformation -Encoding ASCII
    Write-Host "Passwords written to $file (Administrators and SYSTEM only)"
}

Write-Host ""
Write-Host "Created: $created   Skipped: $skipped   Failed: $failed"
if ($failed -gt 0) { Write-Warning "Some accounts failed. Read the warnings above." }
