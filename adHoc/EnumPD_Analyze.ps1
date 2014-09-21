[CmdletBinding()]
param(
$EnumPDFolder = "\\logserver\Enum",
[switch]$Grid
)

process{
write-verbose "getting logfiles in $EnumPDFolder"
$Logfiles = (gci $EnumPDFolder\* -Include "Enum*.log" | out-gridview -title "select 1 or multiple logfiles" -passthru)
foreach ($LogFile in $Logfiles){
	$script:cntr = 1
	#assuming date of first logentry equal to creation of logfile
	$script:RunningDate = (get-date $LogFile.CreationTime)
	Write-Progress -Activity "Getting Enum log" -status "Starting..." -id 1
	write-verbose "reading $logfile"
	ProcessLog $LogFile
	$script:cntr++
	}#foreach
}#process

begin{
#array of outputted objects
$script:EnumData = @()
#holds date of last log item beginning with logfile creation date
[datetime]$script:RunningDate = get-date
#hash table for converting abbreviated month name into month number
#add more if needed, month name must be unique, values can be duplicate
$AbbrevMonths = @{jan=1;feb=2;mar=3;mrt=3;apr=4;mei=5;may=5;jun=6;jul=7;aug=8;sep=9;okt=10;oct=10;nov=11;dec=12}
$nl = [Environment]::NewLine

function EvalLogItemDate ($EnumDateVal){
[regex]$regex = "[- /.]"
$split = $regex.split($EnumDateVal)
#casting splitted string into numbers if possible
try{$iFirst = [int]::Parse($split[0])}
catch{$iFirst = $script:RunningDate.Day}
try{$iSecond = [int]::Parse($split[1])}
catch{$iSecond = $AbbrevMonths[$split[1]]}
try{$iThird = [int]::Parse($split[2])}
catch{$iThird = $script:RunningDate.Year}
write-verbose "parsed: $iFirst - $iSecond - $iThird from incoming string $EnumDateVal"
#check for Y2K formatted year ;-)
if (($script:RunningDate.Year.Equals($iThird)) -or ($script:RunningDate.AddYears(1).Year.Equals($iThird))){$Year = $iThird}
elseif (($script:RunningDate.Year.Equals($iThird + 2000)) -or ($script:RunningDate.AddYears(1).Year.Equals($iThird + 2000))){$Year = $iThird + 2000}
else{$Year = $script:RunningDate.Year}
#switch around day and month part for evaluating log item date
$format = "ddMMyyyy"
try {$tmpDate = $(get-date -Day $iFirst -Month $iSecond -Year $Year)}
catch{write-verbose "evaluated date $format is incorrect: $iFirst $iSecond $Year"}
if (($script:RunningDate.Date.Equals($tmpDate.Date)) -or ($script:RunningDate.AddDays(1).Date.Equals($tmpDate.Date))){
	$script:RunningDate = $tmpDate
	write-verbose "evaluated date $format is correct: $tmpDate"
	}
else{
	$format = "MMddyyyy"
	try{$tmpDate = $(get-date -Day $iSecond -Month $iFirst -Year $Year)}
	catch{write-verbose "evaluated date $format is incorrect: $iSecond $iFirst $Year"}
	if (($script:RunningDate.Date.Equals($tmpDate.Date)) -or ($script:RunningDate.AddDays(1).Date.Equals($tmpDate.Date))){
		$script:RunningDate = $tmpDate
		write-verbose "evaluated date $format is correct: $tmpDate"
		}
	}
#output object
$objDate = new-object PSobject -Property @{
	Date = ($script:RunningDate).ToShortDateString()
	InFormat = $format
	OutFormat = (Get-Culture).DateTimeFormat.ShortDatePattern
	}
return $objDate
}

function EvalLogItemTime ($EnumTimeVal){
$split = $EnumTimeVal -split "[\s : - /]"
$Hour = [int]::Parse($split[0])
$Minute = [int]::Parse($split[1])
# try{$Second = [int]::Parse($split[2])}
# catch{[int]$Second = 0}
switch ($split[3]){
	'AM'{if($Hour -eq 12){$Hour = 0}}
	'PM'{if(-not ($Hour -eq 12)){$Hour += 12}}
	default{write-verbose "no designator"}
	}#switch
if ($Hour -eq 24){$Hour = 0}
write-verbose "parsed: $Hour $Minute from incoming string $EnumTimeVal"
$evaltime = (get-date -Hour $Hour -Minute $Minute -Format "HH:mm")
return $evaltime
}

function ProcessLog ($LogFile){
#get number of lines for progress bar
$nrLines = ([io.file]::ReadAllLines($LogFile)).Count
Write-Progress -Activity "Getting Enum log details" -status "Starting..." -id 2 -ParentId 1
$item = 1
$EnumDate = $EnumTime = $EnumComp = $EnumUser = $EnumHome = ""
$EnumDrive = $EnumPrinter = @()
foreach ($Line in (gc $LogFile)){
	switch -regex ($Line){
		"^PrinterQ: C:\\WINDOWS\\TEMP\\.*" {break}
		#if line contains asterisks write custom object and emtpy saved variables for next loop
		"^\*" {
			$item++
			Write-Progress -Activity "Getting Enum log details" -status "Parsing $($LogFile.Name)" -CurrentOperation "processing item $item" -id 2 -ParentId 1 -percent $($script:cntr / $nrLines * 100)
			write-verbose "asterisks found, saving custom object"
			$script:EnumData += New-Object PSObject -Property @{
				Datum = $EnumDate
				Tijd = $EnumTime
				Host = $EnumComp
				User = $EnumUser
				MyDocs = $EnumHome
				DriveMap = ($EnumDrive -join "`n")
				PrinterQ = ($EnumPrinter -join "`n")
				}
			#empty saved variables for next loop
			$EnumDate = $EnumTime = $EnumComp = $EnumUser = $EnumHome = ""
			$EnumDrive = $EnumPrinter = @()
			break
			}
		"^Datum:" {$EnumDate = (EvalLogItemDate ($Line.TrimStart("Datum:")).Trim()).Date}
		"^Tijd:" {$EnumTime = (EvalLogItemTime ($Line.TrimStart("Tijd:")).Trim())}
		"^ComputerName:" {$EnumComp = $Line.TrimStart("ComputerName:").Trim()}
		"^UserName:" {$EnumUser = $Line.TrimStart("UserName:").Trim()}
		"^MyDocumentsPath:" {$EnumHome = $Line.TrimStart("MyDocumentsPath:").Trim()}
		"^DriveMap:" {$EnumDrive += ($Line.TrimStart("DriveMap:").Trim())}
		"^PrinterQ:" {$EnumPrinter += ($Line.TrimStart("PrinterQ:").Trim())}
		}#end switch
	}#end foreach
}

}#begin

end{
if ($Grid){$script:EnumData | Out-GridView -PassThru}
else{$script:EnumData}
}