param (
[Parameter(Position=0,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$true)]
[alias("Name","ComputerName")] $Computer = @($env:computername),
$OutFileName = "ShareReport.html",
[switch] $HTML
)

process{
if (Test-Connection -ComputerName $Computer -Count 1 -Quiet){
$Name = $Location = $NTFSPermissions = $NTFSOwner = $SharePermissions = $Description = "ERROR"
	try{
		$MainShares = Get-AllShares -Computer $Computer
		Foreach($MainShare in $MainShares){
			$Name = $MainShare.Name
			$Location = $MainShare.Path
			$NTFSPermissions = Get-NTFSPerms -Path $("\\$Computer\" + $MainShare.Name)
			$NTFSOwner = Get-NTFSOwner -Path $("\\$Computer\" + $MainShare.Name)
			$SharePermissions = Get-SharePermissions -Computer $Computer -ShareName $MainShare.Name
			$Description = $MainShare.Description
			}
		}
	catch{
		$continue = $False
		}
	$Global:ObjOut += New-Object PSObject -Property @{
		ComputerName = $Computer
		Name = $Name
		Location = $Location
		NTFSPermissions = $NTFSPermissions
		NTFSOwner = $NTFSOwner
		SharePermissions = $SharePermissions
		Description = $Description
		}
	}
} # end process

begin{
$Global:ObjOut = @()

Function Get-SharePermissions($Computer, $ShareName){
    $Share = Get-WmiObject -Computer $Computer win32_LogicalShareSecuritySetting -Filter "name='$ShareName'"
    if($Share){
        $obj = @()
        $ACLS = $Share.GetSecurityDescriptor().Descriptor.DACL
        foreach($ACL in $ACLS){
            $User = $ACL.Trustee.Name
            if(!($user)){$user = $ACL.Trustee.SID}
            $Domain = $ACL.Trustee.Domain
            switch($ACL.AccessMask){
                2032127 {$Perm = "Full Control"}
                1245631 {$Perm = "Change"}
                1179817 {$Perm = "Read"}
            }
            $obj += "$Domain\$user  $Perm<br>"
        }
    }
    if(!($Share)){$obj = " ERROR: cannot enumerate share permissions. "}
    Return $obj
}

Function Get-NTFSOwner($Path){
    $ACL = Get-Acl -Path $Path
    $a = $ACL.Owner.ToString()
    Return $a
}

Function Get-NTFSPerms($Path){
    $ACL = Get-Acl -Path $Path
    $obj = @()
    foreach($a in $ACL.Access){
        $aA = $a.FileSystemRights
        $aB = $a.AccessControlType
        $aC = $a.IdentityReference
        $aD = $a.IsInherited
        $aE = $a.InheritanceFlags
        $aF = $a.PropagationFlags
        $obj += "$aC | $aB | $aA | $aD | $aE | $aF <br>"
    }
    Return $obj
}

Function Get-AllShares($Computer){
    $a = Get-WmiObject -Computer $Computer win32_share -Filter "type=0"
    Return $a
}

# Create Webpage Header
Function WebDocHeader{
$doc = "<!DOCTYPE html PUBLIC `"-//W3C//DTD XHTML 1.0 Strict//EN`"  `"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd`">"
$doc += "<html xmlns=`"http://www.w3.org/1999/xhtml`">"
$doc += "<head><style>"
$doc += "TABLE{border-width: 2px;border-style: solid;border-color: black;border-collapse: collapse;}"
$doc += "TH{border-width: 2px;padding: 4px;border-style: solid;border-color: black;background-color:lightblue;text-align:left;font-size:14px}"
$doc += "TD{border-width: 1px;padding: 4px;border-style: solid;border-color: black;font-size:12px}"
$doc += "</style></head><body>"
$doc += "<H4>File Share Report</H4>"
$doc += "<table><colgroup><col/><col/><col/><col/><col/><col/><col/></colgroup>"
$doc += "<tr><th>Host</th><th>ShareName</th><th>Location</th><th>NTFSPermissions<br>IdentityReference|AccessControlType|FileSystemRights|IsInherited|InheritanceFlags|PropagationFlags</th><th>NTFSOwner</th><th>SharePermissions</th><th>Description</th></tr>"
return $doc
}
}

end{
if ($HTML){
	$z = WebDocHeader
	$Global:ObjOut | %{
		$z += "<tr><td>$($_.ComputerName)</td><td>$($_.Name)</td><td>$($_.Location)</td><td>$($_.NTFSPermissions)</td><td>$($_.NTFSOwner)</td><td>$($_.SharePermissions)</td><td>$($_.Description)</td></tr>"
		}
	$z += "</table></body></html>"
	Out-File -FilePath .\$OutFileName -InputObject $z -Encoding UTF8
	$OutFileItem = Get-Item -Path .\$OutFileName
	Write-Host " Report available here: $OutFileItem" -Foregroundcolor Yellow
	Invoke-Item $OutFileItem
	}
	else{
		$Global:ObjOut
	}
}