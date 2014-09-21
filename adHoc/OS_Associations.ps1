[CmdletBinding(DefaultParameterSetName='Find', SupportsTransactions=$false)]
param(
[Parameter(ParameterSetName='Find', ValueFromPipeline=$true, Mandatory=$false, Position=0)]
[system.string[]]${Find},
[Parameter(ParameterSetName='Set', ValueFromPipeline=$false, Mandatory=$true, Position=0)]
[System.Management.Automation.SwitchParameter]${Set},
[Parameter(ParameterSetName='Set', ValueFromPipeline=$false, Mandatory=$true, Position=1)]
[ValidatePattern('^\.([a-z0-9]){1,}$')]
[system.string]${Extension},
[Parameter(ParameterSetName='Set', ValueFromPipeline=$false, Mandatory=$true, Position=2)]
[system.string]${Program}
)

process    {
If ($host.version -ge "2.0"){
	# Check if we've got the value from the pipeline
	$script:direct = $PSBoundParameters.ContainsKey('Find')
	switch ($PsCmdlet.ParameterSetName){
		Find {FindAssoc $Find}
		Set {SetAssoc $Extension}
		}
	}
else{exit}
} # end of process

begin{
$script:direct = ""
function FindAssoc ($Find){
$resultsar = @()
foreach ($item in $Find){
	$foundassoc = $foundprog = $assoc = $null
	$Association = "Unknown"
	$Program = ""
	Write-Verbose -Message "Dealing with $item" -Verbose:$true
	try{$foundassoc = Get-ItemProperty -LiteralPath ("HKLM:\Software\Classes\"  + $item) -ErrorAction Stop}
	catch{if ($script:direct) { Write-Host -ForegroundColor Red -Object "File association not found for extension for $item"}}
	if ($foundassoc -ne $null){
		$Association = "NoOpen"
		if ($foundassoc.Count -ne 0){
			$assoc = $foundassoc.'(default)'
			if ($assoc -ne $null){
				$Association = $assoc
				$Program = "NoOpen"
				try{$foundprog = @(Get-ItemProperty -LiteralPath ("HKLM:\Software\Classes\"  + $assoc + "\shell\open\command") -ErrorAction Stop)}
				catch{if($script:direct){ Write-Host -ForegroundColor Red -Object "File type `'$assoc`' not found or no open command associated with it."}}
				if ($foundprog -ne $null){$Program = $foundprog.'(default)'}
				}
			}
		}
	$resultsar +=  New-Object -TypeName PSObject -Property @{
		Extension = $item
		Association = $Association
		Program = $Program
		}
	}#end foreach
return $resultsar
}#end function

function SetAssoc ($Extension){
# Define some common parameters
$extraparams = @{}
$extraparams += @{Force = $true ; Verbose  = $false ; ErrorAction = 'Stop'}
$key = "HKLM:\Software\Classes\" + $Extension
$assocfile = ($Extension -replace "\.","") + "file"
if (-not(Test-Path -Path $key)){
	try{New-Item -Path $key @extraparams | Out-Null}
	catch{
		switch ($_){
			{$_.CategoryInfo.Reason -eq 'UnauthorizedAccessException' } { $reason = "access is denied" }
			default { $reason  = $_.Exception.Message }
			}
		Write-Host -ForegroundColor Red -Object "Failed to create key $key because $reason.`nNote that admin rights are required for this operation."
		}
	}
if (Test-Path -Path $key){
	try{Set-ItemProperty -Path $key -Name '(default)' -Value $assocfile @extraparams}
	catch{
		switch ($_){
			{$_.CategoryInfo.Reason -eq 'UnauthorizedAccessException' } { $reason = "access is denied" }
			default { $reason  = $_.Exception.Message }
			}
		Write-Host -ForegroundColor Red -Object "Failed to set association $Extension because $reason"
		}
	# If previous operation where we set the value succeeded, continue as we are sure that we have admin rights
	if (-not($?)){
		$programkey = "HKLM:\Software\Classes\" + $assocfile + "\shell\open\command"
		if (-not(Test-Path -Path $programkey)){New-Item -Path $programkey @extraparams | Out-Null}
		if (Test-Path -Path $programkey){Set-ItemProperty -Path $programkey -Name '(default)' -Value $program @extraparams}
		}
	}
}#end function

}#end begin

end {}