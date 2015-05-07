param(
$StartTime  = (Get-Date).AddDays(-1),
$LogName = 'System',
$EventID =5807,
[switch]$SendMail
)

process{
$script:Events = Get-Winevent -Computername $env:computername -FilterHashTable @{LogName=$LogName;ID=$EventID;StartTime=$StartTime} 
}

begin{
$script:Events = @()
}

end{
if ($SendMail){
	Send-MailMessage -To "ICT@company.be" -Subject $script:Events[0].ProviderName -Body $($script:Events | Format-Table ID, Message -AutoSize) -SmtpServer smtpgate.company.be -From $($env:computername + "@company.be")
	}
else{
	$script:Events | Format-Table ID, Message -AutoSize
	}
}
