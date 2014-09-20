# Automatic backup + reporting + exporting of GPO
# created by Chris Kenis, 3/22/2013
# GPO module required
# comparison still needs work
[CmdletBinding()]
param(
#$GPOs = $(Get-GPO -All),
$GPOs = $(Get-GPO helpdesk),
$DestinationFolder = [Environment]::getfolderpath("mydocuments"),
[switch]$Output2Excel
)

process{
write-host "Getting GPO XML Reports..."
$GPOCount = 0
foreach ($GPO in $GPOs){
	$GPOCount++
	write-host "GPO number $GPOCount : $($GPO.DisplayName) / $($GPO.ID)"
	#retrieve basic details
	$objGPOdetails = GPOdetail $GPO
	#backup GPO as verbose XML file
	$GPOXMLoutput = OutXMLReport $GPO
	#add link to XML export in custom object
	$objGPOdetails | Add-Member -Type NoteProperty -Name XMLReport -Value $($GPOXMLoutput)
	#compare current and previous exported verbose XML file and add result in custom object
	$objGPOdetails | Add-Member -Type NoteProperty -Name Differences -Value $(CompareGPOs $GPOXMLoutput)
	#add result from report in custom object
	$objGPOdetails | Add-Member -Type NoteProperty -Name HTMLReport -Value $(GPReport $GPO)
	#add custom PSobject to object array for output
	$script:AllGPOs += $objGPOdetails
	}
}#process

begin{
# script variables
$nl = [Environment]::NewLine
$script:AllGPOs = @()
$script:Today = $((get-date).toString('yyyy-MM-dd'))
$script:OutPutRootFolderByDate = Join-Path $DestinationFolder $script:Today

Function GPOdetail($GPO){
#preset required variables
$ComputerExtensions = $UserExtensions = $Links = $LinksEnabled = $LinksNoOverride = "<none>"
#Cast GPO report into XML variable for manipulation
$GPOXML = [xml](Get-GPOReport $GPO.Id -ReportType XML)
write-verbose "retrieving XML report for $($GPO.Displayname)"
if ($GPOXML.GPO.Computer.ExtensionData){$ComputerExtensions = $($GPOXML.GPO.Computer.ExtensionData | %{$_.Name}) -join $nl}
if ($GPOXML.GPO.User.ExtensionData){$UserExtensions = [string]::join($nl, $($GPOXML.GPO.User.ExtensionData | %{$_.Name}))}
if ($GPOXML.GPO.LinksTo){
	$Links = [string]::join($nl, ($GPOXML.GPO.LinksTo | %{ $_.SOMPath }))
	$LinksEnabled = [string]::join($nl, ( $GPOXML.GPO.LinksTo | %{ $_.Enabled }))
	$LinksNoOverride = [string]::join($nl, ($GPOXML.GPO.LinksTo | %{ $_.NoOverride }))
	}
#get gpo size + adm file enum
$GPOSize = GetSize $GPO
#create and fill returned object with GPO data
$GPOInfo = New-Object PSObject -Property @{
	ExportDate = $(Get-Date).ToShortDateString()
	Name = $GPO.Displayname
	GPOID = $GPO.Id
	Created = $GPO.CreationTime
	Modified = $GPO.ModificationTime
	WMIFilter = $GPO.WMIFilter
	#Computer Configuration
	ComputerEnabled = $GPO.Computer.Enabled
	ComputerVerDir = $GPO.Computer.DSVersion
	ComputerVerSys = $GPO.Computer.SysvolVersion
	ComputerExtensions = $ComputerExtensions
	#User Configuration
	UserEnabled = $GPO.User.Enabled
	UserVerDir = $GPO.User.DSVersion
	UserVerSys = $GPO.User.SysvolVersion
	UserExtensions = $UserExtensions
	#Links
	Links = $Links
	LinksEnabled = $LinksEnabled
	LinksNoOverride = $LinksNoOverride
	#Security Info
	Owner = $GPO.Owner
	SecurityPermissions = $($GPO.GetSecurityInfo() | %{"$($_.trustee.name) has $($_.permission)"}) -join "`n"
	#Policy File System Size
	TotalSize = $GPOSize.TotalSize
	ADMSize = $GPOSize.ADMSize
	ADMFiles = $GPOSize.ADMFiles
	}
return $GPOInfo
}

Function GetSize($GPO){
#preset required variables
$ADMSize = $TotalSize = "0KB"
$ADMFiles = $ADMFiles = "<none>"
#get current domain + policies folder thru system environment calls
$domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name
$GPOfolder = "\\$domain\SYSVOL\$domain\Policies\{$($GPO.Id)}"
#custom formatted string for total GPO size
$TotalSize = "{0:N2}" -f ((gci $GPOfolder -recurse | Measure-Object -Property length -sum).sum / 1KB) + "KB"
write-verbose "The size for $($GPO.DisplayName) is $TotalSize KB"
#iterate thru all ADM files if any, report filesize + filename
$ADMs = gci $(Join-Path $GPOfolder "\Adm")
if ($ADMs.Count){
	write-verbose "$($ADMs.Count) ADM files found"
	$ADMSize = "{0:N2}" -f (($ADMs | Measure-Object -Property length -sum).sum / 1KB) + "KB"
	$ADMFiles = $ADMs.Basename -join ","
	}
$GPOSize = @{"TotalSize" = $TotalSize; "ADMSize" = $ADMSize; "ADMFiles" = $ADMFiles}
return $GPOSize
}

Function OutXMLReport ($GPO){
write-verbose "a verbose xml export file will be created for $($GPO.DisplayName)"
$OutputFolder = Join-Path $script:OutPutRootFolderByDate "XMLoutput"
#create output folder if not exists
if (-not (Test-Path $OutputFolder)){New-Item $OutputFolder -Type directory}
$OutFile = (Join-Path $OutputFolder $($GPO.DisplayName + ".xml"))
$GPO.GenerateReportToFile("xml",$OutFile)
write-verbose "XML Report: $OutFile $($nl)....has been created"
return $OutFile.ToString()
}

Function GPReport ($GPO){
write-verbose "getting GPO $($GPO.DisplayName)"
$ReportFolder = Join-Path $script:OutPutRootFolderByDate "HTMLReport"
#create output folder if not exists
if (-not (Test-Path $ReportFolder)){New-Item $ReportFolder -Type directory}
$OutFile = Join-Path $Reportfolder $($GPO.DisplayName + ".html")
Get-GPOReport $GPO.Id -ReportType html -Path $OutFile
write-verbose "HTML report: $OutFile has been created"
return $OutFile.ToString()
}

Function CompareGPOs ($File){
$CurrGPO = (gci $File)
$PrevGPO = (Get-Item -Path $DestinationFolder\* -Exclude $script:Today | gci -Recurse -File -Include $CurrGPO.Name | sort LastWriteTime | select -last 1)
write-verbose "comparing current: $($CurrGPO.FullName)$($nl)with previous version: $($PrevGPO.FullName)"
try{$GPOdiff = Compare-Object $(gc $CurrGPO.FullName) $(gc $PrevGPO.FullName)}
catch{write-error "$($error[0])"}
#read time will always be diff so count greater than 2 before diffs are true
if ($GPODiff.Count -le 2){return $false}
else{return $true}
}

Function EnumProperties ($customobj){
foreach($singleobj in $customobj){
	write-host $($singleobj | gm -MemberType Property | %{$_.Name})
	break
	}
write-verbose "displaying each Property for incoming object"
}

Function Out2Excel ([array]$arrGPOs, $OutFolder){
$SaveFile = (Join-Path $OutFolder "GPO_Report.xlsx")
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $True #Change to Hide Excel Window
$xl.DisplayAlerts = $False
$Center = -4108
$Top = -4160
#EnumProperties $arrGPOs

if (Test-Path $SaveFile){
	$wkb = $xl.Workbooks.Open($SaveFile)
	$wks = $wkb.Worksheets.Item(1)
	$xlCellTypeLastCell = 11
	$row = $wks.usedRange.SpecialCells($xlCellTypeLastCell).row
	write-verbose "Excel file $SaveFile already exists, last used row = $row"
	}
else{
	write-verbose "new Excel file $SaveFile will be generated"
	#Excel Constants
	$White = 2
	$DarkGrey = 56
	$row = 1
	$col = 1
	$wkb = $xl.Workbooks.Add()
	$wks = $wkb.Worksheets.Item(1)
	#Builds Top Row
	$wks.Cells.Item($row,$col)   = "GPO_Name"
	$wks.Cells.Item($row,$col++) = "GPO_ID"
	$wks.Cells.Item($row,$col++) = "Created"
	$wks.Cells.Item($row,$col++) = "Modified"
	$wks.Cells.Item($row,$col++) = "WMI_Filter"
	$wks.Cells.Item($row,$col++) = "Comp_Config"
	$wks.Cells.Item($row,$col++) = "Comp_Dir_Ver"
	$wks.Cells.Item($row,$col++) = "Comp_Sysvol_Ver"
	$wks.Cells.Item($row,$col++) = "Comp_Extensions"
	$wks.Cells.Item($row,$col++) = "User_Config"
	$wks.Cells.Item($row,$col++) = "User_Dir_Ver"
	$wks.Cells.Item($row,$col++) = "User_Sysvol_Ver"
	$wks.Cells.Item($row,$col++) = "User_Extensions"
	$wks.Cells.Item($row,$col++) = "Links"
	$wks.Cells.Item($row,$col++) = "Enabled"
	$wks.Cells.Item($row,$col++) = "No_Override"
	$wks.Cells.Item($row,$col++) = "Owner"
	$wks.Cells.Item($row,$col++) = "Groups"
	$wks.Cells.Item($row,$col++) = "Size"
	$wks.Cells.Item($row,$col++) = "ADM_Files"
	$wks.Cells.Item($row,$col++) = "ADM_Size"
	$wks.Cells.Item($row,$col++) = "XMLReport"
	$wks.Cells.Item($row,$col++) = "Differences"
	$wks.Cells.Item($row,$col++) = "Export_Date"
	$wks.Cells.Item($row,$col++) = "HTMLReport"
	#Formats Top Row
	$wks.Range("A1:Y1").font.bold = "true"
	$wks.Range("A1:Y1").font.ColorIndex = $White
	$wks.Range("A1:Y1").interior.ColorIndex = $DarkGrey
	}
#Fills in Data from Array
$arrGPOs | foreach {
	$row++
	$col = 1
	$wks.Cells.Item($row,$col)   = $_.Name
	$wks.Cells.Item($row,$col++) = $_.GPOID.ToString()
	$wks.Cells.Item($row,$col++) = $_.Created
	$wks.Cells.Item($row,$col++) = $_.Modified
	$wks.Cells.Item($row,$col++) = $_.WMIFilter
	$wks.Cells.Item($row,$col++) = $_.ComputerEnabled
	$wks.Cells.Item($row,$col++) = $_.ComputerVerDir
	$wks.Cells.Item($row,$col++) = $_.ComputerVerSys
	$wks.Cells.Item($row,$col++) = $_.ComputerExtensions
	$wks.Cells.Item($row,$col++) = $_.UserEnabled
	$wks.Cells.Item($row,$col++) = $_.UserVerDir
	$wks.Cells.Item($row,$col++) = $_.UserVerSys
	$wks.Cells.Item($row,$col++) = $_.UserExtensions
	$wks.Cells.Item($row,$col++) = $_.Links
	$wks.Cells.Item($row,$col++) = $_.LinksEnabled
	$wks.Cells.Item($row,$col++) = $_.LinksNoOverride
	$wks.Cells.Item($row,$col++) = $_.Owner
	$wks.Cells.Item($row,$col++) = $_.SecurityPermissions
	$wks.Cells.Item($row,$col++) = $_.TotalSize
	$wks.Cells.Item($row,$col++) = $_.ADMSize
	$wks.Cells.Item($row,$col++) = $_.ADMFiles
	$wks.Cells.Item($row,$col++) = $_.XMLReport
	$wks.Cells.Item($row,$col++) = $_.Differences
	$wks.Cells.Item($row,$col++) = $_.ExportDate
	$wks.Cells.Item($row,$col++) = $_.HTMLReport
	}

#Adjust Formatting to make it easier to read
$wks.Range("I:I").Columns.ColumnWidth = 150
$wks.Range("M:M").Columns.ColumnWidth = 150
$wks.Range("N:N").Columns.ColumnWidth = 150
$wks.Range("S:S").Columns.ColumnWidth = 150
$wks.Range("Q:Q").Columns.ColumnWidth = 150
$wks.Range("U:U").Columns.ColumnWidth = 150
$wks.Range("Y:Y").Columns.ColumnWidth = 150
[void]$wks.Range("A:Y").Columns.AutoFit()
$wks.Range("A:U").Columns.VerticalAlignment = $Top
$wks.Range("F:H").Columns.HorizontalAlignment = $Center
$wks.Range("J:L").Columns.HorizontalAlignment = $Center
$wks.Range("R:R").Columns.HorizontalAlignment = $Center
$wks.Range("V:X").Columns.HorizontalAlignment = $Center
#Save the file and close it
$wkb.SaveAs($SaveFile)
$xl.Quit()
#http://technet.microsoft.com/en-us/library/ff730962.aspx
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($xl)
}

}#begin

end{
if ($Output2Excel){
	write-verbose "Exporting information to Excel..."
	Out2Excel $script:AllGPOs $DestinationFolder
	}
else{
	$script:AllGPOs | select Name, GPO_ID, Created, Modified, WMIFilter, ComputerEnabled, ComputerVerDir, ComputerVerSys, ComputerExtensions, UserEnabled, UserVerDir, UserVerSys, UserExtensions, Links, LinksEnabled, LinksNoOverride, Owner, SecurityPermissions, TotalSize, ADMSize, ADMFiles, XMLReport, Differences, HTMLReport, ExportDate | sort Name
	}
}