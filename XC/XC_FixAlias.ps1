param(
[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
[string[]]$Mailbox,
[switch]$Update
)

begin{
$Script:Aliasses = @()

Function FixAlias ($Alias){
$IllegalCharacters = 0..34+40..41+44,47+58..60+62+64+91..93+127..160
$Result = $Alias
foreach($c in $IllegalCharacters){
	$escaped = [regex]::Escape([char]$c)
	if($Result -match $escaped){
		Write-Verbose "illegal character code detected: '$c'"
		$Result = $Result -replace $escaped
		}
	}
return $Result
}

}

process{
$NewAlias = FixAlias $Mailbox.Alias
If ($Update){Set-Mailbox –Alias $NewAlias}}
$Script:Aliasses += $NewAlias
}

end{
$Script:Aliasses 
}

# one-liners:
# Get-MailContact -ResultSize unlimited | foreach {$_.alias = $_.alias -replace '\s|,|\.'; $_} | Set-MailContact
# Get-MailContact -ResultSize Unlimited | where {$_.alias -match '\s'} | foreach { Set-MailContact $_ -Alias ($_.alias -replace " ", ".") }
# Get-MailPublicFolder -ResultSize Unlimited | where {$_.alias -match '\s'} | foreach {Set-MailPublicFolder $_ -Alias ($_.alias -replace '\s' -replace '"' -replace ':' -replace '@' -replace '\(' -replace '\)' -replace ',')}
# Set-MailPublicFolder $_ -Alias ($_.alias -replace '[\s":@\\,]')
# Set-MailPublicFolder $_ -Alias ($_.alias -replace '[\s":@\\,\.]')
# Set-MailPublicFolder $_ -alias ($_.alias -replace '[\s":@\\,]' -replace '(?<=.+)\.')
# Get-PublicFolder -Recurse | where {$_.name -match '\s'} | foreach { Set-PublicFolder $_ -Name ($_.name -replace '\s',".") }
