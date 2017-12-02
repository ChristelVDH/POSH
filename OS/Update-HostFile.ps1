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
else {$ImportHostFilePath = gi $ImportHostFilePath }
write-Verbose "the new hosts file is: $($ImportHostFilePath.FullName)"
if ($ImportHostFilePath){
	$HostEntries = Get-Content $ImportHostFilePath.FullName | Where { $_ -notmatch "\#" } | Where {$_.trim() -ne " " }
	if (-not $HostEntries){Write-warning "No host entries found in importfile, exiting update script...";exit}
	$Hosts = Get-Content -Path $HostFile.FullName | Where { $_ -notmatch "\#" } | Where {$_.trim() -ne " " }
	if ($Hosts){
		$NewHostEntries = Compare-Object $Hosts $HostEntries -PassThru | ?{$_.sideindicator -eq "=>"} 
		write-Verbose "there are $($NewHostEntries.count) differences found "
		if ($FilteredSelection){ 
			$AddHostEntries = $NewHostEntries | Out-GridView -Title "select to be added hostentries" -PassThru
			write-Verbose "you have selected $($AddHostEntries.Count) entries to add to your hosts file"
			}
		else { $AddHostEntries = $NewHostEntries }
		}
	else { $AddHostEntries = $HostEntries }
	if(Get-Confirmation "Do you want to update your hosts file with $($AddHostEntries.count) entries?"){
		#sort and deduplicate host entries
		write-Verbose "$($AddHostEntries.Count) entries will be added to $($HostFile.FullName)"
		Copy-Item $HostFile -Destination "$($HostFile).BAK" -Force
		Add-Content -path $HostFile.FullName -Value "$($nl)#Update-Host Script dd $(Get-Date)$($nl)" -Encoding UTF8
		$AddHostEntries | Where {$_.trim() -ne " "} | Sort-Object -Unique | Out-File $HostFile.FullName -Append -Encoding UTF8 -Force
		}
	}
else{Write-Error "something went wrong while updating the hosts file"}
}

begin {
$nl = [Environment]::NewLine
#debug host file
$HostFile = gi "$($env:windir)\system32\Drivers\etc\hosts" 


Function Get-NewHostFile{
param(
$HostFileArchive = "hosts.zip",
$HostFileURL = "http://winhelp2002.mvps.org",
$DownloadFolder = [Environment]::GetFolderPath("MyDocuments")
)
#download zip file and place it in folder under the same name
$HostFileURL = "$($HostFileURL)/$($HostFileArchive)"
$DownloadHostFilePath = Join-Path $DownloadFolder $HostFileArchive
try{
	(New-Object Net.WebClient).DownloadFile($HostFileURL,$DownloadHostFilePath)
	#extract zip as new file and overwrite previous download
	$shell = New-Object -ComObject Shell.Application
	$zip = $shell.NameSpace($DownloadHostFilePath)
	$HostFileExtractFolder = Join-Path $DownloadFolder "HostsUpdate"
	New-Item $HostFileExtractFolder -ItemType Directory
	foreach ($item in $zip.items()) { $shell.Namespace($HostFileExtractFolder).CopyHere($item)}
	$HostFilePath = gci $HostFileExtractFolder -File -Filter hosts
	write-Verbose "found new hosts file: $($HostFilePath.FullName)"
	}
catch{
	Write-warning "$($_.Exception)"
	$HostFilePath = ""
	}
return $HostFilePath
}

Function Get-Confirmation ( $question ) {
$title = 'Update hosts file'
$prompt = $question
$No = New-Object System.Management.Automation.Host.ChoiceDescription '&No','Aborts the update'
$Yes = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes','Continue'
$options = [System.Management.Automation.Host.ChoiceDescription[]] ($No,$Yes)
$choice = $host.ui.PromptForChoice($title,$prompt,$options,0)
return $choice
}

}

end{
Clear-DnsClientCache
}