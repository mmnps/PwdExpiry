@{
    ExpireDays          = 14   # How many days in advance the expiry email will be sent

    MailConfig = @{
        TenantId        = ""   # Azure AD Tenant ID
        ClientId        = ""   # App registration (client) ID
        ClientSecret    = ""   # App registration client secret. Set here or create the PWEXPIRE_CLIENT_SECRET environment variable:
                               # [Environment]::SetEnvironmentVariable("PWEXPIRE_CLIENT_SECRET", "XXX", "Machine")

        FromUser        = ""   # Mailbox used as sender, e.g. support@company.com
    }

    LogConfig = @{
        EnableLogging   = $true
        LogPath         = ""   # Folder for daily log files. Leave it blank to use a "Logs" folder next to the script.
        KeepLogsDays    = 14   # How many days the log files will be stored
    }
}
