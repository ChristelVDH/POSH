param(
[Parameter(Position=0,ValueFromPipeline=$True)]
[ValidateNotNullorEmpty()]
[string[]]$NewOU = @(Import-csv -Path "D:\projects\AD\automatisatie\testdiensten.csv" -Delimiter ";"),
$searchBase = "OU=Organisatie,DC=Company,DC=domain",
$SubOUs = @("Computers","Users"),
[switch]$ProtectOU
)
begin{
$Protect = $false
If ($ProtectOU){$Protect = $true}
}

process{
New-ADOrganizationalUnit -Name $NewOU.name -Description $NewOU.description -City "Antwerpen" -Country "BE" -ManagedBy $NewOU.manager -State "Antwerpen" -Path $searchBase -ProtectedFromAccidentalDeletion $Protect
$SubOUPath = "OU=" + $Newou.Name + "," + $searchBase
foreach ($SubOU in $SubOUs){
	New-ADOrganizationalUnit -Name $SubOU -Path $SubOUPath -ProtectedFromAccidentalDeletion $Protect
	}
}

end{
}
