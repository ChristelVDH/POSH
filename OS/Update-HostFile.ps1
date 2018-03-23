#Requires -Version 3.0
#Requires -RunAsAdministrator
[cmdletbinding(DefaultParametersetName="Local")]
param(
[Parameter(ParameterSetName='Local')]
[ValidateScript({ Test-Path $_ })]
$ImportHostFilePath,
[Parameter(ParameterSetName='Online')]
[parameter()][switch]$DownloadNewVersion,
[parameter()][switch]$FilteredSelection,
[parameter()][switch]$DisableDNSClientService
)

process{
if ( $DownloadNewVersion ){ $ImportHostFilePath = Get-NewHostFile }
if ( Test-Path $ImportHostFilePath -PathType Leaf ){
	$ImportHostFilePath = Get-Item $ImportHostFilePath
	write-Verbose "The import hosts file is: $($ImportHostFilePath.FullName)"
	$HostEntries = Get-HostEntries -Path $ImportHostFilePath
	if ( -not $HostEntries ){ Write-Warning "No host entries found in importfile, exiting update script...";exit }
	$Hosts = Get-HostEntries -Path $HostFile
	#if current hosts file has never been altered it contains nothing but comment and examples
	if ( $Hosts ){
		$NewHostEntries = Compare-Object $Hosts $HostEntries -Property "HostName" -PassThru | ? { $_.sideindicator -eq "=>" }
		if (-not $NewHostEntries){ Write-Warning "No new host entries found, exiting update script...";exit }
		write-Verbose "there are $($NewHostEntries.count) new entries found "
		if ($FilteredSelection){
			$AddHostEntries = $NewHostEntries | Out-GridView -Title "select the host entries to be added" -PassThru
			write-Verbose "you have selected $($AddHostEntries.Count) entries to add to your hosts file"
			}
		else { $AddHostEntries = $NewHostEntries }
		}
	#if current hosts file contains no hosts yet then add all new imported host entries
	else { $AddHostEntries = $HostEntries }
	if( Get-Confirmation -prompt "Do you want to update your hosts file with $($AddHostEntries.count) new entries?" ){
		$Hosts += ( $AddHostEntries | Sort-Object -Unique )
		$Hosts += New-Object PSObject -Property @{PSTypeName = 'My.HostEntry';IP = "";HostName = "";Comment = "#Update-Host Script (https://github.com/chriskenis)"}
		$Hosts += New-Object PSObject -Property @{PSTypeName = 'My.HostEntry';IP = "";HostName = "";Comment = "#$($AddHostEntries.Count) entries added on dd $(Get-Date) $($nl)"}
		write-Verbose "$($AddHostEntries.Count) entries will be added to $($HostFile.FullName)"
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
$HostFile = Get-Item "$($env:windir)\system32\Drivers\etc\hosts"

Function Get-NewHostFile {
param(
$HostFileArchive = "hosts.zip",
$HostFileURL = "http://winhelp2002.mvps.org",
$DownloadFolder = [Environment]::GetFolderPath("MyDocuments")
)
#download zip file and place it in folder under the same name
$HostFileURL = "$($HostFileURL)/$($HostFileArchive)"
$DownloadHostFilePath = "$DownloadFolder\$HostFileArchive"
try{
	(New-Object Net.WebClient).DownloadFile($HostFileURL,$DownloadHostFilePath)
	#extract zip as new file and overwrite previous download
	$HostFileExtractFolder = "$DownloadFolder\HostsUpdate"
	New-Item $HostFileExtractFolder -ItemType Directory -ErrorAction SilentlyContinue
	$NewHostFile = "$HostFileExtractFolder\HOSTS.hosts"
	#remove file if it already exists, return no error if it doesn't
	Remove-Item $NewHostFile -ErrorAction SilentlyContinue
	Add-Type -Assembly 'System.IO.Compression.FileSystem'
	$zip = [System.IO.Compression.ZipFile]::OpenRead( $DownloadHostFilePath )
	$zip.Entries | where {$_.Name -eq 'HOSTS'} | foreach {[System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, $NewHostFile, $true)}
	$zip.Dispose()
	write-Verbose "found new hosts file: $($NewHostFile)"
	}
catch{
	Write-warning "$($_.Exception)"
	$NewHostFile = ""
	}
return $NewHostFile
}

Function Get-HostEntries {
param(
$Path,
$HostsRegex = '^\s*(?<IPAddress>[0-9\.\:]+)[\s]+(?<HostName>[\w\.\-]+)[\s]*(?<Comment>.*)$'
)
$HostObjects = @()
$HostEntries = ( Get-Content $Path.FullName ) -match $HostsRegex | Sort-Object -Unique
Write-Verbose "found $($HostEntries.Count) host entries in $($Path.FullName)"
foreach ($HostEntry in $HostEntries){
	$HostValues = $HostEntry -split '[\s]',3
	$HostObject = New-Object PSObject -Property @{
		PSTypeName = 'My.HostEntry'
		IP = $HostValues[0]
		HostName = $HostValues[1]
		Comment = $HostValues[2]
		}
	#Write-Verbose "Host entry found for $($HostObject.HostName) with IP Address $($HostObject.IP)"
	$HostObjects += $HostObject
	}
return ( $HostObjects | Sort Hostname -Unique )
}

Function Write-HostsFile {
param(
[PSTypeName('My.HostEntry')]$HostEntries,
$Delimiter = "`t"
)
if ( -not $HostEntries ){ Write-Warning "No host entries to be added, exiting update script...";exit }
write-Verbose "$($HostEntries.Count) entries will be written to $($HostFile.FullName)"
Copy-Item $HostFile -Destination "$($HostFile).BAK" -Force
#$HostEntries | ConvertTo-Csv -Delimiter $Delimiter -NoTypeInformation  | select -Skip 2 | Out-File $HostFile -Encoding utf8
$stream = [System.IO.StreamWriter]$HostFile.FullName
$HostEntries | % { $stream.WriteLine("$($_.IP)$($Delimiter)$($_.Hostname)$($Delimiter)$($_.Comment)") }
$stream.Close()
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
