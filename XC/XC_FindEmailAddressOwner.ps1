param(
[string] $MailAddress
)
get-recipient -results unlimited | where {$_.emailaddresses -match $MailAddress} | fl
