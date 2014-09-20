param(
[string[]]$room = @("naam_van_de_zaal")
)
begin{
$Global:XCrooms = @()
$destOU = 'company.domain/Security/Service Accounts/Exchange/Rooms'
}

process{
$Global:XCrooms += (New-Mailbox -Name $room -Alias $room -OrganizationalUnit $destOU -UserPrincipalName "$room@company.domain" -SamAccountName $room -FirstName $room -Initials '' -LastName '' -Room)
}

end{
$Global:XCrooms | sort name
}
