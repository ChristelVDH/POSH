param(
[Parameter(Position=0,ValueFromPipeline=$True)]
[ValidateNotNullorEmpty()][string[]] $Users,
$PasswordAgeDays = 91,
#$BaseOU = "OU=EndUsers,OU=Users,OU=Managed,DC=Company,DC=domain",
$TargetOU = "OU=ExpiredAccounts,DC=Company,DC=domain",
[switch] $DisableUser,
[switch] $MoveUser,
[switch] $ClearGroupMembership,
[switch] $DisconnectMailbox
)
begin{
#[string] $BaseOU=([ADSI]"LDAP://$env:userdnsdomain").distinguishedname
if (-not $Users){
	$Users = Get-ADUser -Filter * -SearchBase $TargetOU
	#$User = Search-ADAccount -SearchBase $BaseOU -SearchScope Subtree -AccountInactive -TimeSpan "$PasswordAgeDays.00:00:00" -UsersOnly
	}

Function ClearXCAttributes($User){
# attributes to be cleared according to:
# http://blogs.technet.com/b/exchange/archive/2006/10/13/3395089.aspx
$XCattributes=@(
"adminDisplayName","altRecipient","authOrig","autoReplyMessage","deletedItemFlags","delivContLength","deliverAndRedirect","displayNamePrintable",
"dLMemDefault","dLMemRejectPerms","dLMemSubmitPerms","extensionAttribute1","extensionAttribute10","extensionAttribute11","extensionAttribute12",
"extensionAttribute13","extensionAttribute14","extensionAttribute15","extensionAttribute2","extensionAttribute3","extensionAttribute4","extensionAttribute5",
"extensionAttribute6","extensionAttribute7","extensionAttribute8","extensionAttribute9","folderPathname","garbageCollPeriod","homeMDB","homeMTA",
"internetEncoding","legacyExchangeDN","mail","mailNickname","mAPIRecipient","mDBOverHardQuotaLimit","mDBOverQuotaLimit","mDBStorageQuota","mDBUseDefaults",
"msExchADCGlobalNames","msExchControllingZone","msExchExpansionServerName","msExchFBURL","msExchHideFromAddressLists","msExchHomeServerName",
"msExchMailboxGuid","msExchMailboxSecurityDescriptor","msExchPoliciesExcluded","msExchPoliciesIncluded","msExchRecipLimit","msExchResourceGUID",
"protocolSettings","proxyAddresses","publicDelegates","securityProtocol","showInAddressBook","submissionContLength","targetAddress","textEncodedORAddress",
"unauthOrig"
)
try{set-aduser -Identity $User -Clear $XCattributes}
catch{Write-Error $("For " + $User + ": " + $($error[0]))}
}
}

process{
foreach ($User in $Users){
	If ($DisableUser){
		Disable-ADAccount -Identity $User
		Set-ADUser -Identity $User -Description $("Disabled dd $((get-date).toshortdatestring())")
		}
	If ($MoveUser){
		Move-ADObject -Identity $User -TargetPath $TargetOU
		Write-Host -ForegroundColor green "$User has been moved"
		}
	If ($ClearGroupMembership){
		(Get-ADuser –Identity $User –Properties MemberOf).MemberOf | %{Remove-ADGroupMember -Identity $_ -confirm:$false -member $User}
		}
	If ($DisconnectMailbox){
		#ClearXCAttributes $User
		Disable-Mailbox -Identity $User
		}
	#Get-ADUser -Identity $User -Properties DisplayName, EmployeeID, Department, DistinguishedName, ObjectGUID, Created, LastLogonDate, Enabled, PasswordExpired, PasswordLastSet, PasswordNeverExpires
	}
}

end{

}
