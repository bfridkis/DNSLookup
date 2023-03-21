#Clear any potentially uninitialized variable
$readFileOrManualEntry = $outputMode = $fileNotFound = $ipFilePath = $null

#Initialize lists for input, results (output), and errors.
$IPsForLookup = New-Object System.Collections.Generic.List[System.Object]
$results = New-Object System.Collections.Generic.List[System.Object]
$errors = New-Object System.Collections.Generic.List[System.Object]

write-output "`n"
write-output "`t`t`t`t`t   *!*!* IP Lookup *!*!*`n"

#Determine input mode.
do {
    $readFileOrManualEntry = read-host -prompt "Read Input From File (1) or Manual Entry (2) [Default = Read Input From File]"
    if (!$readFileOrManualEntry) { $readFileOrManualEntry = 1 }
} 
while ($readFileOrManualEntry -ne 1 -and $readFileOrManualEntry -ne 2 -and $readFileOrManualEntry -ne "Q")
if ($readFileOrManualEntry -eq "Q") { exit }

#Read ips in if input mode = 1 (i.e. input from file).
if ($readFileOrManualEntry -eq 1) {
    do {
        $ipFilePath = read-host -prompt "`nIP Address Input File [Default=.\IPAddressesForLookup.txt]" 
        if(!$ipFilePath) { $ipFilePath = ".\IPAddressesForLookup.txt" }
        if ($ipFilePath -ne "Q") { 
            $fileNotFound = $(!$(test-path $ipFilePath -PathType Leaf))
            if ($fileNotFound) { write-output "`n`tFile '$ipFilePath' Not Found or Path Specified is a Directory!`n" }
        }
        if($fileNotFound) {
            write-output "`n** Remember To Enter Fully Qualified Filenames If Files Are Not In Current Directory **" 
            write-output "`n`tFile must contain one ip address per line.`n"
        }
    }
    while ($fileNotFound -and $ipFilePath -ne "Q")
    if ($ipFilePath -eq "Q") { exit }

    $IPsForLookup = Get-Content $ipFilePath -ErrorAction Stop
}
#Prompt for ips if input mode = 2 (i.e. manual entry).
else {
    $IPCount = 0
    write-output "`n`nEnter 'f' once finished. Minimum 1 entry. (Enter 'q' to exit.)`n"
    do {
        $IPInput = read-host -prompt "IP Address ($($IPCount + 1))"
        if ($IPInput -ne "F" -and $IPInput -ne "B" -and $IPInput -ne "Q" -and 
            ![string]::IsNullOrEmpty($IPInput)) {
            if ($IPInput -eq 'localhost') { $IPInput = $ENV:Computername }
            $IPsForLookup.Add($IPInput)
            $IPCount++
            }
    }
    while (($IPInput -ne "F" -and $IPInput -ne "B" -and $IPInput -ne "Q") -or 
            ($IPCount -lt 1 -and $IPInput -ne "B" -and $IPInput -ne "Q"))

    if ($IPInput -eq "Q") { exit }
}

#Determine output mode.
do { 
    $outputMode = read-host -prompt "`nSave To File (1), Console Output (2), or Both (3) [Default=3]"
    if (!$outputMode) { $outputMode = 3 }
}
while ($outputMode -ne 1 -and $outputMode -ne 2 -and $outputMode -ne 3 -and $outputMode -ne "Q")
if ($outputMode -eq "Q") { exit }

#If file output selected, determine location/filename...
if ($outputMode -eq 1 -or $outputMode -eq 3) {
        write-output "`n* To save to any directory other than the current, enter fully qualified path name. *"
        write-output   "*              Leave this entry blank to use the default file name of               *"
        write-output   "*                        '$defaultOutFileName',                          *"
        write-output   "*                which will save to the current working directory.                  *"
        write-output   "*                                                                                   *"
        write-output   "*  THE '.csv' EXTENSION WILL BE APPENDED AUTOMATICALLY TO THE FILENAME SPECIFIED.   *`n"

    $defaultOutFileName = "IPLookupOutput-$(Get-Date -Format MMddyyyy_HHmmss)"

    do { 
        $outputFileName = read-host -prompt "Save As [Default=$defaultOutFileName]"
        if ($outputFileName -eq "Q") { exit }
        if(!$outputFileName) { $outputFileName = $defaultOutFileName }
        $pathIsValid = $true
        $overwriteConfirmed = "Y"
        $outputFileName += ".csv"
        #Test for valid file name and check if file already exists...                                
        $pathIsValid = Test-Path -Path $outputFileName -IsValid
        if ($pathIsValid) {          
            $fileAlreadyExists = Test-Path -Path $outputFileName
            if ($fileAlreadyExists) {
                do {
                    $overWriteConfirmed = read-host -prompt "File '$outputFileName' Already Exists. Overwrite (Y) or Cancel (N)"       
                    if ($overWriteConfirmed -eq "Q") { exit }
                } while ($overWriteConfirmed -ne "Y" -and $overWriteConfirmed -ne "N")
            }
        }

        else { 
            write-output "* Path is not valid. Try again. ('q' to quit.) *"
        }
    }
    while (!$pathIsValid -or $overWriteConfirmed -eq "N")
}

#Process lookup...
$IPsForLookup | ForEach-Object {
    $thisIP = $_
    Try { 
        $thisResult = $([system.net.dns]::GetHostByAddress($_))
        $results.Add([PSCustomObject]@{'IP Address'=$thisIP;
                                       'DNS Name'=($thisResult.Hostname).split(".")[0];
                                       'Aliases'= $(if(!$thisResult.Aliases) {"None"} else {[String]$thisResult.Aliases})})
    }
    Catch { $errors.Add([PSCustomObject]@{'IP Address'=$thisIP;
                                          'Error Message'=$_.Exception.Message})
    }
}

if ($outputMode -eq 1 -or $outputMode -eq 3) {
    $results | Export-CSV -Path $outputFileName -NoTypeInformation 
    if ($errors) {
        Add-Content -Path $outputFileName -Value "`r`n** Errors **"
        $errors | Select-Object | ConvertTo-CSV -NoTypeInformation | Add-Content -Path $outputFileName
    }
}
if ($outputMode -eq 2 -or $outputMode -eq 3) {
    write-Output "`n`t`t`t*** Results ***"
    $results | Format-Table
    if ($errors) {
        write-Output "`t`t`t*** Errors ***"
        $errors | Format-Table
    }
}

if($outputMode -eq 1) {
    write-host "`nTask Complete. Press enter to exit..." -NoNewLine
    $Host.UI.ReadLine()
}
else { 
    write-host "Task Complete. Press enter to exit..." -NoNewLine
    $Host.UI.ReadLine()
}

#References:
# https://stackoverflow.com/questions/44397795/dns-name-from-ip-address