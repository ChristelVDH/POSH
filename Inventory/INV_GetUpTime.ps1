Param (
[Parameter(Position=0,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$true)]
[alias("Name","ComputerName")][string[]]$Computers=@($env:ComputerName),
[switch] $Output
)

process{
foreach ($Computer in $Computers){
	if (Test-Connection -ComputerName $Computer -Count 1 -Quiet){
		write-host "Getting Uptime for $Computer" -foregroundcolor green
		$Result = GetUpTime $Computer
		$Global:objUpTime += $Result
		}
	else {
		Write-Output $("$($Computer) cannot be reached")
		}
	}
}

begin{
$Global:objUpTime = @()
$nl = [Environment]::NewLine

Function GetUpTime ($HostName){
try{
	$UpTime = [System.Management.ManagementDateTimeconverter]::ToDateTime((Get-WmiObject -Class Win32_OperatingSystem -Computer $HostName).LastBootUpTime)
	$UpTimeSpan = New-TimeSpan -start $UpTime -end $(Get-Date -Hour 8 -Minute 0 -second 0)
	$Filter = @{ProviderName= "USER32";LogName = "system"}
	$Reason = (Get-WinEvent -ComputerName $HostName -FilterHashtable $Filter | where {$_.Id -eq 1074} | Select -First 1)
	$Result = New-Object PSObject -Property @{
		Date = $(Get-Date -Format d)
		ComputerName = $HostName
		LastBoot = $UpTime
		Reason = [regex]::Replace($Reason.Message,$nl," == ")
		Days = $($UpTimeSpan.Days)
		Hours = $($UpTimeSpan.Hours)
		Minutes = $($UpTimeSpan.Minutes)
		Seconds = $($UpTimeSpan.Seconds)
		}
	return $Result
	}
catch{
	write-error $error[0]
	return $null
	}
}

}

end{
if ($Output){
	[string]$OutputLog = ([environment]::getfolderpath("mydocuments")) + "\" + "Servers_Uptime.csv"
	$Global:objUpTime | ConvertTo-Csv -Delimiter ";" -NoTypeInformation | out-file $OutputLog
	}
else{
	$Global:objUpTime | Select Date, ComputerName, Lastboot, Reason, Days, Hours, Minutes, Seconds | fl
	}
}