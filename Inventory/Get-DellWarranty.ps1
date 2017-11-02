[CmdletBinding()]
param(
[Parameter(Mandatory=$false)][string[]]$ServiceTag,
[Parameter(Mandatory=$false)]
[ValidateSet("xml","json")][string]$ResponseFormat = "json",
[Parameter(Mandatory=$false)]
[ValidateSet("Getassetheader","Getassetwarranty")][string]$RequestType = "Getassetwarranty"
)

process{
$i=0
#parse no more than allowed number of tags per request using chunk variable
#divide array of tags into chunks using i as lower and chunk minus 1 as upper index
#then increase i with chunk value for next iteration as long as i is less than number of tags in array
if ($Chunk -gt $ServiceTag.count){ $Chunk = $ServiceTag.count }
for ($i;$i -lt $ServiceTag.count;$i+=$Chunk){
	$upper = $i+$Chunk-1
	write-progress -id 1 -activity "Dell Asset query: $($RequestType)" -Status "looking up Servicetag $($i+1) thru $($upper+1)" -PercentComplete (($i/$ServiceTag.Count)*100)
	$script:Assets += Get-DellWarranty -ServiceTag $($ServiceTag[$i..$upper] -join $Delimiter) $ResponseFormat
	}
}#process

begin{
$script:Assets = @()
$nl = [Environment]::NewLine
$APIKey = "abcdefghijklmnopqrstuvwxyz123457890"
#$EndPoint = "https://sandbox.api.dell.com/support/assetinfo/v4/$($RequestType)/"
$EndPoint = "https://api.dell.com/support/assetinfo/v4/$($RequestType)/"
$Delimiter = ","
$Chunk = 80

Function Get-DellWarranty ($ServiceTag,$ResponseFormat){
$body = @{ID=$ServiceTag}
$headers = @{}
$headers.Add("APIKey",$APIKey)
# $headers.Add("Accept","Application/$($ResponseFormat)")
switch ($ResponseFormat){
	'xml'{
		[xml]$response = Invoke-RestMethod -Uri $EndPoint -Body $body -Headers $headers -Method POST
		}
	'json'{
		$response = Invoke-RestMethod -Uri $EndPoint -Body $body -Headers $headers -Method POST
		}
	} #switch
# write-verbose "returned data = $($nl)$($response)"
switch ($RequestType){
	"Getassetheader"{ return $response.AssetHeaderResponse.AssetHeaderData }
	"Getassetwarranty"{
		$WarrResults = $response.AssetWarrantyResponse
		$Warr = @()
		write-verbose "$($WarrResults.count) results returned"
		$j = 0
		foreach ($WarrResult In $WarrResults){
			$Asset = $WarrResult.AssetHeaderData
			$Entitlements = $WarrResult.AssetEntitlementData
			$ProductHdr = $WarrResult.ProductHeaderData
			write-progress -ID 2 -ParentID 1 -activity "Parsing returned $($RequestType) results" -Status "$(($Entitlements).count) warranties found for $($Asset.ServiceTag)" -PercentComplete (($j++/$WarrResults.Count)*100)
			#sleep 2
			$WarrantyOverview = @()
			foreach ($Entitlement In $Entitlements){
				$WarrantyOverview += "$($Entitlement.ServiceLevelDescription) ($($Entitlement.ServiceLevelCode)) from $($Entitlement.StartDate -as [datetime]) until $($Entitlement.EndDate -as [datetime])"
				}
			$Warr += New-Object PSObject -Property @{
				Tag = $Asset.ServiceTag
				SystemShipDate = $Asset.ShipDate -as [DateTime]
				SystemDescription = $Asset.MachineDescription
				ServiceLevels = $($WarrantyOverview -join ", ")
				StartDate = $($Entitlements.StartDate | sort | select -first 1) -as [DateTime]
				EndDate = $($Entitlements.EndDate | sort -Descending | select -first 1) -as [DateTime]
				}
			Write-Verbose "found warranty details for $($Asset.ServiceTag):$($nl)$($Warr)"
			}
		return $Warr
		}
	}
}

}

end{
$script:Assets
}
