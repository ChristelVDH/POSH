param (
[Parameter(Position=0,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
[alias("Name","DNSHostName","ComputerName")][object[]]$Computers = @($env:computername),
[string] $Drive = $env:SystemDrive,
[string] $OutputFolder = "D:\Inventory\",
[switch] $FilterDrive,
[switch] $Output, 
[switch] $Invoke
)

begin{
$script:objOut = @()
$script:objErr = @()
$script:cntr = 1
Function WriteErrorLog ($ErrString){
	$script:objErr += $ErrString
	write-verbose $ErrString
	}
}

process{
$activity = "Getting Diskspace report"
Write-Progress -activity $activity -status "Starting" -id 1
foreach ($Computer in $Computers){
	Write-verbose "Diskspace Inventory for: $Computer"
	if ($Computers.count -gt 1){[int]$pct = (($script:cntr++ / $Computers.count) * 100)}
	else {[int]$pct = 100}
	Write-Progress -activity $activity -status $Computer -id 1 -percent $pct -current "querying..."
	if (Test-Connection -ComputerName $Computer -Count 1 -Quiet){
		try{
			$wmifilter = "Drivetype=3"
			if ($FilterDrive){$wmifilter = "DeviceID='$drive'"}
			foreach ($disk in (gwmi -Computer $Computer -Class Win32_logicalDisk -Filter $wmifilter -EA 0)){
				$Result = New-Object PSObject -Property @{
					Today = (Get-Date -format d)
					Host = [string]$Computer
					DriveName = $disk.DeviceID
					VolumeLabel = $disk.VolumeName
					TotalSpaceGB = (($disk.size/1GB).ToString("0.00"))
					FreeSpaceGB = (($disk.FreeSpace/1GB).ToString("0.00"))
					}
				$script:objOut += $Result
				}
			Write-Progress -activity $activity -status $Computer -id 1 -percent $pct -current "succeeded..."
			}
		catch{
			Write-Progress -activity $activity -status $Computer -id 1 -percent $pct -current "failed..."
			WriteErrorLog "$("For ")$([string]$Computer)$(": ")$($error[0] | fl *)"
			$continue = $False
			}
		}
	else {
		Write-Progress -activity $activity -status $Computer -id 1 -percent $pct -current "unreachable..."
		WriteErrorLog $("$([string]$Computer) cannot be reached")
		}
	}#foreach
}#process

end{
if($Output){
	$RepDate = (get-date).toString('dd_MMM')
	$OutputLog = "Diskspace_" + $RepDate + ".csv"
	$script:objOut | select Today, Host, DriveName, VolumeLabel, TotalSpaceGB, FreeSpaceGB | ConvertTo-Csv -Delimiter ";" -NoTypeInformation | out-file (join-path $OutputFolder $OutputLog)
	if ($script:objErr){
		$ErrorLog = "Inv_Get-DiskSpace_errors_dd_" + $RepDate + ".log"
		$script:objErr | out-file (join-path $OutputFolder $ErrorLog)
		}
	if ($Invoke){ Invoke-Item (join-path $OutputFolder $OutputLog)}
	}
else {
	write-host $script:objErr -fore yellow
	$script:objOut | select Today, Host, DriveName, VolumeLabel, TotalSpaceGB, FreeSpaceGB
	}
}
