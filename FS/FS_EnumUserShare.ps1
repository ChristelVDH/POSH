param(
[Parameter(Position=0,ValueFromPipeline=$True)][ValidateNotNullorEmpty()]
[string[]]$Share = @("\\company.domain\start\users","\\fs02\TSprofiles"), 
[string[]]$Regex = "^_",
[switch] $Rename,
[switch] $FolderSize,
[switch] $Output
)

process{
$i=0
write-progress -id 1 -activity "Getting SubDirs from $Share" -status "..." -percentComplete ($i);
$DirList = @(Get-ChildItem $Share | ?{$_.PSIsContainer})
Foreach ($Dir in $Dirlist){
	# if foldername matches regex then skip
	if(([regex]::IsMatch($Dir.Name,$Regex))){
		$Action = "Skip"
		$Reason = "Regex match"
		}
	else{
		# remove domain suffix if present
		$domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name
		$User = $Dir.Name -replace(".$domain","")
		$User = $Dir.Name -replace(".$($env:UserDomain)","")
		try{
			$ADuser = Get-ADUser $User -Properties WhenChanged
			switch ($Aduser.enabled){
				True {
					$Action = "Skip"
					$Reason = "Active User"
					}
				False {
					If ($ADuser.WhenChanged -lt ($(Get-Date).AddMonths(-$InActiveMonths))){
						$Action = "Disable"
						$Reason = "disabled user > $InActiveMonths months"
						}
					Else{
						$Action = "Delete"
						$Reason = "disabled user < $InActiveMonths months"
						}
					}
				}
			}
		catch{
			$Action = "Unknown"
			$Reason = "Unknown User"
			}
		}
	$FolderDet = FolderInfo $Dir.Fullname
	$Status = HandleDir $Dir $Action $Rename
	$Result = New-Object PSObject -Property @{
		Share = [string]$Share
		Time = Get-Date
		Directory = $Dir.Fullname
		User = $User
		Size = "$($FolderDet.Size) MB"
		ItemCount = $FolderDet.ItemCount
		AvgItemSize = "$($FolderDet.AverageItemSize) MB"
		Status = $Status
		Reason = $Reason
		}
	$script:objOut += $Result
	$i += 1
	$a = ($i/$($DirList.count)*100)
	write-progress -id 1 -activity "Getting SubDirs from $Share" -status "$("{0:N0}" -f $a)% Processing $($Dir.Fullname)" -percentComplete ($a)
	}
}

begin{
$script:objOut = @()
$InActiveMonths = 6

Function FolderInfo($path){
# Gets the Directory size including hidden en systemfolders
$Size = $ItemCount = $AverageItemSize = $null
try{
	if ($FolderSize){
		$Folder = @(Get-ChildItem -path $path -recurse -force -EA stop)
		$Size = ("{0:n2}" -f (($Folder | Measure-Object -property length -sum).sum / 1MB))
		$ItemCount = ($Folder | ?{!($_.PSIsContainer)}).Count
		$AverageItemSize = [System.Math]::Round($Size/$ItemCount, 2)
		}
	}
catch{
	write-host $Error[0].Exception.InnerException.Message.ToString().Trim()
	}
finally{
	$Result = New-Object PSObject -Property @{
		Size = $Size
		ItemCount = $ItemCount
		AverageItemSize = $AverageItemSize
		}
	return $Result
	}
}

Function HandleDir ($Dir, $Action, $Handle){
try{
	switch ($Action){
		'Delete'{
			if ($Handle){Rename-Item -path $Dir.FullName -NewName "_Deleted_" + $Dir.Name}
			$Result = "Deleted"
			}
		'Disable'{
			if ($Handle){Rename-Item -path $Dir.FullName -NewName "_Disabled_" + $Dir.Name}
			$Result = "Disabled"
			}
		'Unknown'{
			if ($Handle){Rename-Item -path $Dir.FullName -NewName "_Unknown_" + $Dir.Name}
			$Result = "Unknown"
			}
		'Skip'{
			$Result = "Skipped"
			}
		Default{
			$Result = "Default"
			}
		}
	}
catch{
	$Result = $Error[0].Exception.InnerException.Message.ToString().Trim()
	}
return $Result
}
}
	
end{
if ($Output){
	$DateRevMin = get-date -uformat "%Y-%m-%d"
	$LogFile = ($([environment]::getfolderpath("mydocuments")) + "\" + $DateRevMin + "UserShare_CleanUp.csv")
	$script:objOut | Select Share, Time, Directory, User, Size, ItemCount, Average, Status, Reason | Export-CSV $LogFile -NoTypeInformation -Encoding UTF8
	}
else{
	$script:objOut
	}
}