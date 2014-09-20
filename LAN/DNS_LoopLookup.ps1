param(
[string[]]$dnsservers = ("dc01","dc02","dc03","dc04"),
[string[]]$dnsqueries = ("www.vmware.com", "www.redhat.com", "www.pubmed.com"),
[int] $Attempts = 100,
[int] $Wait = 1
)
$RRtype = "MicrosoftDNS_ResourceRecord"

function getdns($dnssrv, $dnsq){
# $dnshost = $($dnsq.split(".")[0]) + "."
# $dnsdomain = $dnsq.replace("$dnshost","")
# write-host -ForegroundColor Green "querying $dnssrv for $dnshost in $dnsdomain"
write-host -ForegroundColor Green $dnsq
[System.Net.Dns]::GetHostEntry("$dnsq").AddressList | %{ $_.IPAddressToString  } 
}

clear-host
foreach ($element in(1..$Attempts)){start-sleep -s $Wait; foreach ($dnsserver in $dnsservers){foreach ($dnsquery in $dnsqueries) {getdns $dnsserver $dnsquery | ft -autosize server, answer}}}

