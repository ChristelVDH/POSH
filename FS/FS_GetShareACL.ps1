param(
[string] $Computer = $env:computername,
[string] $SharedFolder
)

Get-ChildItem "\\$Computer\$SharedFolder" -Recurse | ?{ $_.PsIsContainer } | %{
	write-host $_.FullName
	$Path = $_.FullName
	# Exclude inherited rights from the report
	(Get-Acl $Path).Access | ?{ !$_.IsInherited } | Select-Object @{n='Path';e={ $Path }}, IdentityReference, AccessControlType, InheritanceFlags, PropagationFlags, FileSystemRights
} | Export-CSV $("e:\debug\inv\" + $Computer + "_" + $SharedFolder + "_Permissions.csv") -NoTypeInformation -Delimiter ";"
