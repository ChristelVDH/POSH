<#
.Synopsis
   get everything you want to know about any computer
.DESCRIPTION
   get inventory from a list of remote computers or run locally thru startup script
.EXAMPLE
   Collect-ComputerData -EnumHardware
   get basic OS data + BIOS information
.EXAMPLE
   Collect-ComputerData -EnumUsers
   get basic OS data + logged on user sessions
.EXAMPLE
   Get-Adcomputer workstation007 | Collect-ComputerData -EnumDrivers
   get basic OS data + known system devices from an AD computer object
.INPUTS
   can handle pipeline input for computernames
.OUTPUTS
   nested object, can be converted to CLI XML or JSON for database processing
   can be piped to output
.NOTES
   advanced output thru nested custom objects,
   can contain functions that are still in beta
.COMPONENT
   Chriske.Inventory.Computer
.ROLE
   Inventory
.FUNCTIONALITY
   get all Windows OS info for network inventory
#>
[CmdletBinding()]
Param (
	[Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
	[Alias("Name", "ComputerName")][string[]]$Computers = @($env:ComputerName),
	[Parameter()][ValidateSet('Hardware', 'Drivers', 'Software', 'Users', 'All')][string[]]$Enumerate = 'All'
)

process {
	Write-Progress -activity "Getting Inventory report" -status "Starting" -id 1
	foreach ($Computer in $Computers) {
		[int]$pct = ($script:cntr / $Computers.count) * 100
		$NodeInfo = New-Object PSObject -Property @{
			Host = $Computer
			Date = (Get-Date)
		}
		if (Test-connection $Computer -quiet -count 1) {
			Write-Progress -CurrentOperation "Getting Computer Inventory" -Status $Computer -Id 1 -PercentComplete $pct -Activity "OS details..."
			write-verbose -Message "Inventory report of $($Enumerate -join ',') for $($Computer)"
			$NodeInfo | add-member NoteProperty -Name OS -Value (GetOS $Computer)
			$NodeInfo | add-member NoteProperty -Name POWER -Value (GetActivePowerPlan $Computer)
			$NodeInfo | add-member NoteProperty -Name Environment -Value (GetEnvVariables $Computer)
			$NodeInfo | add-member NoteProperty -Name WSMAN -Value (GetShares $Computer)
			[byte]$EnumCtr = 1
			switch ($Enumerate) {
				'Hardware' {
					Write-Progress -CurrentOperation "Getting Hardware" -Status $Computer -ParentId 1 -Id 2 -PercentComplete ($EnumCtr / $Enumerate.Count * 100) -Activity "Hardware..."
					$NodeInfo | add-member NoteProperty -Name BIOS -Value (GetBIOS $Computer)
					$NodeInfo | add-member NoteProperty -Name CPU -Value (GetProcessor $Computer)
					$NodeInfo | add-member NoteProperty -Name RAM -Value (GetMemory $Computer)
					$NodeInfo | add-member NoteProperty -Name DISK -Value (GetLocalDisk $Computer)
					$NodeInfo | add-member NoteProperty -Name LAN -Value (GetNIC $Computer)
					$EnumCtr++
				}
				'Drivers' {
					Write-Progress -CurrentOperation "Getting Driver details" -Status $Computer -ParentId 1 -Id 2 -PercentComplete ($EnumCtr / $Enumerate.Count * 100) -Activity "Drivers..."
					$NodeInfo | add-member NoteProperty -Name VGA -Value (GetGraphics $Computer)
					$NodeInfo | add-member NoteProperty -Name AUDIO -Value (GetAudio $Computer)
					$EnumCtr++
				}
				'Software' {
					Write-Progress -CurrentOperation "Getting Software Inventory" -Status $Computer -ParentId 1 -Id 2 -PercentComplete ($EnumCtr / $Enumerate.Count * 100) -Activity "Software..."
					Write-Progress -CurrentOperation "Getting Applications" -Status $Computer -ParentId 2 -Id 3 -PercentComplete 33 -Activity "Software..."
					$NodeInfo | add-member NoteProperty -Name SOFT -Value (GetApps $Computer)
					Write-Progress -CurrentOperation "Getting Windows Updates" -Status $Computer -ParentId 2 -Id 3 -PercentComplete 66 -Activity "Software..."
					$NodeInfo | add-member NoteProperty -Name WUPD -Value (GetUpdates $Computer)
					Write-Progress -CurrentOperation "Getting Scheduled Tasks" -Status $Computer -ParentId 2 -Id 3 -PercentComplete 100 -Activity "Software..."
					$NodeInfo | add-member NoteProperty -Name SCHED -Value (GetSchedTasks $Computer)
					$EnumCtr++
				}
				'Users' {
					Write-Progress -CurrentOperation "Getting Login Sessions" -Status $Computer -ParentId 1 -Id 2 -PercentComplete ($EnumCtr / $Enumerate.Count * 100) -Activity "Users..."
					$NodeInfo | add-member NoteProperty -Name USERS -Value (GetLoggedOnUsers $Computer)
					$EnumCtr++
				}
			}
			$Result = "Success"
		}
		else {
			Write-Progress -CurrentOperation "Getting data" -Status $Computer -Id 1 -PercentComplete $pct -Activity "Unreachable..."
			Write-Error -Message "$($Computer) cannot be reached"
			$Result = "Unreachable"
		}
		$script:cntr++
		$NodeInfo | add-member NoteProperty -Name Result -Value $Result
		$script:outInv += $NodeInfo
	}#foreach
}#process

begin {
	$script:outInv = @()
	$script:cntr = 1
	$script:DefErrActPref = $ErrorActionPreference
	switch ($Enumerate) {
		'All' { $Enumerate = @('Hardware', 'Drivers', 'Software', 'Users') }
		Default { $Enumerate = @($Enumerate) }
	}

	Function CheckAdmin {
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
	}

	Function CheckRemote ($Computer) {
		[Bool](Invoke-Command -ComputerName $Computer -ScriptBlock { 1 } -EA SilentlyContinue)
	}

	Function GetOS ($Computer) {
		$SysData = Get-WMIObject -ComputerName $Computer -class Win32_Computersystem
		$OSData = Get-WMIObject -ComputerName $Computer -class Win32_operatingsystem
		$ProductInfo = (WindowsProduct $Computer)
		$DomainRole = "Stand alone workstation", "Member workstation", "Stand alone server", "Member server", "Backup DC", "Primary DC"
		$Result = New-Object PSObject -Property @{
			HostName       = $SysData.Name
			PCType         = ($SysData.description + $SysData.systemtype)
			Model          = $SysData.Model
			CPUSockets     = $SysData.NumberOfProcessors
			LogicCPU       = $SysData.NumberOfLogicalProcessors
			Memory         = "$([math]::round($($OSData.TotalVisibleMemorySize/1024))) MB"
			OSVersion      = ($OSData.Caption + "SP" + $OSData.ServicePackMajorVersion)
			InstallDate    = [System.Management.ManagementDateTimeconverter]::ToDateTime($OSData.InstallDate).ToLongDateString()
			WinDir         = $OSData.WindowsDirectory
			IsDomainMember = $([System.Convert]::ToBoolean($SysData.partofdomain))
			Role           = ($DomainRole[$SysData.DomainRole])
			ProductID      = $ProductInfo.ProductID
			ProductKey     = $ProductInfo.ProductKey
			Build          = $OSData.Version
			BuildType      = $OSData.BuildType
			LastBoot       = [System.Management.ManagementDateTimeconverter]::ToDateTime($OSData.LastBootUpTime).ToLongDateString()
		}
		return $Result
	}

	Function GetBIOS ($Computer) {
		$bioss = @()
		foreach ($bios in (get-wmiobject -ComputerName $Computer -class "Win32_BIOS")) {
			$Result = New-Object PSObject -Property @{
				Manufacturer = $bios.Manufacturer
				Description  = $bios.Description
				Version      = $bios.SMBIOSBIOSVersion
				ReleaseDate  = [System.Management.ManagementDateTimeconverter]::ToDateTime($bios.ReleaseDate).ToLongDateString()
				SerialNr     = $bios.SerialNumber
			}
			$bioss += $Result
		}
		return $bioss
	}

	Function WindowsProduct ($Computer) {
		## retrieve Windows Product Key from any PC by Jakob Bindslet (jakob@bindslet.dk)
		[hashtable]$Result = @{}
		$hklm = 2147483650
		$regPath = "Software\Microsoft\Windows NT\CurrentVersion"
		$rr = [WMIClass]"\\$Computer\root\default:stdRegProv"
		try {
			$data = $rr.GetBinaryValue($hklm, $regPath, "DigitalProductId")
			$binArray = ($data.uValue)[52..66]
			$charsArray = "B", "C", "D", "F", "G", "H", "J", "K", "M", "P", "Q", "R", "T", "V", "W", "X", "Y", "2", "3", "4", "6", "7", "8", "9"
			## decrypt base24 encoded binary data
			For ($i = 24; $i -ge 0; $i--) {
				$k = 0
				For ($j = 14; $j -ge 0; $j--) {
					$k = $k * 256 -bxor $binArray[$j]
					$binArray[$j] = [math]::truncate($k / 24)
					$k = $k % 24
				}
				$ProductKey = $charsArray[$k] + $ProductKey
				If (($i % 5 -eq 0) -and ($i -ne 0)) { $ProductKey = "-" + $ProductKey }
			}
		}
		catch { $ProductKey = "nothing" }
		try { $ProductID = ($rr.GetStringValue($hklm, $regPath, "ProductId")).svalue }
		catch { $ProductID = "nothing" }
		$Result.ProductKey = $ProductKey
		$Result.ProductID = $ProductID
		return $Result
	}

	Function GetProcessor ($Computer) {
		$CPUS = @()
		try {
			$ErrorActionPreference = "Stop"
			foreach ($CPU in (Get-WMIObject -ComputerName $Computer -Class Win32_processor)) {
				$Result = New-Object PSObject -Property @{
					Manufacturer = ($CPU.manufacturer + " " + $CPU.name)
					AddressWidth = ($CPU.AddressWidth).ToString()
					ClockSpeed   = ($CPU.MaxClockSpeed).ToString()
					Cores        = ($CPU.NumberOfCores).ToString()
					L2Cache      = ($CPU.L2CacheSize).ToString()
				}
				$CPUS += $Result
			}
		}
		catch {}
		return $CPUS
		$ErrorActionPreference = $script:DefErrActPref
	}

	Function GetEnvVariables ($Computer) {
		$Envirs = @()
		foreach ($Envir in (Get-WmiObject -ComputerName $Computer -class Win32_Environment | Where-Object { $_.username -eq '<system>' })) {
			$Envirs += New-Object PSObject -Property @{
				Name = $Envir.Name
				Path = $Envir.VariableValue
			}
		}#foreach
		return $Envirs
	}

	function GetActivePowerPlan ($Computer) {
		write-verbose "Getting active plan..."
		try { $result = Get-WmiObject -Class Win32_PowerPlan -Namespace root\cimv2\power -ComputerName $Computer -Filter "IsActive ='True'" | Select-Object ElementName, Description, IsActive }
		catch { $result = "nothing" }
		return $result
	}

	Function GetSpecialFolders() {
		#can this work from remote
		$UserShellFolders = @()
		foreach ($SpecialFolder in (@([system.Enum]::GetValues([System.Environment+SpecialFolder])))) {
			$UserShellFolders += New-Object PSObject -Property @{
				Specialfolder = $Specialfolder
				Path          = [Environment]::getfolderpath($SpecialFolder)
			}
		}#foreach
		return $UserShellFolders
	}

	Function GetLocalDisk ($Computer) {
		$Disks = @()
		foreach ($Disk in (Get-WMIObject -ComputerName $Computer -class Win32_Logicaldisk)) {
			$Result = New-Object PSObject -Property @{
				DriveLetter = $Disk.caption
				Description = $Disk.description
				Label       = $Disk.VolumeName
				FileSystem  = $Disk.FileSystem
				Compressed  = $Disk.compressed
				Size        = ([math]::round(($Disk.size / 1073741824), 2))
				FreeSpace   = ([math]::round(($Disk.freespace / 1073741824), 2))
				VolumeDirty = $Disk.volumedirty
				VolumeName  = $Disk.volumename
			}
			$Disks += $Result
		}
		return $Disks
	}

	Function GetPartitions ($Computer) {
		$Partitions = @()
		foreach ($Partition in (Get-WmiObject -Class Win32_DiskPartition -ComputerName $Computer)) {
			$Partitions += New-Object PSObject -Property @{
				BlockSize       = $Partition.BlockSize
				Bootable        = $Partition.Bootable
				BootLoader      = $Partition.BootPartition
				DeviceID        = $Partition.DeviceID
				Primary         = $Partition.PrimaryPartition
				OffsetAlignment = [bool]($Partition.StartingOffset % 4096)
				SizeGB          = [Math]::Round($Partition.Size / 1GB)
			}
		}
		return $Partitions
	}

	Function GetMemory ($Computer) {
		$RAMs = @()
		# Memory type constants from win32_pysicalmemory.MemoryType
		$RAMtypes = "Unknown", "Other", "DRAM", "Synchronous DRAM", "Cache DRAM", "EDO", "EDRAM", "VRAM", "SRAM", "RAM", "ROM", "Flash", "EEPROM", "FEPROM", "EPROM", "CDRAM", "3DRAM", "SDRAM", "SGRAM", "RDRAM", "DDR", "DDR-2"
		foreach ($RAM in (Get-WMIObject -ComputerName $Computer -class Win32_PhysicalMemory)) {
			$Result = New-Object PSObject -Property @{
				PartNR     = $RAM.PartNumber
				CapacityMB = ($RAM.Capacity / 1073741.824)
				Speed      = $RAM.Speed
				MemType    = ($RAMtypes[$RAM.MemoryType])
				Location   = $RAM.DeviceLocator
			}
			$RAMs += $Result
		}
		return $RAMs
	}

	Function GetGraphics ($Computer) {
		$displays = @()
		foreach ($display in (Get-WMIObject -ComputerName $Computer -class Win32_VideoController)) {
			$Result = New-Object PSObject -Property @{
				DisplayName   = $display.Name
				DriverVersion = $display.DriverVersion
				ColorDepth    = $display.CurrentBitsPerPixel
				Resolution    = $display.VideoModeDescription
				RefreshRate   = "$($display.CurrentRefreshRate) Hz"
			}
			$displays += $result
		}
		return $displays
	}

	Function GetAudio ($Computer) {
		$soundcards = @()
		foreach ($soundcard in (Get-WMIObject -ComputerName $Computer -class win32_SoundDevice)) {
			$Result = New-Object PSObject -Property @{
				Caption      = $soundcard.Caption
				Manufacturer = $soundcard.manufacturer
				# $Filter = "DeviceID -eq '" + $soundcard.DeviceID + "'"
				# $PNPdriver = Get-WMIObject -ComputerName $Computer -class Win32_PNPSignedDriver -Filter $Filter
				# DriverName = $PNPdriver.DriverName
				# DriverVersion = $PNPdriver.DriverVersion
				# $DriverDate = [System.Management.ManagementDateTimeconverter]::ToDateTime($PNPdriver.DriverDate).ToShortDateString()
				# DriverDate = $DriverDate
			}
			$soundcards += $Result
		}
		return $soundcards
	}

	Function GetNIC ($Computer) {
		$NICs = @()
		foreach ($NIC in (Get-WmiObject -ComputerName $Computer -class win32_networkadapter | Where-Object { -not [string]::IsNullOrWhiteSpace($_.MACAddress) })) {
			$NICs += New-Object PSObject -Property @{
				AdapterName      = $NIC.Name
				AdapterType      = $NIC.AdapterType
				MacAddress       = $NIC.MACAddress
				Manufacturer     = $NIC.Manufacturer
				PhysicalAdapter  = ([System.Convert]::ToBoolean($NIC.PhysicalAdapter))
				NetworkEnabled   = ([System.Convert]::ToBoolean($NIC.NetEnabled))
				ConnectedNetwork = $NIC.NetConnectionID
			}
		}#foreach
		return $NICs
	}

	Function GetShares($Computer) {
		$Shares = @()
		$ShareTypes = @{"2147483648" = "admin"; "2147483649" = "print"; "0" = "file"; "2147483651" = "ipc" }
		foreach ($Share in (Get-WmiObject -ComputerName $Computer -class Win32_Share)) {
			$Shares += New-Object PSObject -Property @{
				Name = $Share.Name
				Type = $ShareTypes."$($Share.Type)"
			}
		}
		return $Shares
	}

	Function GetStartUpApps($Computer) {
		$StartUpApps = @()
		$hkcr = 2147483648 #Classes Root
		$hkcu = 2147483649 #Current User
		$hklm = 2147483650 #Local Machine
		$hku = 2147483652 #Users
		$hkcc = 2147483653 #Current Config
		$rr = [WMIClass]"\\$Computer\root\default:stdRegProv"
		#$StartupCommands = (Get-WmiObject -ComputerName $Computer -class "Win32_StartupCommand")
		#enum of registry items under run key
		$regPath = "Software\Microsoft\Windows\CurrentVersion"
		$HKLMApps = @($rr.GetStringValue($hklm, $regPath, "Run"))
		foreach ($HKLMApp in $HKLMApps) {
			$StartUpApps += New-Object PSObject -Property @{
				StartUpType = "HKLM"
			}
		}
		$HKCUApps = @($rr.GetStringValue($hkcu, $regPath, "Run"))
		foreach ($HKCUApp in $HKCUApps) {
			$StartUpApps += New-Object PSObject -Property @{
				StartUpType = "HKCU"
			}
		}
		$MachineRuns = ""
		foreach ($MachineRun in $MachineRuns) {
			$StartUpApps += New-Object PSObject -Property @{
				StartUpType = "AllUsers"
			}
		}
		$UserRuns = ""
		foreach ($UserRun in $UserRuns) {
			$StartUpApps += New-Object PSObject -Property @{
				StartUpType = "User"
			}
		}
		return $StartUpApps
	}

	Function GetApps ($Computer) {
		#$ProductUsers = dir hklm:\software\microsoft\windows\currentversion\installer\userdata
		#$Products = $ProductUsers |% {$p = [io.path]::combine($_.pspath, 'Products'); if (test-path $p){dir $p}}
		#$ProductInfos = $Products |% {$p = [io.path]::combine($_.pspath, 'InstallProperties'); if (test-path $p){gp $p}}
		$Products = (Get-WmiObject -class Win32_Product -ComputerName $Computer | Select-Object Name, Version, ProductID, Vendor, InstallDate, InstallSource)
		return $Products
	}

	Function GetUpdates ($Computer) {
		$Updates = @()
		foreach ($Update in (Get-WmiObject -ComputerName $Computer -class "Win32_QuickFixEngineering")) {
			$Result = New-Object PSObject -Property @{
				HotFixID    = $Update.HotFixID
				HotFixType  = $Update.Description
				InstallDate = $Update.InstalledOn
				InstalledBy = $Update.InstalledBy
			}
			$Updates += $Result
		}
		return $Updates
	}

	Function GetSwapFile ($Computer) {
		$SwapFiles = @()
		foreach ($SwapFile in (Get-WmiObject -class Win32_PageFile -ComputerName $Computer)) {
			$SwapFiles += New-Object PSObject -Property @{
				Name        = $PageFile.Name
				SizeGB      = [int]($PageFile.FileSize / 1GB)
				InitialSize = $PageFile.InitialSize
				MaximumSize = $PageFile.MaximumSize
			}
			return $SwapFiles
		}
	}

	Function GetSchedTasks($Computer) {
		$SchedTasks = @()
		write-verbose -Message "Getting scheduled tasks for $($Computer)"
		$Tasks = Get-ScheduledTask -CimSession $Computer | Sort-Object TaskPath, TaskName
		Foreach ($Task in $Tasks){
			$TaskInfo = Get-ScheduledTaskInfo -TaskName $Task.Name
			$SchedTasks += New-Object psobject -Property @{
				TaskPath = $TaskInfo.TaskPath
				TaskName = $Task.Name
				Action = $Task.CurrentAction
				Status = $Task.State
				LastRunTime = $TaskInfo.LastRunTime
				NextRunTime = $TaskInfo.NextRunTime
				RunAs = $Task.Principal.UserId
				Result = $TaskInfo.LastTaskResult

			}
		}
		return $SchedTasks
	}

	Function GetServices($Computer) {
		$Services = @()
		try {
			foreach ($Service in (Get-WmiObject -Class Win32_Service -ComputerName $Computer)) {
				$Result = New-Object PSObject -Property @{
					Displayname    = $Service.DisplayName
					ServiceAccount = $Service.StartName
					State          = $Service.State
					StartMode      = $Service.StartMode
				}
				if ($Service.DisplayName) { $Services += $Result }
			}
		}
		Catch {}
		return $Services
	}

	Function GetSessions ($Computer) {
		$LocalSessions = @()
		$regex = '.+Domain="(.+)",Name="(.+)"$'
		try {
			foreach ($Session in (Get-WmiObject Win32_LoggedOnUser -ComputerName $Computer | Select-Object Antecedent -Unique)) {
				$Session.Antecedent -match $regex
				$LocalSessions += New-Object PSObject -Property @{
					Domain = $matches[1]
					User   = $matches[2]
				}
			}
		}
		catch {}
		return $LocalSessions
	}

	Function GetLoggedOnUsers ($Computer, $Process = "explorer.exe") {
		$LoggedOnUsers = @()
		try {
			foreach ($Session in (Get-WMIObject Win32_Process -filter "name='$Process'" -ComputerName $Computer)) {
				$owner = $Session.GetOwner()
				$LoggedOnUsers += New-Object PSObject -Property @{
					Domain           = $owner.Domain
					User             = $owner.User
					SessionID        = $Session.SessionID
					WorkingDir       = $Session.ExecutablePath #Path
					SessionStartDate = [System.Management.ManagementDateTimeconverter]::ToDateTime($Session.CreationDate).ToLongDateString()
				}
			}
		}
		catch {}
		return $LoggedOnUsers | Sort-Object | Get-Unique
	}

}#begin

end {
	if ($Enumerate -notcontains 'Hardware') { write-warning "Enumeration of hardware was not enabled" }
	if ($Enumerate -notcontains 'Drivers') { write-warning "Enumeration of drivers was not enabled" }
	if ($Enumerate -notcontains 'Software') { write-warning "Enumeration of software was not enabled" }
	if ($Enumerate -notcontains 'Users') { write-warning "Enumeration of users was not enabled" }
	$script:outInv
}