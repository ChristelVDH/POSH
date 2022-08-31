[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "")]

param(
	[switch]$ChangeBiosSettings,
	[string]$BiosPassword
)

[System.Collections.Hashtable]$script:outBios = @{}
$ComputerName = $env:COMPUTERNAME
$BiosSettings = @(((Get-WmiObject -ClassName Lenovo_BiosSetting -NameSpace root\wmi) | Select-Object CurrentSetting).CurrentSetting | ConvertFrom-Csv -Delimiter "," -Header Name, Value)
$BiosSettings | ForEach-Object { $script:outBios[$_.Name] = $_.Value }

if ($ChangeBiosSettings.IsPresent) {
	if ($BiosPassword) { $BiosPasswordParam = ",$($BiosPassword),ascii,us" } else { $BiosPasswordParam = "" }
	$BiosChanges = $script:outBios | Out-GridView -Title "Select BIOS setting to change" -PassThru
	$BiosChanges | ForEach-Object {
		$Selections = ((Get-WmiObject -ClassName Lenovo_GetBiosSelections -NameSpace root\wmi).GetBiosSelections($_.Name)).Selections
		$BiosValue = $Selections.split(',') | Out-GridView -Title "Select new value for $($_.Name) currently set to $($_.Value)" -OutputMode Single
		$BiosParameter = "$($_.Name),$($BiosValue)" -join $BiosPasswordParam
		try {
			(Get-WmiObject -ClassName Lenovo_SetBiosSetting -NameSpace root\wmi).SetBiosSetting($BiosParameter)
			(Get-WmiObject -class Lenovo_SaveBiosSettings -namespace root\wmi).SaveBiosSettings($BiosPasswordParam)
			Write-Verbose -Message "Successfully changed value of $($_.Name) from $($_.Value) to $($BiosValue)"
			$script:outBios[$_.name] = $BiosValue
		}
		catch { Write-Error -Message "FAILED to change value of $($_.Name) from $($_.Value) to $($BiosValue)"}
	}#ForEach-Object
}
Write-Verbose -Message "Retrieved/changed BIOS values for $($ComputerName):"
$script:outBios | Select-Object Name, Value
