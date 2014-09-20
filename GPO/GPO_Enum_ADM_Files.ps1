param(
$filter = "*.adm",
$OutFolder = [Environment]::getfolderpath("mydocuments"),
[switch]$Output
)

begin{
$script:GPOs = @()
#get current domain + policies folder thru system environment calls
$domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name
$GPOfolder = "\\$domain\SYSVOL\$domain\Policies"
$OutFile = Join-Path $OutFolder "legacy_adm_files.csv"
}
process{
$ADMfiles = (Get-ChildItem -Path $GPOfolder -Filter $filter -Recurse)
foreach ($ADMfile in $ADMfiles){
	$script:GPOs += New-Object PSObject -Property @{
		Folder = $ADMfile.Directory
		File = $ADMfile.Name
		Extension = $ADMfile.Extension
		CreateDate = $ADMfile.CreationTime
		LastWriteDate = $ADMfile.LastWriteTime
		AccessDate = $ADMfile.LastAccessTime
		Length = $ADMfile.Length
		}
	}
}

end{
if ($Output){$script:GPOs | sort File | Export-CSV $OutFile -NoTypeInformation -UseCulture}
else {$script:GPOs | sort File}
}