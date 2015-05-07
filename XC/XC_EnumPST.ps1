[CmdletBinding()]
param(
[Parameter(Position=0)][ValidateNotNullorEmpty()]
[string]$HomeShare = "\\server\home$",
[string]$Filter = "*.pst",
[switch]$MailboxSize=$true
)

process{
#$users = gci -Path $HomeShare -Directory -Filter | select -first 20
$users = gci -Path $HomeShare -Directory -Filter | get-random -count 20
#$users = gci -Path $HomeShare -Directory
$i = 0
foreach ($user in $users){
	$i++
	write-progress -id 1 -activity "Enumeration Script" -status "Processing $($user.Name)" -percentComplete (($i/$users.Count)*100)
	EnumFolder $user.Name $user.FullName 3
	if ($MailboxSize){GetMailboxSize $user.Name}
	}#end foreach user
}

begin{
#check powershell version
if ((Get-Host).Version.Major -lt 3){Write-Error "Powershell version must be 3 or greater, script execution will end";exit}
$MyDocs = [Environment]::getfolderpath("mydocuments")
$script:outpst = @()
if ($MailboxSize){
	$Options = New-PSSessionOption -SkipCACheck -SkipCNCheck
	#change array of CAS servers beforehand running the script
	$ExchangeServer = (get-random ("cashub1","cashub2"))
	$XCSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$ExchangeServer/PowerShell/ -Authentication Kerberos -Name "RemoteXC" -SessionOption $Options
	Import-PSSession $XCSession -EA stop
	}

Function EnumFolder ($parent,$folder,$depth){
#if depth = 0 then skip loop
if ([bool]$depth){
	$depth--
	$files = gci -Path $folder -File -Filter $Filter
	$j = 0
	foreach ($file in $files) {
		$j++
		write-progress -id 2 -parentId 1 -activity "Enumerating Files" -status "Getting $($file.name) properties" -percentComplete (($j/$files.Count)*100)
		$UserReport = New-Object PSObject -Property @{
			Username = $parent
			Folder = $folder
			File = $file.Name
			Extension = $file.Extension
			CreateDate = $file.CreationTime
			LastWriteDate = $file.LastWriteTime
			AccessDate = $file.LastAccessTime
			SizeMB = $([System.Math]::Round($file.Length /1Mb,2))
			}
		$script:outpst += $UserReport
		}#end foreach file
	#loop thru subfolders AFTER enumerating files in current folder
	$folders = gci -Path $folder -Directory
	$j = 0
	foreach ($subfolder in $folders) {
		$j++
		write-progress -id 3 -parentId 2 -activity "Enumerating Folders" -status "Inspecting $($subfolder.FullName)" -percentComplete (($j/$folders.Count)*100)
		#iterate Enum loop per subfolder
		EnumFolder $parent $subfolder.FullName $depth
		}
	}
}

Function GetMailboxSize ($username){
write-host "Getting Mailbox Statistics"
#query mailbox
$mailbox  = Get-Mailbox -Identity $username
$mbxStats = Get-MailboxStatistics $mailbox.Name
$MBReport = New-Object PSObject -Property @{
		Username = $username
		Folder = $mailbox.Database
		File = $mailbox.DisplayName
		Extension = "mbx"
		CreateDate = $mailbox.WhenCreated
		LastWriteDate = $mailbox.WhenChanged
		AccessDate = ""
		#SizeMB = $mbxStats.TotalItemSize
		SizeMB = $([math]::Round(($mbxStats.TotalItemSize -replace "(.*\()|,| [a-z]*\)", "")/1MB,2))
		}
$script:outpst += $MBReport
}

}

end{
if($MailboxSize){Remove-PSSession -Name "RemoteXC"}
$OutFile = Join-Path $MyDocs "UserPSTEnumeration.csv"
$script:outpst | sort Username | Export-CSV $OutFile -NoTypeInformation -UseCulture -Force
write-host "saved results to $OutFile"
#$script:outpst
}
