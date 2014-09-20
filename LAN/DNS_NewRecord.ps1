param(
[string] $DNSServer = ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().pdcroleowner.Name),
[string] $Importfile = "E:\Projects\DNS\hosts.csv",
[string] $DNSZone = ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name),
[switch] $ReversePTR,
[switch] $IPv6
)
<# example CSV import file
name;type;ipaddress;priority;alias
;mx;;15;mail
firewall;A;190.190.130.76;;
testmailgw;A;190.190.130.86;;
vpn;CNAME;;;firewall
test;MX;;15;testmailgw
honeypot-v6;AAAA;2001:6a8:400:8003::2;;
www.subzone;CNAME;;subzone

--> to create "same as parent" A record the Name field is equal to $DNSZone
--> to create "same as parent" MX record the Name field is left blank
--> to create a subzone add .DNSsuffix to any A or CNAME record Name field

#>
process{
# check incoming parameters
If (($DNSServer -eq ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().pdcroleowner.Name)) -or ($DNSZone -eq ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name))){YesNoMenu # are you really, absolutely, positively very sure?}
write-warning "$DNSZone on $DNSServer will be updated with imported records..."
# check DNS zone existence
$DNSzones = @(Get-WmiObject -Class MicrosoftDNS_Zone -ComputerName $DNSserver -Namespace root\microsoftDNS | Select-Object -Property Name)
If (-not ($DNSzones -match $DNSZone)){
	Write-Warning "$DNSZone does not exist yet"
	NewDNSzone $DNSZone
	}
# actual processing of DNS records
$DNSRecords = Import-Csv $Importfile -Delimiter ";"
write-verbose "$($DNSRecords.Count) new DNS records will be imported..."
New-DNSrecord $DNSRecords
}#process

begin{

Function YesNoMenu {
$title = "DNS server selection"
$message = "Do you want to use the autodiscovered DNS server: $DNSServer ?"
$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Continues using $DNSServer for processing DNS records in $DNSZone ."
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Exits DNS script."
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$result = $host.ui.PromptForChoice($title, $message, $options, 0)
switch ($result){
	0 {"$DNSServer will be the target server for updating $DNSZone"} # YES
	1 {Exit} # NO
	}
}

Function FourToSix($IPv4){
$IPv6Prefix = ""
$IPAv4 = [Net.IPAddress]::Parse($IPv4)
$IPAv6 = $IPv6Prefix + ":" + "1000" + ":" + [String]::Join(':', $( $IPAv4.GetAddressBytes() | %{[Convert]::ToString($_, 10).PadLeft(4, '0') } ))
return $IPAv6
}

Function ReversePTR($iDNSrec){
$sHostPtr = $sPtrZone = $sHostPtrv6 = $sPtrZonev6 = ""
$aOctets = $iDNSrec.IPAddress.Split(".")
$sPtrZone = $aOctets[2] + "." + $aOctets[1] + "." + $aOctets[0] + ".in-addr.arpa"
$sHostPtr = $aOctets[3] + "." + $sPtrZone
If ($IPv6){
	$IPv6Address = FourToSix $iDNSrec.IPAddress
	For ($i = 13; $i -gt -1; $i--){
		If (($i -ne 4) -and ($i -ne 9)){$sPtrZonev6 += $IPv6Address[$i] + "."}
		}
	$sPtrZonev6 += "ip6.arpa"
	For ($i = 38; $i -gt -1; $i--){
		switch ($i){
			{4,9,14,19,24,29,34 -eq $_}{write-verbose "skipped"}
			default{$sHostPtrv6 += $IPv6Address[$i] + "."}
			}
		}
	$sHostPtrv6 += "ip6.arpa"
	}
$PTR = new-object PSObject -Property @{
	Host = $sHostPtr
	Zone = $sPtrZone
	Hostv6 = $sHostPtrv6
	Zonev6 = $sPtrZonev6
	}
return $PTR
}

Function New-DNSRecord($DNSrecs){
$objA = [wmiclass]"\\$DNSServer\Root\MicrosoftDNS:MicrosoftDNS_AType"
$objAAAA = [wmiclass]"\\$DNSServer\Root\MicrosoftDNS:MicrosoftDNS_AAAAType"
$objPTR = [wmiclass]"\\$DNSServer\root\MicrosoftDNS:MicrosoftDNS_PTRType"
$objCNAME = [wmiclass]"\\$DNSServer\root\microsoftDNS:MicrosoftDNS_cNameType"
$objMX = [wmiclass]"\\$DNSServer\root\microsoftDNS:MicrosoftDNS_MXType"
$class = 1
$TTL = $Null #3600
foreach ($DNSrec in $DNSrecs){
	try{
		switch ($DNSrec.Type){
			"A" {
				If ($DNSrec.Name -ieq $DNSZone){$DNSAName = $DNSZone}
				Else {$DNSAName = $($DNSrec.Name + "." + $DNSZone)}
				$objA.CreateInstanceFromPropertyData($DNSserver, $DNSZone, $DNSAName , $class, $ttl, $DNSrec.IPAddress)
				}
			"AAAA" {
				$objAAAA.CreateInstanceFromPropertyData($DNSserver, $DNSzone, $($DNSrec.Name + "." + $DNSZone), $class, $ttl, $DNSrec.IPAddress)
				}
			"PTR" {
				If ($ReversePTR){
					$RevPTR = (ReversePTR $DNSrec)
					$objPTR.CreateInstanceFromPropertyData($DNSserver, $RevPTR.Zone, $RevPTR.Host, $class, $ttl, $($DNSrec.Name + "." + $DNSZone))
					If ($IPv6){
						$objPTR.CreateInstanceFromPropertyData($DNSserver, $RevPTR.Zonev6, $RevPTR.Hostv6, $class, $ttl, $($DNSrec.Name + "." + $DNSZone))
						}
					}
				}
			"CNAME" {
				$objCNAME.CreateInstanceFromPropertyData($DNSserver, $DNSzone, $($DNSrec.Name + "." + $DNSZone), $class, $ttl, $($DNSrec.Alias + "." + $DNSZone))
				}
			"MX"{
				If (-not $DNSrec.Name){$DNSName = $DNSZone}
				else{$DNSName = $($DNSrec.Name + "." + $DNSZone)}
				$objMX.CreateInstanceFromPropertyData($DNSserver, $DNSzone, $DNSName, $class, $ttl, $DNSrec.Priority,$($DNSrec.Alias + "." + $DNSZone) )
				}
			}#switch
		}#try
	Catch {
		Write-error "$($error[0])"
		Continue
		}
	}#foreach
}#function

Function NewDNSzone ($iDNSzone){
$DNS = [wmiclass]"\\$DnsServer\Root\MicrosoftDNS:MicrosoftDNS_Zone"
$DNS.CreateZone($iDNSzone,0,$false,"","","")
}
}#begin

end{}