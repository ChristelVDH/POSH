<#
.SYNOPSIS
This function will display the status of Scheduled Task in the Root Folder (Not Recursive).

.DESCRIPTION
This function will display the status of Scheduled Task in the Root Folder (Not Recursive).  The function uses the
Schedule.Service COM Object to query information about the scheduled task running on a local or remote computer.

.PARAMETER ComputerName
A single Computer or an array of computer names.  The default is localhost ($env:COMPUTERNAME).

.EXAMPLE
Get-SchedTasks -ComputerName Server01
This example will query any scheduled task, located in Root Task Folder, of Server01.

.LINK
This Function is based on information from:
http://msdn.microsoft.com/en-us/library/windows/desktop/aa446865(v=vs.85).aspx

.NOTES
Author: Brian Wilhite
Email:  bwilhite1@carolina.rr.com
Date:   02/22/2012
#>

[CmdletBinding()]
param(
[Parameter(Position=0,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$true)]
[alias("Name","ComputerName")][string[]]$Computers = @($env:computername)
)

Begin{
$script:objOutput = @()
$script:TaskStatus = "Unknown","Disabled","Queued","Ready","Running"
}

Process{
foreach ($Computer in $Computers){
	write-host "Getting scheduled tasks for $Computer" -foregroundcolor green
	if (Test-Connection -ComputerName $Computer -Count 1 -Quiet -EA Stop){
		Try{
			#Defining Schedule.Service Variable as COM object and connecting to...
			$SchedService = New-Object -ComObject Schedule.Service
			$SchedService.Connect([string]$Computer)
			$RootTasks = $SchedService.GetFolder("").GetTasks("")
			Foreach ($Task in $RootTasks){
				$script:objOutput += New-Object PSObject -Property @{
					ServerName=[string]$Computer
					TaskName=$Task.Name
					RunAs=(([xml]$Task.Xml).DocumentElement.Principals.Principal.UserID).Trim()
					Enabled=$Task.Enabled
					Status=$script:TaskStatus[$Task.State]
					LastRunTime=$Task.LastRunTime
					Result=$Task.LastTaskResult
					NextRunTime=$Task.NextRunTime
					}
				}
			}
		Catch {write-error "for $([string]$Computer): $($Error[0].Exception)"}
		}
	else{Write-warning $("$([string]$Computer) cannot be reached")}
	}
}#process

end{
$script:objOutput
}