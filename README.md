# PwdExpiry

PowerShell script that finds Active Directory users whose password is about to expire and notifies them by email via Microsoft Graph.

## How it works

1. Loads the configuration from `Settings/config.psd1`.
2. Obtains a Microsoft Graph access token via the client-credentials flow.
3. Queries all enabled AD users whose password is not set to "never expires" and is not already expired.
4. Calculates each user's expiry date based on the fine-grained (or domain) password policy.
5. Sends an HTML email via Graph (`sendMail`) to users whose password expires within `ExpireDays`.
6. Writes log entries and cleans up old log files.

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
```

Then fill in `Settings\config.psd1` with your own values (see below). This file is excluded from version control via `.gitignore`, so it is never touched by `git pull`.

## Update

Update the script using the following commands:

```powershell
cd C:\Scripts\PwdExpiry
git pull
```

Since `Settings\config.psd1` is not tracked by Git, your local settings are preserved. If a future version changes `config.psd1.example` (e.g. adds a new setting), compare it against your local `config.psd1` and add the new key manually.

## Configuration (`Settings/config.psd1`)

| Key                            | Description                                                                 |
|---------------------------------|-------------------------------------------------------------------------------|
| `ExpireDays`                    | Number of days before expiry at which the notification is sent               |
| `MailConfig.TenantId`           | Azure AD tenant ID                                                           |
| `MailConfig.ClientId`           | App registration (client) ID                                                 |
| `MailConfig.ClientSecret`       | App registration client secret (optional, see below)                        |
| `MailConfig.FromUser`           | Sender mailbox, e.g. `support@company.com`                                  |
| `LogConfig.EnableLogging`       | Enable logging (`$true`/`$false`)                                            |
| `LogConfig.LogPath`             | Directory for log files (blank = a `Logs` folder next to the script)         |
| `LogConfig.KeepLogsDays`        | Number of days after which log files are deleted                            |

### Client secret without plaintext in the file

Instead of entering the secret in `config.psd1`, it can be set as an environment variable:

```powershell
[Environment]::SetEnvironmentVariable("PWEXPIRE_CLIENT_SECRET", "XXX", "Machine")
```

The script automatically uses `$env:PWEXPIRE_CLIENT_SECRET` if `MailConfig.ClientSecret` is empty. This is the recommended approach for production environments.

## Usage

For regular operation, a daily task in Windows Task Scheduler is recommended.

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\PwdExpiry\PwdExpiry.ps1"'
$trigger = New-ScheduledTaskTrigger -Daily -At 8:00AM
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "PwdExpiryCheck" -Action $action -Trigger $trigger -Settings $settings -Principal $principal
```
Adjust these settings if needed.

## Project structure

```
PwdExpiry.ps1                  Main script
Functions/
  Microsoft-Graph.ps1          Token acquisition & mail sending via Graph
  Mail-Body.ps1                HTML template for the notification email
  Write-Log.ps1                Logging function
Settings/
  config.psd1.example          Configuration template (no secrets, tracked by Git)
  config.psd1                  Local configuration (ignored by Git)
```

## Security notes

- `Settings/config.psd1` is excluded from version control via `.gitignore` because it can contain secrets (client secret). Only `config.psd1.example` (without real values) is committed.
- Grant the app registration only the minimally required permission (`Mail.Send`).
- Prefer providing the client secret via the `PWEXPIRE_CLIENT_SECRET` environment variable instead of the configuration file.
