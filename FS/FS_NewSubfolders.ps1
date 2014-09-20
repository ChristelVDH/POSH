#coded for generating user home folders but can be used for whatever
param(
[string] $RootFolder = "E:\tmp",
[String[]] $SubFolders2Make = @("Documents","Desktop","Favorites"),
[string[]] $ParentFolders,
[switch] $MakeParentFolders
)

If ($MakeParentFolders -and $Parentfolders){
	ForEach($Folder2Make in $ParentFolders){
		try{New-Item -ItemType Directory -Path "$RootFolder\$Folder2Make" -ea stop}
		catch{"$RootFolder\$Folder2Make already exists" }
		}
	}
$Folders = gci $RootFolder | Where-Object{($_.PSIsContainer)} | foreach-object{$_.FullName}
# In each folder create the subfolder
ForEach($Folder in $Folders){
	ForEach ($SubFolder2Make in $SubFolders2Make){
		try{New-Item -ItemType Directory -Path "$Folder\$SubFolder2Make" -ea stop}
		catch{"$Folder\$SubFolder2Make already exists"}
		}
	}
#alternative oneliner:
# ls 'd:\bak' | ? {($_.PSIsContainer)} | % {$_.fullName} | % { new-item -path "$_\newfolder" -type directory}
