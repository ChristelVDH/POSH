[CmdletBinding()]
param (
    [Parameter(ValueFromPipelineByPropertyName = $true)]$MacAddress
)

process {
    if ([string]::IsNullOrEmpty($MacAddress)) {
        Write-Verbose -Message "parsed MAC address string is empty"
        return $false 
    }
    Write-Verbose -Message "Incoming MAC address to parse is $($MacAddress)"
    if (-not $MacAddressFormat.IsMatch($MacAddress)) {
        Write-Verbose -Message "The MAC address format is incorrect, must be 6 hexadecimal values optionally separated by : or -"
        return $false
    }
    $FirstOctet = [system.convert]::ToString("0x$(($MacAddress.Substring(0,2)))", 2).PadLeft(2,'0')
    [bool]$result = $FirstOctet.EndsWith('00')
    Write-Verbose -Message "First octet of MAC address in binary format is $($FirstOctet) and last 2 bits must be zeroes to be valid --> $($result)"
    return $result
}#process

begin {
    [regex]$MacAddressFormat = "^([0-9A-Fa-f]{2}([:-])?){5,6}$"
}

end {

}