function New-AdminNotification {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$ErrorMessage,
        [Parameter(Mandatory)][string]$TemplatePath
    )

    if (-not (Test-Path $TemplatePath)) {
        throw "Template not found: $TemplatePath"
    }

    $template = Get-Content -Path $TemplatePath -Raw -Encoding UTF8

    $body = $template.Replace('{{Name}}', $Name).Replace('{{ErrorMessage}}', $ErrorMessage)

    return $body
}