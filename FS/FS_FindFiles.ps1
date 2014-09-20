Param (
[Parameter(Position=0,ValueFromPipeline=$True)]
[alias("Name","ComputerName")]$Computer = @($env:computername),
[string[]] $Paths = @("C:\Uniface\UF93\","C:\Oracle\v9\"),
[string[]] $FileNames = @("zis.vbs","version.txt")
)

process{
if (Test-Connection -ComputerName $Computer -Count 1 -Quiet){
	foreach ($Path in $Paths){
		foreach ($FileName in $FileNames){
			$Filter = "$Path\$FileName" -replace '\\','\\'
			FindFiles $Computer $Filter
			}
		}
	}
else {
	Write-Host "$Computer cannot be reached"
	}
}

begin{
$script:objOut = @()
Function FindFiles ($Computer, $Filter){
try{
	$Files = Gwmi -namespace "root\CIMV2" -computername $Computer -class CIM_DataFile -filter "Name = '$Filter'"
	# $Files = Gwmi -computername $Computer -class Win32_Directory -filter "FileName = '$Filter'"
	if ($Files){
		foreach ($File in $Files){
			$Result = New-Object PSObject -Property @{
				Host = [string]$Computer
				Path = $File.Name
				FileSize = "$([math]::round($File.FileSize/1KB)) KB"
				Modified = [System.Management.ManagementDateTimeconverter]::ToDateTime($File.LastModified).ToShortDateString()
				InUse = ([System.Convert]::ToBoolean($File.InUseCount))
				LastUsed = [System.Management.ManagementDateTimeconverter]::ToDateTime($File.LastAccessed).ToShortDateString()
				}
			$script:objOut += $Result
			}
		}
	}
catch{
	$continue = $False
	write-warning "error querying $Computer"
	Write-Host $($error[0] | fl *)
	}
}
}

end{
$script:objOut
}
