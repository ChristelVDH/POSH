param(
[string]$ExchangeServer = (get-random ("cas01","cas02")),
[string]$SessionAlias = "RemoteXC",
[switch] $AlternativeCredentials,
[switch] $Disconnect
)

$Options = New-PSSessionOption -SkipCACheck -SkipCNCheck #-SkipRevocationCheck
#Import Session information for Exchange
if (-not $Disconnect){
	write-host "connecting to CAS server: $ExchangeServer" -fore green
	if ($AlternativeCredentials){
		$usercredential= get-credential
		$XCSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$ExchangeServer/PowerShell/ -Authentication Kerberos -Credential $UserCredential -Name $SessionAlias -SessionOption $Options
		#-Authentication NegotiateWithImplicitCredential
		}
	else{
		$XCSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$ExchangeServer/PowerShell/ -Authentication Kerberos -Name $SessionAlias -SessionOption $Options
	}
	if (-not (Import-PSSession $XCSession -EA stop)){
		Write-Error "connection to $ExchangeServer failed"
		}
	}
else{Remove-PSSession -Name $SessionAlias}