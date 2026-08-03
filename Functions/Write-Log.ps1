function Write-Log {
    param(
        [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO',
        [Parameter(Mandatory)][string]$Text,
        [switch]$ToConsole
    )

    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $Msg = "[$Timestamp] - $Level - $Text"

    if ($EnableLogging) {
        try {
            Add-Content -Path $LogFile -Value $Msg
        }
        catch {
            Write-Host "Failed to write to log file '$LogFile': $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    if ($ToConsole) {
        switch ($Level) {
            'INFO'  { Write-Host $Msg -ForegroundColor Cyan }
            'WARN'  { Write-Host $Msg -ForegroundColor Yellow }
            'ERROR' { Write-Host $Msg -ForegroundColor Red }
        }
    }
}