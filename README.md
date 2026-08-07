# PwdExpiry

PowerShell script that finds Active Directory users whose password is about to expire and notifies them by email via Microsoft Graph.

## Requirements

- Windows with PowerShell 5.1 or higher
- RSAT module `ActiveDirectory` (`Install-WindowsFeature RSAT-AD-PowerShell`)
- The `EmailAddress` attribute must be populated in AD
- Azure AD app registration with the application permission **`Mail.Send`** (admin consent granted) for Microsoft Graph
- Network access to `login.microsoftonline.com` and `graph.microsoft.com`

## Installation

If git isn't insalled, install is using:

```powershell
winget install --id Git.Git -e --source winget
```

Start a new powershell and execute the following commands:

```powershell
mkdir C:\Scripts\
cd C:\Scripts\
git clone --depth 1 https://github.com/mmnps/PwdExpiry
cd PwdExpiry
Copy-Item .\Settings\config.psd1.example .\Settings\config.psd1
Copy-Item .\Settings\Template.html.example .\Settings\Template.html
```

Then fill in `Settings\config.psd1` with your own values (see below). This file is excluded from version control via `.gitignore`, so it is never touched by `git pull`. 

You can add a custom HTML template by editing the `Settings\Template.html`.

## Update

Update the script using the following commands:

```powershell
cd C:\Scripts\PwdExpiry
git pull
```

Since `Settings\config.psd1` is not tracked by Git, your local settings are preserved. If a future version changes `config.psd1.example` (e.g. adds a new setting), compare it against your local `config.psd1` and add the new key manually.

## Configuration (`Settings/config.psd1`)

| Key                             | Description                                                                 |
|---------------------------------|-----------------------------------------------------------------------------|
| `ExpireDays`                    | Number of days before expiry at which the notification is sent              |
| `MailConfig.TenantId`           | Azure AD tenant ID                                                          |
| `MailConfig.ClientId`           | App registration (client) ID                                                |
| `MailConfig.ClientSecret`       | App registration client secret (optional, see below)                        |
| `MailConfig.FromUser`           | Sender mailbox, e.g. `support@company.com`                                  |
| `LogConfig.EnableLogging`       | Enable logging (`$true`/`$false`)                                           |
| `LogConfig.LogPath`             | Directory for log files (blank = a `Logs` folder next to the script)        |
| `LogConfig.DeleteLogs`          | Delete log files automatically (`$true`/`$false`)                           |
| `LogConfig.KeepLogsDays`        | Number of days after which log files are deleted                            |

### Client secret without plaintext in the file

Instead of entering the secret in `config.psd1`, it can be set as an environment variable:

```powershell
[Environment]::SetEnvironmentVariable("PWEXPIRE_CLIENT_SECRET", "XXX", "Machine")
```

The script automatically uses `$env:PWEXPIRE_CLIENT_SECRET` if `MailConfig.ClientSecret` is empty. This is the recommended approach for production environments.

## Usage

For regular operation, a daily task in Windows Task Scheduler is recommended.
Create the task using the windows task scheduler or run this powershell commands as administrator:

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\PwdExpiry\PwdExpiry.ps1"'
$trigger = New-ScheduledTaskTrigger -Daily -At 8:00AM
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$cred = Get-Credential
Register-ScheduledTask -TaskName "PwdExpiryCheck" -Action $action -Trigger $trigger -Settings $settings -User $cred.UserName -Password $cred.GetNetworkCredential().Password -RunLevel Highest
```
Adjust these settings in the windows task scheduler if needed.


## Security notes

- `Settings/config.psd1` is excluded from version control via `.gitignore` because it can contain secrets (client secret). Only `config.psd1.example` (without real values) is committed.
- Grant the app registration only the minimally required permission (`Mail.Send`).
- Prefer providing the client secret via the `PWEXPIRE_CLIENT_SECRET` environment variable instead of the configuration file.


## Changelog

### 07.08.2026

Added a function to automatically delete the log files.

### 03.08.2026

Users can now create their own mail template by editing the Template.html in the Settings folder.