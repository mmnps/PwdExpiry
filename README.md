# PwdExpiry - O365 version

PowerShell script that finds Active Directory users whose password is about to expire and notifies them by email via Microsoft Graph.

## Requirements

- Windows with PowerShell 5.1 or higher
- RSAT module `ActiveDirectory` (`Install-WindowsFeature RSAT-AD-PowerShell`)
- The `EmailAddress` attribute must be populated in AD
- Azure AD app registration with the application permission **`Mail.Send`**
- Network access to `login.microsoftonline.com` and `graph.microsoft.com`

## Installation

If git isn't installed, install it using:

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
Copy-Item .\Settings\UserTemplate.html.example .\Settings\UserTemplate.html
Copy-Item .\Settings\AdminTemplate.html.example .\Settings\AdminTemplate.html
```

Then fill in `Settings\config.psd1` with your own values (see below).

You can create a custom HTML template by editing the `Settings\UserTemplate.html`.

## Update

Update the script using the following commands:

```powershell
cd C:\Scripts\PwdExpiry
git pull
```

### Client secret without plaintext in the file

Instead of entering the secret in `config.psd1`, it can be set as an environment variable:

```powershell
[Environment]::SetEnvironmentVariable("PWEXPIRE_CLIENT_SECRET", "XXX", "Machine")
```

The script automatically uses `$env:PWEXPIRE_CLIENT_SECRET` if `MailConfig.ClientSecret` is empty. This is the recommended approach for production environments.

## Usage

For regular operation, a daily task in Windows Task Scheduler is recommended.


## Security notes

- `Settings/config.psd1` is excluded from version control via `.gitignore` because it can contain secrets (client secret).
- Grant the app registration only the minimally required permission (`Mail.Send`).
- Prefer providing the client secret via the `PWEXPIRE_CLIENT_SECRET` environment variable instead of the configuration file.


## Changelog

### 09.07.2026

- A new feature has been added so that the admin is notified as soon as an error occurs while processing a user.
- The notification for admin and user are now sent with importance `high`.
- A new feature hast been added so that the script automatically checks for updates and notifies the administrator if an update is needed.
- New files: `Settings\AdminTemplate.html.example`, `Functions\AdminMail-Body.ps1`
- Renamed files: `Settings\Template.html.example` -> `Settings\UserTemplate.html.example`, `Functions\Mail-Body.ps1` -> `Functions\UserMailBody.ps1`

### 07.08.2026

- Added a function to automatically delete the log files.

### 03.08.2026

- Users can now create their own mail template by editing the Template.html in the Settings folder.
