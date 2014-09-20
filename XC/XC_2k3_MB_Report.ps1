param(
[string] $ExchangeServer = "mailserver2k3",
[string] $MailboxType
)

begin{
$script:Mailboxes = @()
}

process{
switch ($MailboxType){
	'Disconnected'{
		$script:Mailboxes += (Get-WMIObject -namespace root\MicrosoftExchangeV2 -class Exchange_Mailbox -computer $ExchangeServer -filter "DateDiscoveredAbsentInDS is not null")
		}
	Default {
		$script:Mailboxes += (Get-WMIObject -namespace root\MicrosoftExchangeV2 -class Exchange_Mailbox -computer $ExchangeServer)
		}
}
}

end{
$script:Mailboxes | select @{name="date";expression={(get-date).ToShortDateString()}}, mailboxdisplayname, legacydn, MailboxGUID, size, totalitems, @{name="avg size/item";expression={$_.size/$_.totalitems}}, storagegroupname, storename, @{name="lastlogontime";expression={[System.Management.ManagementDateTimeconverter]::ToDateTime($_.lastlogontime)}},LastLoggedOnUserAccount | sort-object MailboxDisplayName 
}