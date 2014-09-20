[CmdletBinding()]
param(
[string]$AssocXMLFilePath = ".\assoc_$($env:computername).xml",
[switch]$Import
)

process{
$VerbosePreference = "continue"
ExportAssociation -Path $AssocXMLFilePath
BackupAssociation -Path $AssocXMLFilePath
ModifyAssociation -Path $AssocXMLFilePath -Extension ".bmp"  -ProgID "PhotoViewer.FileAssoc.Bitmap" -AppName 'Windows Photo Viewer'
ModifyAssociation -Path $AssocXMLFilePath -Extension ".dib"  -ProgID "PhotoViewer.FileAssoc.Bitmap" -AppName 'Windows Photo Viewer'
ModifyAssociation -Path $AssocXMLFilePath -Extension ".jfif"  -ProgID "PhotoViewer.FileAssoc.JFIF" -AppName 'Windows Photo Viewer'
ModifyAssociation -Path $AssocXMLFilePath -Extension ".jpe"  -ProgID "PhotoViewer.FileAssoc.Jpeg" -AppName 'Windows Photo Viewer'
ModifyAssociation -Path $AssocXMLFilePath -Extension ".jpeg"  -ProgID "PhotoViewer.FileAssoc.Jpeg" -AppName 'Windows Photo Viewer'
ModifyAssociation -Path $AssocXMLFilePath -Extension ".jpg"  -ProgID "PhotoViewer.FileAssoc.Jpeg" -AppName 'Windows Photo Viewer'
ModifyAssociation -Path $AssocXMLFilePath -Extension ".jxr"  -ProgID "PhotoViewer.FileAssoc.Wdp" -AppName 'Windows Photo Viewer'
ModifyAssociation -Path $AssocXMLFilePath -Extension ".png"  -ProgID "PhotoViewer.FileAssoc.Png" -AppName 'Windows Photo Viewer'
ModifyAssociation -Path $AssocXMLFilePath -Extension ".tif"  -ProgID "PhotoViewer.FileAssoc.Tiff" -AppName 'Windows Photo Viewer'
ModifyAssociation -Path $AssocXMLFilePath -Extension ".tiff"  -ProgID "PhotoViewer.FileAssoc.Tiff" -AppName 'Windows Photo Viewer'
ModifyAssociation -Path $AssocXMLFilePath -Extension ".wdp"  -ProgID "PhotoViewer.FileAssoc.Wdp" -AppName 'Windows Photo Viewer'
ModifyAssociation -Path $AssocXMLFilePath -Extension ".pdf"  -ProgID "AcroExch.Document.11" -AppName 'Adobe Reader'
if ($Import){ImportAssociation -Path $AssocXMLFilePath}
}

begin{

Function ExportAssociation($Path){
write-verbose "Exporting Default Associations file to $Path"
DISM /Online /Export-DefaultAppAssociations:$Path
}

Function BackupAssociation($Path){
#create backup file for today
$BackupFile = "$($path)_$(get-date -f yyyyMMdd).bak"
Copy-Item $Path $BackupFile -Force
write-verbose "Created backup file to $BackupFile"
}

Function ModifyAssociation{
param(
[parameter(Mandatory = $True )][string]$Path,
[parameter(Mandatory = $True )][string]$Extension,
[parameter(Mandatory = $True )][string]$ProgID,
[parameter(Mandatory = $True )][string]$AppName
)
#open the file as xml object
[xml]$AssocXML = Get-Content $Path -Encoding UTF8
#Update existing Association node else create it
$node = $AssocXML.DefaultAssociations.Association | ?{$_.Identifier -match "$($Extension)$"}
if ($node){
	write-verbose "association found for $Extension with $($node.ApplicationName)"
	$node.ProgId = $ProgID
	$node.ApplicationName = $AppName
	}
else{
	$NewAssociationNode = $AssocXML.CreateElement("Association")
	#Set the attributes for the new element
	$NewAssociationNode.SetAttribute("Identifier",$Extension)
	$NewAssociationNode.SetAttribute("ProgId",$ProgID)
	$NewAssociationNode.SetAttribute("ApplicationName",$AppName)
	#Inject the new child to existing
	$AssocXML.LastChild.AppendChild($NewAssociationNode) > $null
	write-verbose "new association appended for $Extension with $AppName"
	}
$AssocXML.Save($Path)
}# end function

Function SortAssociation($Path){
[xml]$AssocXML = Get-Content $Path -Encoding UTF8
$AssocXML.DefaultAssociations.Association | sort progid 
}

Function ImportAssociation ($Path){
write-verbose "Importing Default Associations file from $Path"
DISM /Online /Import-DefaultAppAssociations:$Path
}

}# end begin

end{

}
