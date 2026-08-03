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

```powershell
mkdir C:\Scripts\
cd C:\Scripts\
git clone https://github.com/mmnps/PwdExpiry
```

Then fill in `Settings\config.psd1` with your own values (see below).

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

```powershell
.\PwdExpiry.ps1
```

For regular operation, a daily task in Windows Task Scheduler is recommended.


## Project structure

```
PwdExpiry.ps1                  Main script
Functions/
  Microsoft-Graph.ps1          Token acquisition & mail sending via Graph
  Mail-Body.ps1                HTML template for the notification email
  Write-Log.ps1                Logging function
Settings/
  config.psd1                  Configuration
```

## Security notes

- `Settings/config.psd1` may contain secrets (client secret) — check before committing that no real values are present.
- Grant the app registration only the minimally required permission (`Mail.Send`).
- Prefer providing the client secret via the `PWEXPIRE_CLIENT_SECRET` environment variable instead of the configuration file.
