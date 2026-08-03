function New-ExpiryMailBody {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$DaysToExpire
    )

    return @"
<p>Dear $Name,</p>
<p>Your password is going to expire in $DaysToExpire day(s). Please change it as soon as possible.</p>
<br>
<p>Thanks,<br>Your IT-Team</p>
"@
}