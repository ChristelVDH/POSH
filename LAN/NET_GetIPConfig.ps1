param (
[Parameter(Position=0,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$true)]
[alias("Name","ComputerName")][string[]]$Computer = @($env:computername),
[switch] $Output
)
begin {
$script:node = @()
}

process {
if(Test-Connection -ComputerName $Computer -Count 1 -ea 0) {
	write-host "Getting Network config for $Computer" -foregroundcolor green
	$NICs = Get-WmiObject Win32_NetworkAdapterConfiguration -ComputerName $Computer | ? {$_.IPEnabled}
	foreach ($NIC in $NICs) {
		if ($NIC.DNSServerSearchOrder){$DNSServers = $([string]::join(",", $NIC.DNSServerSearchOrder))}
		else{$DNSServers = "NULL"}
		if ($NIC.DNSDomainSuffixSearchOrder){$SuffixSearch = $([string]::join(",", $NIC.DNSDomainSuffixSearchOrder))}
		else{$SuffixSearch = "NULL"}
		$script:node += New-Object -Type PSObject -Property @{
			DNSHostName = $NIC.DNSHostName
			DNSSuffix = $NIC.DNSDomain
			IPAddress = $NIC.IpAddress[0]
			SubnetMask = $NIC.IPSubnet[0]
			Gateway = $($NIC.DefaultIPGateway)
			IsDHCPEnabled = $NIC.DHCPEnabled
			DNSServers = $DNSServers
			SuffixSearch = $SuffixSearch
			MACAddress = $NIC.MACAddress
			}
		}
	}
}

end {
$script:node | Select DNSHostName, DNSSuffix, SuffixSearch, DNSServers, IsDHCPEnabled, MACAddress, IPAddress, SubnetMask, Gateway 
}