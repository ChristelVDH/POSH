param(
[switch]$FirstFree,
[switch]$LastFree,
[switch]$AllFree
)

begin{
$nl = [Environment]::NewLine
Function GetFreeDriveLetters{[char[]](68..90)|?{!(gdr $_ -ea 0)}}
Function GetFirstFreeDriveLetter{for($j=67;gdr($d=[char]++$j)2>0){}$d}
Function GetFirstFreeDriveLetter2{[char](1+”$(gdr ?)”[-1])}
Function GetLastFreeDriveLetter{for($j=91;gdr($d=[char]--$j)2>0){}$d}
}

process{
if ($FirstFree){
	write-host "The first free drive letter is:"
	GetFirstFreeDriveLetter
	}
if ($LastFree){
	write-host "The last free drive letter is:"
	GetLastFreeDriveLetter
	}
if ($AllFree){
	write-host "All free drive letters:"
	GetFreeDriveLetters
	}
}