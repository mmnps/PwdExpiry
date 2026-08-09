<#
.SYNOPSIS
    Sends an email notification via Microsoft Graph when an Active Directory user's password is about to expire.

.DESCRIPTION
    The script retrieves all Active Directory users and checks whether their passwords are about to expire. 
    If so, an email is sent to the user via the Graph API.

.NOTES
    Version:        2.0
    Last Update:    09.08.2026
    Author:         https://github.com/mmnps
    Requirements:   Powershell version 5.1 or higher, PowerShell Active Directory module
#>

#Requires -Version 5.1

#########################
###   Configuration   ###
#########################
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Load config from config.psd1
$Config = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot 'Settings\config.psd1')

$ExpireDays =   $Config.ExpireDays

# Mail config
$TenantId =     $Config.MailConfig.TenantId
$ClientId =     $Config.MailConfig.ClientId
$ClientSecret = if ($Config.MailConfig.ClientSecret) { $Config.MailConfig.ClientSecret } else { $env:PWEXPIRE_CLIENT_SECRET }
$FromUser =     $Config.MailConfig.FromUser
$NotifyAdmin =  $Config.MailConfig.NotifyAdmin
$AdminMail =    $Config.MailConfig.AdminMail

# Log config
$EnableLogging = $Config.LogConfig.EnableLogging
$LogPath =       $Config.LogConfig.LogPath
$KeepLogsDays =  $Config.LogConfig.KeepLogsDays
$DeleteLogs =    $Config.LogConfig.DeleteLogs
$LogName =       "$(Get-Date -Format 'yyyy-MM-dd').log"


########################
###   Check config   ###
########################
$MissingSettings = @()
if (-not $ExpireDays)   { $MissingSettings += 'ExpireDays' }
if (-not $TenantId)     { $MissingSettings += 'MailConfig.TenantId' }
if (-not $ClientId)     { $MissingSettings += 'MailConfig.ClientId' }
if (-not $ClientSecret) { $MissingSettings += 'MailConfig.ClientSecret (or $env:PWEXPIRE_CLIENT_SECRET)' }
if (-not $FromUser)     { $MissingSettings += 'MailConfig.FromUser' }

if ($MissingSettings.Count -gt 0) {
    Write-Error "Missing required configuration value(s): $($MissingSettings -join ', ')"
    exit 1
}

if (-not $LogPath) {
    $LogPath = Join-Path $PSScriptRoot "Logs"
}
if (-not $KeepLogsDays) {
    $KeepLogsDays = 14
}

$LogFile = Join-Path $LogPath $LogName

if ($EnableLogging -and -not (Test-Path -Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

#####################
###   Functions   ###
#####################
. "$PSScriptRoot\Functions\Write-Log.ps1"
. "$PSScriptRoot\Functions\Microsoft-Graph.ps1"
. "$PSScriptRoot\Functions\UserMail-Body.ps1"
. "$PSScriptRoot\Functions\AdminMail-Body.ps1"


########################################
###   Check Active Directory module  ###
########################################
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Log -Level ERROR -Text 'The Active Directory module is not installed.' -ToConsole
    Write-Log -Level INFO -Text 'Install it using: Install-WindowsFeature RSAT-AD-PowerShell' -ToConsole
    exit 1
}

Import-Module ActiveDirectory


##############################
###   Graph access token   ###
##############################
try {
    Write-Log -Level INFO -Text 'Requesting Microsoft Graph access token...' -ToConsole
    $AccessToken = Get-GraphAccessToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret
    $TokenAcquiredAt = Get-Date
}
catch {
    Write-Log -Level ERROR -Text "Failed to obtain Graph access token: $($_.Exception.Message)" -ToConsole
    exit 1
}


####################################
###   Active Directory request   ###    
####################################
Write-Log -Level INFO -Text 'Getting users...' -ToConsole

try {
    $Users = Get-ADUser -Properties Name, PasswordNeverExpires, PasswordExpired, PasswordLastSet, EmailAddress `
        -Filter { (Enabled -eq $true) -and (PasswordNeverExpires -eq $false) -and (PasswordExpired -eq $false) }
}
catch {
    Write-Log -Level ERROR -Text "Failed to query Active Directory: $($_.Exception.Message)" -ToConsole
    exit 1
}

try {
    $DefaultMaxPasswordAge = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge
}
catch {
    Write-Log -Level ERROR -Text "An error occured while loading the domain password policy: $($_.Exception.Message)"
    exit 1
}


############################
###   Processing users   ###
############################
$SentCount = 0
$SkipCount = 0
$ErrorCount = 0

foreach ($User in $Users) {
    $Name = $User.Name
    $MailAddress = $User.EmailAddress

    if (-not $MailAddress) {
        Write-Log -Level WARN -Text "No email address found for '$Name', skipping."
        $SkipCount++
        continue
    }

    $PasswordSetDate = $User.PasswordLastSet
    if (-not $PasswordSetDate) {
        Write-Log -Level WARN -Text "No PasswordLastSet found for '$Name', skipping."
        $SkipCount++
        continue
    }

    $MaxPasswordAge = $DefaultMaxPasswordAge
    try {
        $PasswordPolicy = Get-ADUserResultantPasswordPolicy -Identity $User
        if ($PasswordPolicy) {
            $MaxPasswordAge = $PasswordPolicy.MaxPasswordAge
        }
    }
    catch {
        Write-Log -Level WARN -Text "Could not resolve resultant password policy for '$Name', using domain default. $($_.Exception.Message)"
    }

    $ExpireDate = $PasswordSetDate + $MaxPasswordAge
    $DayToExpire = (New-TimeSpan -Start (Get-Date) -End $ExpireDate).Days

    if (($DayToExpire -ge 0) -and ($DayToExpire -lt $ExpireDays)) {
        try {
            if ((New-TimeSpan -Start $TokenAcquiredAt -End (Get-Date)).TotalMinutes -ge 50) {
                Write-Log -Level INFO -Text 'Refreshing Microsoft Graph access token...'
                $AccessToken = Get-GraphAccessToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret
                $TokenAcquiredAt = Get-Date
            }

            $MailBodyHtml = New-ExpiryMailBody -Name $Name -DaysToExpire $DayToExpire -TemplatePath "$PSScriptRoot\Settings\UserTemplate.html"
            Send-GraphMail -AccessToken $AccessToken -FromUser $FromUser -ToUser $MailAddress -Subject "Your password is going to expire in $DayToExpire day(s)" -BodyHtml $MailBodyHtml

            Write-Log -Level INFO -Text "Sent expiry notice to '$Name' ($MailAddress), $DayToExpire day(s) left." -ToConsole
            $SentCount++
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            try {
                if ($NotifyAdmin -and $AdminMail) {
                    $AccessToken = Get-GraphAccessToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret
                    $MailBodyHtml = New-AdminNotification -Name $Name -ErrorMessage $ErrorMessage -TemplatePath "$PSScriptRoot\Settings\AdminTemplate.html"
                    Send-GraphMail -AccessToken $AccessToken -FromUser $FromUser -ToUser $AdminMail -Subject "Failed to send expiry mail to '$Name'!" -BodyHtml $MailBodyHtml
                }
            }
            catch {
                Write-Log -Level ERROR -Text "An error occured while sending the admin notification: $($_.Exception.Message)"
            }

            Write-Log -Level ERROR -Text "Failed to send expiry mail to '$Name' ($MailAddress): $ErrorMessage" -ToConsole
            $ErrorCount++
        }
    }
    else {
        Write-Log -Level INFO -Text "Password for '$Name' not expiring soon ($DayToExpire day(s))."
    }
}

Write-Log -Level INFO -Text "Done. Sent: $SentCount, Skipped: $SkipCount, Errors: $ErrorCount" -ToConsole

if ($ErrorCount -gt 0) {
    exit 1
}

########################
###   Cleanup logs   ###
########################
if ($DeleteLogs -and (Test-Path -Path $LogPath)) {
    Get-ChildItem -Path $LogPath -Filter '*.log' -File | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$KeepLogsDays) } | Remove-Item -Force
}
