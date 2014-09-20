<#
.Synopsis
   Copies and/or cleans DNS records from one forward zone to another
.DESCRIPTION
   This script can both copy and clean DNS records by comparing any 2 DNS zones, either same or different FQDN
.EXAMPLE
   .\DNS_Functions SourceServer SourceZone DestinationServer DestinationZone Switches
   Generic example
.EXAMPLE
    .\DNS_Functions $SourceServer $SourceZone $DestinationServer $DestinationZone
    Forward zone comparison report only
.EXAMPLE
	.\DNS_Functions.ps1 source_dnsserver source_zone.local destination_dnsserver destination_zone.com -RRtypes `"MicrosoftDNS_AType`",`"MicrosoftDNS_CNAMEType`" -Clean
    Forward source zone clean up for CNAME records
.INPUTS
   every parameter must be parsed manually
.OUTPUTS
   All relevant information is sent to write-output thus must be pipelined into...
.NOTES
   General notes
.COMPONENT
   The component this cmdlet belongs to
.ROLE
   Chriske.Management.Network
.FUNCTIONALITY
   Cleaning records by resolving hosts (not by TTL or timestamp),
   Dedup of records that exist in both source and destination DNS zone,
   Copying records from source to destination, optionally after cleaning the source zone
#>

Param (
[Parameter(Mandatory=$true, Position=1)][string] $SourceServer,
[Parameter(Mandatory=$true, Position=2)][string] $SourceZone,
[Parameter(Mandatory=$true, Position=3)][string] $DestinationServer,
[Parameter(Mandatory=$true, Position=4)][string] $DestinationZone,
[ValidateSet("MicrosoftDNS_AType", "MicrosoftDNS_CNAMEType", "MicrosoftDNS_MXType")]
[string[]] $RRtypes = @("MicrosoftDNS_AType","MicrosoftDNS_CNAMEType"),
[switch] $Dedup,
[switch] $Copy,
[switch] $Clean
)

process{
# actual script execution

write-output "$('Comparison between') $($SourceServer) $('and') $($DestinationServer) $('for all regular DNS zones')$($nl)"
if ($SourceServer -ne $DestinationServer){
	# arrays of DNS zones to compare
	$srcZones = GetDNSzones $SourceServer
	$destZones = GetDNSzones $DestinationServer
	# output of DNS zones found on both servers
	CompareDNSservers $srcZones $destZones
	}
else{write-output "$('Source and Destination server are the same')$($nl)"}

# run thru loop for all DNS record types in script parameter
foreach ($RRtype in $RRtypes){
	if (-not (GetRecordType $RRtype)){write-warning "$RRtype is not a valid DNS resource type";continue}
	write-output "$('Comparison between') $($SourceZone) $('on') $($SourceServer) $('and') $($DestinationZone) $('on') $($DestinationServer) $('for') $(GetRecordType $RRtype) $('records')$($nl)"
	# arrays of DNS records to compare
	$sourceRecords = (GetDNSrecords $SourceServer $SourceZone $RRtype)
	$destinRecords = (GetDNSrecords $DestinationServer $DestinationZone $RRtype)
	# check for empty array(s)
	if ($sourceRecords -and $destinRecords){
		# output of DNS records found in both zones
		CompareDNSzones $sourceRecords $destinRecords
		# clean duplicate records on the source server
		if($Dedup){DedupDNSzone $sourceRecords $destinRecords}
		# copy unique records from source to destination server
		CopyDNSzone $sourceRecords $destinRecords
		# clean dead records in source zone
		CleanDNSzone $sourceRecords $destinRecords
		}
	else{write-output "$('no') $(GetRecordType $RRtype) $('records in either DNS zone')$($nl)"}
}
}#process

begin{
# script variables
$nl = [Environment]::NewLine

function GetDNSrecords($DNSserver, $DNSzone, $RRtype){
	if ($RRtype -eq $null){$RRtype = "MicrosoftDNS_AType"}
	$DNSrecords = Get-WMIObject -Computer $DNSserver -Namespace "root\MicrosoftDNS" -Class $RRtype -Filter "ContainerName='$DNSzone'"
	if ($DNSrecords){
		Switch ($RRtype){
			MicrosoftDNS_AType {
				foreach ($rec in $DNSrecords){
					# add simple name of dns record as extra property for comparison routine
					Add-Member -InputObject $rec -MemberType NoteProperty -Name SimpleVal -Value $rec.OwnerName.Replace(".$DNSzone","")
					}
				}
			MicrosoftDNS_CNAMEType {
				foreach ($rec in $DNSrecords){
					# add simple name of dns record as extra property for comparison routine
					Add-Member -InputObject $rec -MemberType NoteProperty -Name SimpleVal -Value $rec.OwnerName.Replace(".$DNSzone","")
					}
				}
			MicrosoftDNS_MXType{
				foreach ($rec in $DNSrecords){
					# add simple name of dns record as extra property for comparison routine
					Add-Member -InputObject $rec -MemberType NoteProperty -Name SimpleVal -Value $rec.OwnerName.Replace(".$DNSzone","")
					}
				}
			MicrosoftDNS_ResourceRecord {
				# to be implemented
				}
			}
		}
	return $DNSrecords
}

function GetDNSrecord ($DNSserver, $DNSzone, $name, $RRtype){
	$DnSrecord = Get-WMIObject -Computer $DNSserver -Namespace "root\MicrosoftDNS" -Class $RRtype -Filter "OwnerName='$name.$DNSzone'"
	return $DNSrecord # returns the actual object for further processing
}

function GetDNSzones($DNSserver){
	# server side filtering
	$DNSzones = Get-WmiObject -ComputerName $DNSserver -Class MicrosoftDNS_Zone -Namespace root\microsoftDNS -Filter "ZoneType = 1 or ZoneType = 2"
	# client side filtering
	#$DNSzones = Get-WmiObject -ComputerName $destServer -Class MicrosoftDNS_Zone -Namespace root\microsoftDNS | Where {$_.ZoneType -eq '1' -or  $_.ZoneType -eq '2'}
	return $DNSzones
}

function GetDNSzone ($DNSserver, $name){
	$DnSzone = Get-WMIObject -Computer $DNSserver -Namespace "root\MicrosoftDNS" -Class MicrosoftDNS_Zone -Filter "Name='$name'"
	return $DnSzone # returns the actual object for further processing
}

# just for debugging and reference
function DNSrecordInfo($DNSrecord){
	$objOutput = New-Object PSObject -Property @{
		$class			= $DNSrecord.__CLASS			# A, CNAME, PTR, etc.
		$ownerName		= $DNSrecord.OwnerName			# Name column in DNS GUI, FQDN
		$containerName	= $DNSrecord.ContainerName		# Zone FQDN
		$domainName		= $DNSrecord.DomainName			# Zone FQDN
		$ttl			= $DNSrecord.TTL				# TTL
		$recordClass	= $DNSrecord.RecordClass		# Usually 1 (IN)
		$recordData		= $DNSrecord.RecordData			# Data column in DNS GUI, value
		$simpleval		= $ownerName.Replace(".$domainName","")
		}
	return $objOutput
}

function CopyRecords($DNSrecords){
	Write-Output "$($nl)$('Copying') $($DNSrecords.count) $('records to') $($DestinationServer)$($nl)"
	$Succ = $Fail = 0
	foreach ($DnSrecord in $DNSrecords){
		$strmsg = ""
		Switch ($DNSrecord.__CLASS) {
			MicrosoftDNS_AType {
				$destRec = [WmiClass]"\\$DestinationServer\root\MicrosoftDNS:MicrosoftDNS_AType"
				$newRec = $DNSrecord.SimpleVal + "." + $DestinationZone
				$strmsg = "copy of A: $newRec on $DestinationServer"
				if ($Copy){
					if ($DnSrecord.SimpleVal -eq $SourceZone){
						$strmsg += " skipped `(same as parent`)"
						break
						}
					try{
						$destRec.CreateInstanceFromPropertyData($DestinationServer, $DestinationZone, $newRec, 1, $DNSrecord.TTL, $DNSrecord.RecordData) | out-null
						$strmsg += " succeeded"
						$Succ ++
						}
					catch{
						$strmsg += " failed"
						$strmsg += "$($nl)$($error[0])"
						$Fail ++
						}
					}
				else{
					$strmsg += " -whatif"
					}
				}
			MicrosoftDNS_CNAMEType {
				$destRec = [WmiClass]"\\$DestinationServer\root\MicrosoftDNS:MicrosoftDNS_CNAMEType"
				$newRec = $DNSrecord.SimpleVal + "." + $DestinationZone
				$strmsg = "copy of CNAME: $newRec on $DestinationServer"
				if ($Copy){
					try{
						$cRec = $DNSrecord.RecordData.Replace(".$SourceZone",".$DestinationZone")
						$destRec.CreateInstanceFromPropertyData($DestinationServer, $DestinationZone, $newRec, 1, $DNSrecord.TTL, $cRec ) | out-null
						$strmsg += " succeeded"
						$Succ ++
						}
					catch{
						$strmsg += " failed:"
						$strmsg += "$($nl)$($error[0])"
						$Fail ++
						}
					}
				else{
					$strmsg += " -whatif"
					}
				}
			MicrosoftDNS_MXType {
				$destRec = [WmiClass]"\\$DestinationServer\root\MicrosoftDNS:MicrosoftDNS_MXType"
				$newRec = $DNSrecord.SimpleVal + "." + $DestinationZone
	            $pref = $DNSrecord.Preference
				$mx = $DNSrecord.MailExchange
				$strmsg = "copy of MX: $newRec for $mx with preference $pref on $DestinationServer"
				if ($Copy){
					try{
						$destRec.CreateInstanceFromPropertyData($DestinationServer, $DestinationZone, $newRec, 1, $DNSrecord.TTL, $pref, $mx)
						}
					catch{
						$strmsg += " failed:"
						$strmsg += "$($nl)$($error[0])"
						$Fail ++
						}
					}
				else{
					$strmsg += " -whatif"
					}
				}
			default{
				$strmsg = "copy of DNS record skipped due to unknown class"
				$Fail ++
				}
			}
		Write-Output $strmsg
		}
	Write-Output "$($nl)$($Succ) $('records copied')"
	Write-Output "$($Fail) $('records failed')$($nl)"
}

function ScavengeRecords($DNSrecords){
	$Deleted = $Dead = $Live = 0
	foreach ($DnSrecord in $DNSrecords){
		$strmsg = "$($DNSrecord.SimpleVal)"
		if (Test-Connection -ComputerName  $DNSrecord.OwnerName -count 1 -ea silentlycontinue) {
			$strmsg +=  " is still alive"
			$Live ++
			}
		else{
			$strmsg += " cannot be reached"
			$Dead ++
			if ($Clean){
				try{
					$DNSrecord.delete()
					$strmsg += " and deletion succeeded"
					$Deleted ++
					}
				catch{
					$strmsg += " but deletion failed"
					}
				}
			}
		Write-Output $strmsg
		}
	Write-Output "$($nl)$($Live) $('records were live')"
	Write-Output "$($Dead) $('records were dead')"
	Write-Output "$($Deleted) $('records scavenged on a total of') $($Dnsrecords.count)$($nl)"
}

function DedupDNSzone ($srcRecords, $dstRecords){
	$Succ = $Fail = 0
	# return only records from reference (= source zone) found in both DNS zones
	$Records2Dedup = compare-object $srcRecords $dstRecords -IncludeEqual -ExcludeDifferent -Property SimpleVal -PassThru
	$strmsg = "$nl Deleting duplicate records from $SourceZone"
	$Records2Dedup | %{
		try{
			$_.delete()
			$Succ ++
			}
		catch{
			$Fail ++
			}
		}
	$strmsg += " has succeeded for $Succ and failed for $Fail records"
	Write-Output $strmsg
}

function CleanDNSzone($srcRecords, $dstRecords){
	# return unique records in source zone only
	$Records2Clean = compare-object $srcRecords $dstRecords -Property SimpleVal -PassThru | Where-Object { $_.SideIndicator -eq '<=' }
	ScavengeRecords $Records2Clean
}

function CopyDNSzone ($srcRecords, $dstRecords){
	# return unique records in source zone only
	$Records2Copy = compare-object $srcRecords $dstRecords -Property SimpleVal -PassThru | Where-Object { $_.SideIndicator -eq '<=' }
	CopyRecords $Records2Copy
}

function DeleteZone ($Domain, $DNSserver,$RRTypes = @("A", "NS", "CNAME", "AAAA")){
$RRTypes | %{
	Get-WMIObject -ComputerName $DNSservers -Namespace root\microsoftdns -Class "MicrosoftDNS_$($_)Type" -Filter "ContainerName='..RootHints'" | ?{ $_.DomainName -like "*$Domain" } | %{ $_.Delete() }
	}
}

function CompareDNSservers($srcDNSzone ,$destDNSzone){
	$dest = $src = $equ = 0
	$zones = compare-object $srcDNSzone $destDNSzone -Property name -IncludeEqual
	if ($zones -ne $null){
		foreach ($zone in $zones){
			$strmsg = "$zone.Name exists on: "
			switch ($zone.SideIndicator){
				'=>' {
					$strmsg += "$DestinationServer `(destination server`)"
					$dest ++
					}
				'<=' {
					$strmsg += "$SourceServer `(source server`)"
					$src ++
					}
				'==' {
					$strmsg += "both source and destination server"
					$equ ++
					}
				}
				Write-Output $strmsg
			}
		write-output "$($nl)$($dest) $('zones on') $($DestinationServer) $('only')"
		write-output "$($src) $('zones on') $($SourceServer) $('only')"
		write-output "$($equ) $('zones on both source and destination')$($nl)" 
		}
}

function CompareDNSzones($srcRecords, $dstRecords){
	$dest = $src = $equ = 0
	$records = compare-object $srcRecords $dstRecords -IncludeEqual -Property SimpleVal
	if ($records -ne $null){
		foreach ($record in $records){
			$strmsg = "$($record.SimpleVal) exists in: "
			switch ($record.SideIndicator){
				'=>' {
					$strmsg += "$DestinationZone `(destination zone`)"
					$dest ++
					}
				'<=' {
					$strmsg += "$SourceZone `(source zone`)"
					$src ++
					}
				'==' {
					$strmsg += "both zones"
					$equ ++
					}
				}
			Write-Output $strmsg
			}
		write-output "$($nl)$($dest) $('records in') $($DestinationZone) $('on') $($DestinationServer) $('only')"
		write-output "$($src) $('records in') $($SourceZone) $('on') $($SourceServer) $('only')"
		write-output "$($equ) $('records in both source and destination')$($nl)" 
		}
}

function GetRecordType($Class){
# return human readable record type :-)
	Switch ($Class) {
		MicrosoftDNS_AAAAType 	{return "AAAA"}
		MicrosoftDNS_AFSDBType 	{return "AFSDB"}
		MicrosoftDNS_ATMAType 	{return "ATMA"}
		MicrosoftDNS_AType 		{return "A"}
		MicrosoftDNS_CNAMEType 	{return "Cname"}
		MicrosoftDNS_HINFOType 	{return "H Info"}
		MicrosoftDNS_ISDNType 	{return "ISDN"}
		MicrosoftDNS_KEYType 	{return "Key"}
		MicrosoftDNS_MBType 	{return "MB"}
		MicrosoftDNS_MDType		{return "MD"}
		MicrosoftDNS_MFType 	{return "MF"}
		MicrosoftDNS_MGType 	{return "MG"}
		MicrosoftDNS_MINFOType 	{return "M Info"}
		MicrosoftDNS_MRType 	{return "MR"}
		MicrosoftDNS_MXType 	{return "MX"}
		MicrosoftDNS_NSType 	{return "NS"}
		MicrosoftDNS_NXTType	{return "NXT"}
		MicrosoftDNS_PTRType	{return "PTR"}
		MicrosoftDNS_RPType 	{return "RP"}
		MicrosoftDNS_RTType 	{return "RT"}
		MicrosoftDNS_SIGType	{return "SIG"}
		MicrosoftDNS_SOAType	{return "SOA"}
		MicrosoftDNS_SRVType	{return "SRV"}
		MicrosoftDNS_TXTType	{return "Text"}
		MicrosoftDNS_WINSRType	{return "Wins R"}
		MicrosoftDNS_WINSType 	{return "Wins"}
		MicrosoftDNS_WKSType 	{return "WKS"}
		MicrosoftDNS_X25Type 	{return "X25"}
		}
}
}#begin

end{
write-output "$('end script')$($nl)"
}