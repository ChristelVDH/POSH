param(
[string] $ImportFile = "",
[string] $Delimiter = ";",
[string[]]$Groups = @("basic_user_group")
)

begin{
if (-not (get-module).name -eq "ActiveDirectory"){Import-Module ActiveDirectory -ErrorAction Stop}
# $DCs = [DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().DomainControllers
# $DC = (get-random $DCs.Name)
$DC = (get-random "dc01","dc02","dc03","dc04")
$script:newmb = @()
$nl = [Environment]::NewLine
$MyDocs = [Environment]::getfolderpath("mydocuments")
#number of properties (either empty or not) for creating new AD user
[int]$RequiredColumns = 12

function New-Sleep {
param(
[parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,
Mandatory=$true, HelpMessage="Specify time in seconds")][int]$s
)
for ($i=1; $i -lt $s; $i++) {
	[int]$TimeLeft=$s-$i
	Write-Progress -Activity "Waiting $s seconds..." -PercentComplete (100/$s*$i) -CurrentOperation "$TimeLeft seconds left ($i elapsed)" -Status "Please wait"
	Start-Sleep -s 1
	}
Write-Progress -Completed $true -Status "Continuing..."
}

function FindEmpID ($EmpID){
#nya = Not Yet Assigned employee ID
if ($EmpID -eq "nya"){return $false}
else{
	$Filter = 'employeeid -eq $EmpID'
	[string]$SearchBase = [DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().GetDirectoryEntry().distinguishedName
	[string]$Domain = [DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name
	$result = (Get-ADUser -Filter $Filter -SearchBase $SearchBase)
	return $result
	}
}

function CheckImport ($ImportData,[int]$ColumnCount){
$result = $false
[int]$ImportdataColumncount = ($ImportData | gm -Type noteproperty).count
switch ($ImportdataColumncount){
	{$_ -lt $ColumnCount}{write-error "not enough columns"}
	{$_ -gt $ColumnCount}{write-error "too many columns or delimiter(s)"}
	{$_ -eq $ColumnCount}{write-verbose "columncount is correct";$result = $true}
	}
return $result
}

Function CheckADUser ($UserRecord){
#front function for all kind of checks
$result = $true
if (FindEmpID $UserRecord.EmpID){write-warning "user with employee ID $($_.empid) already exists";$result=$true}
#check columncount again for each user record
if (-not CheckImport $UserRecord $RequiredColumns){$result = $false}
return $result
}

} # end begin

process{
# fill up users array with csv entries
$Users = Import-CSV $ImportFile -delimiter $Delimiter
# check for columncount in import file header
if (-not CheckImport $users $RequiredColumns){
	write-error "error found in importfile, exiting script..."
	break
	}
# user array iteration
$i=0
foreach ($User in $Users){
	$i++
	write-progress -id 1 -activity "Creating new AD users" -status "creating login with EmpID $($User.empid)" -percentComplete (($i/$users.Count)*100)
	if (CheckADUser $User){write-error "$($User.login) is NOT created";return}
	else{
		$Password = convertto-securestring $User.password -asplaintext -force
		try{$ExpDate = (Get-Date $User.ExpDate).AddDays(1)}
		catch{write-warning "Expiry date $($User.ExpDate) cannot be parsed as date"}
		write-verbose "expiry date is $ExpDate"
		try{
			New-ADuser -Server $DC -Name $User.name -GivenName $User.Firstname -Surname $User.Lastname -DisplayName $User.name -userPrincipalName $User.UPN -SamAccountName $User.login -EmployeeID $User.empid -Description $User.functie -Path $User.OUpath -AccountPassword $Password -Company "Company" -Office "Centrum" -City "Antwerpen" -Department $User.dept -Enabled:$true
			}
		catch [Microsoft.ActiveDirectory.Management.ADIdentityAlreadyExistsException]{
			Write-warning "$($_.Exception):$($nl)$($User.login)"
			Write-Host $nl
			}
		catch{
			Write-warning "$($_.Exception):$($nl)$($User.login)"
			Write-Host $nl
			return
			}
		$NewUser = Get-ADUser -Server $DC $User.login
		write-verbose "found AD user for $($User.login): $($NewUser.DistinguishedName)"
		if ($NewUser){
			if ($Expdate){
				write-verbose "setting Expiry Date for $($Newuser.Name) to: $Expdate"
				try{Set-AdUser -Identity $NewUser -Server $DC -AccountExpirationDate $ExpDate}
				catch{write-warning "failed to set expiry date for $($NewUser.SamAccountName) to $Expdate"}
				}
			$Groups | Add-ADGroupMember -Server $DC -Members $NewUser
			write-verbose "$($NewUser.Name) is member of:"
			write-verbose "$($(Get-ADUser $Newuser –Properties MemberOf).MemberOf)"
			#add newly created user to array for further processing and script output
			$script:newmb += $NewUser
			}
		}
	}
# wait for replication between AD and XC
write-verbose "waiting 30 seconds for replication between AD and XC"
new-sleep -s 30
# establish remote exchange PS session
$exchangeserver = (get-random "cas01","cas02")
$XCSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$exchangeserver/PowerShell/ -Authentication Kerberos -ErrorAction SilentlyContinue
Import-PSSession $XCSession
# AD user array iteration piped into enable mailbox cmdlet
$Notes = $("Created dd $((get-date).toshortdatestring())")
$i = 0
foreach ($UserMB in $script:newmb){
	$i++
	write-progress -id 1 -activity "Creating mailboxes" -status "creating mailbox for $($UserMB.SamAccountName)" -percentComplete (($i/$script:newmb.Count)*100)
	Enable-Mailbox -Identity $UserMB.SamAccountName -DomainController $DC
	Set-Mailbox -Identity $UserMB.SamAccountName -DomainController $DC -IssueWarningQuota "1920MB" -ProhibitSendQuota "1984MB" -ProhibitSendReceiveQuota "2048MB"
	Set-User -Identity $UserMB.SamAccountName -Notes $Notes
	}
} # end process
end{
Remove-PSSession $XCSession
$script:newmb
}

#examples given for used fields
#$firstname = "peter"
#$lastname = "simmons"
#$initials = ""
#$alias = $firstname + "." + $lastname --> "peter.simmons"
#$name = $lastname + " " + $firstname --> "simmons peter" --> used for mailbox display name & AD display name
#$login = "ps99"
#$UPN = $login + "@company.domain" --> "ps99@company.domain"
#$OUpath = "OU=Users,DC=company,DC=domain"
#$password = "paswoord"
#$dept = "Accounting"
