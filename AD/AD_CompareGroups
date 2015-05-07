[CmdletBinding()]
param(
[Parameter(Mandatory=$true)][string] $OrigUser = "TemplateUser",
[Parameter(Mandatory=$true)][string] $NewUser,
[string[]] $ExcludedGroups = "CN=FIM*|CN=UF*"
)

begin{
#check powershell version
if ((Get-Host).Version.Major -lt 3){Write-Error "powershell version must be 3 or greater, script execution will end";exit}
#load AD module and connect to a random domain controller
if (-not (get-module).name -eq "ActiveDirectory"){Import-Module ActiveDirectory -ErrorAction Stop}
$script:added = 0
$script:skipped = 0

Function CompareMemberShip($FromUser, $ToUser){
try{
	#get memberOf from AD for each user
	$OrigUserMember = (Get-ADUser $FromUser -Properties memberof).memberof
	$NewUserMember = (Get-ADUser $ToUser -Properties memberof).memberof
	#show groups from OrigUser not assigned to newuser
	$groupsmissing = (compare $NewUserMember $OrigUserMember | ?{$_.sideindicator -eq "=>"})
	}
catch {Write-warning "$($_.Exception)"}
return $groupsmissing
}

Function AddGroups ($groups){
write-debug $groups
foreach ($group in $groups){
	if (-not ($group.InputObject -match $ExcludedGroups)){
		try {Add-ADGroupMember -Identity $group.InputObject -Members $NewUser;$script:added++}
		catch [Microsoft.ActiveDirectory.Management.ADException] {Write-warning "no permission to add this group: $($group.Inputobject)";$script:skipped++}
		catch {Write-warning "$($_.Exception)";$script:skipped++}
		}
	else{write-warning "$($group.Inputobject) is skipped";$script:skipped++}
	}
}

}#end begin

process{
$groupsmissing = CompareMemberShip $OrigUser $NewUser
#the out-gridview allows you to select the groups to be assigned to the new user
AddGroups $($groupsmissing | Out-GridView -Title "van $OrigUser naar $NewUser" -PassThru)
}#end process

End{
Write-Host "end of script, $($script:added) groups have been added and $($script:skipped) groups have been skipped"
}#end end
