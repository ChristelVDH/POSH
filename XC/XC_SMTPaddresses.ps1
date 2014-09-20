param(
[Parameter(Position=0,ValueFromPipeline=$True)]
[ValidateNotNullorEmpty()][string[]]$Mailboxes = @(),
[string] $Regex = "company\.legacy\.com$|^CCMAIL|^MS:company|^X500:",
$SMTPdomains = @("company.com","company.legacy.com"),
$Delimiter = "|",
$LogFile = $([Environment]::getfolderpath("mydocuments")) + "\smtpadresses.csv",
[switch]$Output,
[switch]$X500,
[switch]$Remove,
[switch]$Update
)

process{
try{$sMailbox = get-mailbox -identity $Mailbox -EA Stop}
catch{write-warning "no such mailbox: $Mailbox";continue}
foreach ($Address in $sMailbox.EmailAddresses){
	if([regex]::IsMatch($Address,$Regex)){
		if ($Remove){RemoveSMTPAddress -Mailbox $sMailbox -Address $Address -Match $True}
		else{OutputMB -Mailbox $sMailbox -Address $Address -Match $True -Action "Matched"}
		}
	else{OutputMB -Mailbox $sMailbox -Address $Address -Match $False -Action "None"}
	}
if ($Update){
	foreach ($sDomain in $SMTPdomains){
		NewSMTPAddress -Mailbox $sMailbox -Prefix $sMailbox.SamAccountName -Domain $sDomain
		}
	}
if ($X500){X500Address -Mailbox $sMailbox}
}#process

end{
if($Output){$script:mbx | Select Mailbox, Address, Match, Action | Export-Csv $LogFile -Delimiter $Delimiter -NoTypeInformation -Encoding UTF8}
else {$script:mbx | Select Mailbox, Address, Match, Action}
}#end

begin{
$script:mbx = @()

Function NewSMTPAddress ($Mailbox,$Prefix,$Domain){
$Address = "$Prefix@$Domain"
$Mailbox | Set-Mailbox -EmailAddresses @{add = $Address}
OutputMB -Mailbox $Mailbox -Address $Address -Match $False -Action "Added"
}

Function X500Address ($Mailbox){
$Address = "X500:$($Mailbox.LegacyExchangeDN)"
$Mailbox | Set-Mailbox -EmailAddresses @{add = $Address}
OutputMB -Mailbox $Mailbox -Address $Address -Match $False -Action "Added"
}

Function RemoveSMTPAddress ($Mailbox,$Address,$Match){
$Mailbox | Set-Mailbox -EmailAddresses @{remove = $Address}
OutputMB -Mailbox $Mailbox -Address $Address -Match $Match -Action "Removed"
}

Function OutputMB ($Mailbox,$Address,$Match,$Action){
$script:mbx += New-Object -Typename PSObject -Property @{
	Mailbox = $Mailbox
	Address = $Address
	Match = $Match
	Action = $Action
	}
}

}#begin

#.\XC_SMTPaddresses.ps1 -Mailboxes (Get-Mailbox -OrganizationalUnit "OU=Users,DC=company,DC=domain")
#Set-EmailAddressPolicy -Identity “simpledot” -EnabledEmailAddressTemplates SMTP:"%r .%g.%r .%s@company.com", "smtp:%m@company.com"

 