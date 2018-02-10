#Requires -Version 3.0
#Requires -RunAsAdministrator
[cmdletbinding(DefaultParametersetName="Local")]
param(
[Parameter(ParameterSetName='Local')]
[ValidateScript({ Test-Path $_ })]
$ImportHostFilePath,
[Parameter(ParameterSetName='Online')]
[parameter()][switch]$DownloadNewVersion,
[parameter()][switch]$FilteredSelection
)

process{
if ($DownloadNewVersion){$ImportHostFilePath = Get-NewHostFile}
if ($ImportHostFilePath){
	$ImportHostFilePath = Get-Item $ImportHostFilePath
	write-Verbose "the import hosts file is: $($ImportHostFilePath.FullName)"
	$HostEntries = (Get-Content $ImportHostFilePath.FullName) -match $HostsRegex
	if (-not $HostEntries){Write-warning "No host entries found in importfile, exiting update script...";exit}
	$Hosts = (Get-Content -Path $HostFile.FullName) -match $HostsRegex
	if ($Hosts){
		$NewHostEntries = Compare-Object $Hosts $HostEntries -PassThru | ?{$_.sideindicator -eq "=>"} 
		write-Verbose "there are $($NewHostEntries.count) new entries found "
		if ($FilteredSelection){ 
			$AddHostEntries = $NewHostEntries | Out-GridView -Title "select the host entries to be added" -PassThru
			write-Verbose "you have selected $($AddHostEntries.Count) entries to add to your hosts file"
			}
		else { $AddHostEntries = $NewHostEntries }
		}
	else { $AddHostEntries = $HostEntries }
	if(Get-Confirmation -prompt "Do you want to update your hosts file with $($AddHostEntries.count) new entries?"){
		write-Verbose "$($AddHostEntries.Count) entries will be added to $($HostFile.FullName)"
		Copy-Item $HostFile -Destination "$($HostFile).BAK" -Force
		$Hosts += "$($nl)#Update-Host Script (https://github.com/chriskenis)"
		$Hosts += "#$($AddHostEntries.Count) entries added on dd $(Get-Date) $($nl)"
		#sort and deduplicate host entries
		$Hosts += $AddHostEntries | Sort-Object -Unique
		$Hosts | Set-Content $HostFile.FullName -Force
		}
	Write-Verbose "clearing DNS cache so the new hosts file is in effect immediately after update"
	Clear-DnsClientCache
	}
else{Write-Error "something went wrong while updating the hosts file"}
}

begin {
$nl = [Environment]::NewLine
#debug host file
$HostFile = gi "$($env:windir)\system32\Drivers\etc\hosts"
$HostsRegex = '^\s*(?<Address>[0-9\.\:]+)\s+(?<Host>[\w\.\-]+)\s*$'


Function Get-NewHostFile{
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
	$zip = [System.IO.Compression.ZipFile]::OpenRead($DownloadHostFilePath)
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

Function Get-Confirmation {
param(
$title = 'Update hosts file',
$prompt
)
$No = New-Object System.Management.Automation.Host.ChoiceDescription '&No','Aborts the update'
$Yes = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes','Continue'
$options = [System.Management.Automation.Host.ChoiceDescription[]] ($No,$Yes)
$choice = $host.ui.PromptForChoice($title,$prompt,$options,0)
return $choice
}

}

end{

}
