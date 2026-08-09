function Get-GraphAccessToken {
    param(
        [Parameter(Mandatory)][string]$TenantId,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][string]$ClientSecret
    )

    $body = @{
        grant_type = 'client_credentials'
        scope = 'https://graph.microsoft.com/.default'
        client_id = $ClientId
        client_secret = $ClientSecret
    }

    $tokenResponse = Invoke-RestMethod -Method Post `
        -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
        -Body $body

    return $tokenResponse.access_token
}

function Send-GraphMail {
    param(
        [Parameter(Mandatory)][string]$AccessToken,
        [Parameter(Mandatory)][string]$FromUser,
        [Parameter(Mandatory)][string]$ToUser,
        [Parameter(Mandatory)][string]$Subject,
        [Parameter(Mandatory)][string]$BodyHtml
    )

    $mailBody = @{
        message = @{
            subject = $Subject
            importance = 'high'
            body = @{
                contentType = 'HTML'
                content = $BodyHtml
            }
            toRecipients = @(
                @{ emailAddress = @{ address = $ToUser } }
            )
        }
        saveToSentItems = $true
    } | ConvertTo-Json -Depth 5

    Invoke-RestMethod -Method Post `
        -Uri "https://graph.microsoft.com/v1.0/users/$FromUser/sendMail" `
        -Headers @{ Authorization = "Bearer $AccessToken" } `
        -Body $mailBody `
        -ContentType 'application/json'
}