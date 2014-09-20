param(
[string[]]$AppsList = @("Microsoft.WindowsAlarms","Microsoft.Reader","Microsoft.WindowsCalculator","Microsoft.WindowsReadingList","Microsoft.WindowsScan","Microsoft.WindowsSoundRecorder","Microsoft.SkypeApp","Microsoft.HelpAndTips","Microsoft.BingFinance","Microsoft.BingFoodAndDrink","Microsoft.BingHealthAndFitness","Microsoft.BingNews","Microsoft.BingSports","Microsoft.BingTravel","BrowserChoice")
)

begin{}

process{
ForEach ($App in $AppsList){
	$Packages = Get-AppxPackage | Where-Object {$_.Name -eq $App}
	if ($Packages -ne $null){
		foreach ($Package in $Packages){
			Remove-AppxPackage -package $Package.PackageFullName
		}
	}
	$ProvisionedPackage = Get-AppxProvisionedPackage -online | Where-Object {$_.displayName -eq $App}
	if ($ProvisionedPackage -ne $null){
		remove-AppxProvisionedPackage -online -packagename $ProvisionedPackage.PackageName
	}
}
}# end process

end{}