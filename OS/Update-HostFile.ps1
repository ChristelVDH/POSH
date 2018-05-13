#Requires -Version 3.0
#Requires -RunAsAdministrator
[cmdletbinding(DefaultParametersetName="Local")]
param(
[Parameter(ParameterSetName='Local')]
[ValidateScript({ Test-Path $_ })]
$ImportHostsFilePath,
[Parameter(ParameterSetName='Online')]
[parameter()][switch]$DownloadNewVersion,
[Parameter(ParameterSetName='Reset')]
[parameter()][switch]$ResetHostsFile,
[parameter()][switch]$FilteredSelection,
[parameter()][switch]$DisableDNSClientService

)

process{
if ( $ResetHostsFile ) { Reset-HostsFile ; exit }
if ( $DownloadNewVersion ){ $ImportHostsFilePath = Get-NewHostsFile }
if ( Test-Path $ImportHostsFilePath -PathType Leaf ){
	$ImportHostsFilePath = Get-Item $ImportHostsFilePath
	write-Verbose "The import hosts file is: $($ImportHostsFilePath.FullName)"
	$HostEntries = Get-HostEntries -Path $ImportHostsFilePath
	if ( -not ($HostEntries) ){ Write-Warning "No host entries found in importfile, exiting update script...";exit }
	$Hosts = Get-HostEntries -Path $HostsFile
	#if current hosts file has never been altered it contains nothing but comment and examples
	if ( $Hosts ){
		$NewHostEntries = Compare-Object $Hosts $HostEntries -Property "HostName" -PassThru | ? { $_.sideindicator -eq "=>" }
		if (-not ($NewHostEntries) ){ Write-Warning "No new host entries found, exiting update script...";exit }
		write-Verbose "there are $($NewHostEntries.count) new entries found "
		if ( $FilteredSelection ){
			$AddHostEntries = $NewHostEntries | Out-GridView -Title "select the host entries to be added" -PassThru
			write-Verbose "you have selected $($AddHostEntries.Count) entries to add to your hosts file"
			}
		else { $AddHostEntries = $NewHostEntries }
		}
	#if current hosts file contains no hosts yet then add all new imported host entries
	else { $AddHostEntries = $HostEntries }
	if( Get-Confirmation -prompt "Do you want to update your hosts file with $($AddHostEntries.count) new entries?" ){
		$Hosts += ( $AddHostEntries | Sort Hostname -Unique )
		$Hosts += New-Object PSObject -Property @{PSTypeName = 'My.HostEntry';IP = "";HostName = "";Comment = "#Update-Host Script ( https://github.com/chriskenis )"}
		$Hosts += New-Object PSObject -Property @{PSTypeName = 'My.HostEntry';IP = "";HostName = "";Comment = "#$($AddHostEntries.Count) entries added on dd $(Get-Date) $($nl)"}
		write-Verbose "$($AddHostEntries.Count) entries will be added to $($HostsFile.FullName)"
		Write-HostsFile -HostEntries $Hosts
		Write-Verbose "clearing DNS cache so the new hosts file is in effect immediately after update"
		Clear-DnsClientCache
		if ($DisableDNSClientService){Set-Service DNSCache -Status Stopped -StartupType Manual}
		}
	else { Write-Warning "update of hosts file skipped by user action" }
	}
else{ Write-Error "something went wrong while updating the hosts file" }
}

begin {
$nl = [Environment]::NewLine
#debug host file
$HostsFile = Get-Item "$($env:windir)\system32\Drivers\etc\hosts"

Function Get-NewHostsFile {
param(
$HostsFileArchive = "hosts.zip",
$HostsFileURL = "http://winhelp2002.mvps.org",
$DownloadFolder = [Environment]::GetFolderPath("MyDocuments")
)
#download zip file and place it in folder under the same name
$HostsFileURL = "$($HostsFileURL)/$($HostsFileArchive)"
$DownloadHostsFilePath = "$DownloadFolder\$HostsFileArchive"
try{
	(New-Object Net.WebClient).DownloadFile($HostsFileURL,$DownloadHostsFilePath)
	#extract zip as new file and overwrite previous download
	$HostsFileExtractFolder = "$DownloadFolder\HostsUpdate"
	New-Item $HostsFileExtractFolder -ItemType Directory -ErrorAction SilentlyContinue
	$NewHostsFile = "$HostsFileExtractFolder\HOSTS.hosts"
	#remove file if it already exists, return no error if it doesn't
	Remove-Item $NewHostsFile -ErrorAction SilentlyContinue
	Add-Type -Assembly 'System.IO.Compression.FileSystem'
	$zip = [System.IO.Compression.ZipFile]::OpenRead( $DownloadHostsFilePath )
	$zip.Entries | where {$_.Name -eq 'HOSTS'} | foreach {[System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, $NewHostsFile, $true)}
	$zip.Dispose()
	write-Verbose "found new hosts file: $($NewHostsFile)"
	}
catch{
	Write-warning "$($_.Exception)"
	$NewHostsFile = ""
	}
return $NewHostsFile
}

Function Get-HostEntries {
param(
[System.IO.FileInfo]$Path
)
$HostObjects = @()
$HostEntries = ( Get-Content $Path.FullName ) 
Write-Verbose "found $($HostEntries.Count) host entries in $($Path.FullName)"
#skip first 31 lines containing commentary only
foreach ($HostEntry in $HostEntries[31..($HostEntries.Length -2)]){
	switch -regex ($HostEntry) {
		'^\s*([0-9\.\:]+)' {
			$HostValues = $HostEntry -split '[\s]',3
			$HostObject = New-Object PSObject -Property @{
				PSTypeName = 'My.HostEntry'
				IP = $HostValues[0]
				HostName = $HostValues[1]
				Comment = $HostValues[2]
				}
			Write-Verbose "Host entry found for $($HostObject.HostName) with IP Address $($HostObject.IP) and $($HostObject.Comment)"
			$HostObjects += $HostObject
			}
		}
	}
return ( $HostObjects | Sort Hostname -Unique )
}

Function Write-HostsFile {
param(
[PSTypeName('My.HostEntry')]$HostEntries,
$Delimiter = "`t"
)
if ( -not ($HostEntries) ){ Write-Warning "No host entries to be added, exiting update script...";exit }
write-Verbose "$($HostEntries.Count) entries will be written to $($HostsFile.FullName)"
Copy-Item $HostsFile -Destination "$($HostsFile).BAK" -Force
#$HostEntries | ConvertTo-Csv -Delimiter $Delimiter -NoTypeInformation  | select -Skip 2 | Out-File $HostsFile -Encoding utf8
$stream = [System.IO.StreamWriter]$HostsFile.FullName
$HostEntries | % { $stream.WriteLine("$($_.IP)$($Delimiter)$($_.Hostname)$($Delimiter)$($_.Comment)") }
$stream.Close()
}

Function Backup-HostsFile {
Copy-Item $HostsFile -Destination "$($HostsFile).ORIG" -Force
}

Function Reset-HostsFile {
$hosts = 
@"
# Copyright (c) 1993-2006 Microsoft Corp.
#
# This is a sample HOSTS file used by Microsoft TCP/IP for Windows.
#
# This file contains the mappings of IP addresses to host names. Each
# entry should be kept on an individual line. The IP address should
# be placed in the first column followed by the corresponding host name.
# The IP address and the host name should be separated by at least one
# space.
#
# Additionally, comments (such as these) may be inserted on individual
# lines or following the machine name denoted by a '#' symbol.
#
# For example:
#
#      102.54.94.97     rhino.acme.com          # source server
#       38.25.63.10     x.acme.com              # x client host
# localhost name resolution is handle within DNS itself.
#
# Reset by Update-HostsFile script ( https://github.com/chriskenis )
{0}
{1}
"@
$HostAppend1 = "#       127.0.0.1       localhost"
$HostAppend2 = "#       ::1             localhost"
$build =  Get-CimInstance -Class Win32_OperatingSystem
switch ($build.buildnumber) {
	{9601..18000 -contains $_} { Write-Verbose "Windows 10" }
	{9201..9600 -contains $_} { Write-Verbose "Windows 8.1" }
	{7602..9200 -contains $_} { Write-Verbose "Windows 8" }
	{6002..7601 -contains $_} { Write-Verbose "Windows 7" }
	{6000..6001 -contains $_} { 
		Write-Verbose "Windows Vista"
		$HostAppend1 = "127.0.0.1       localhost"
		$HostAppend2 = "::1             localhost"
		}
	{2600..5999 -contains $_} {
		Write-Verbose "Windows XP / 2003"
		$HostAppend1 = "127.0.0.1       localhost"
		$HostAppend2 = ""
		}
	default { 
		Write-Verbose "Windows 2000 or earlier"
		$HostAppend1 = "127.0.0.1       localhost"
		$HostAppend2 = ""	
		}
	}
try { 
	$hosts -f $HostAppend1, $HostAppend2 | Out-File -Encoding "ASCII" $HostsFile -Force 
	Write-Verbose "the hosts file has been reset to default as per advice of Microsoft KB 972034"
	}
catch { Write-Error "$($_.Exception)" }
}

Function Get-Confirmation {
param(
$title = 'Update hosts file',
$prompt
)
$No = New-Object System.Management.Automation.Host.ChoiceDescription '&No','Aborts the update'
$Yes = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes','Continue'
$options = [System.Management.Automation.Host.ChoiceDescription[]] ($No,$Yes)
$choice = $host.ui.PromptForChoice($title,$prompt,$options,0)
Write-Verbose "answer to $($title) is $($choice)"
return $choice
}

}

end{

}
