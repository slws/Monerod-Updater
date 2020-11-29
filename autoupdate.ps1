<#
Written for PowerShell 5 (Windows 10)

The first four variables are all user configurable as per your requirements.
Remove the value of prune if you do not require pruning
Set fPath to be where you want the cli wallet to run from
Set lmdb to be the path of your blockchain storage (SSD with >100GB recommended)
Set subfolder to $fPath\some_other_name if you prefer
#>

$prune = "--prune-blockchain"
$fPath = "<Your_filepath>"
$lmdb = "--data-dir <Your_blockchain_path>"
$subfolder = "$fPath\monero-cli"
$monerod = (Get-Process -name monerod -EA SilentlyContinue).id
$hMatch = $false
$pgpSig = ""
$update = [string] (& $subfolder\monerod.exe update check)
If ($update -like "*No update available"){
    Write-Output "No updates required."
} ElseIf ($update -ne $null) {
    If ($monerod -ne $null){
        $updateInfo = $update -split '\s+'
        $url = $updateInfo[10].Substring(0,$updateInfo[10].Length-1)
        $hash = $updateInfo[12]
        $fileInfo = $url -split '/'
        $fileName = $fileInfo[4]
        Write-Output "Downloading $fileName from the web..."
        $progresspreference = 'silentlyContinue'
        Invoke-WebRequest $url -OutFile $fPath\$fileName
        $progressPreference = 'Continue'
        $certUtilOutput = (certUtil -hashfile $fPath\$fileName SHA256) -split '\s+'
        $fileHash = $certUtilOutput[4]
        If ($fileHash -eq $hash){
            Write-Output "Hash match confirmed. Killing monerod and Extracting download..."
            Stop-Process -id $monerod | Wait-Process
            Expand-Archive -LiteralPath $fPath\$fileName -DestinationPath $fPath -Force
            $varName = "monero-x86_64-w64-mingw32-v"+$fileName.Substring(16,$fileName.Length-20)
            If (test-path $subfolder) {
                Move-Item $fPath\$varName\* $subfolder\ -Force
                Remove-Item $fPath\$varName
            } Else {
                Rename-Item $fPath\$varName $subfolder
            }
            Write-Output "Restarting monerod.exe..."
            Start-Process $subfolder\monerod.exe -ArgumentList "$lmdb $prune"
        } Else {
            Write-Output "Hashes do not match!"
            Write-Output "Daemon Hash: $hash"
            Write-Output "File Hash: $fileHash"
        }
    } Else {
        Write-Output "Daemon not running."
        If (Test-Path "$fPath\monero-cli\monerod.exe"){
            Write-Output "Starting monerod.exe..."
            Start-Process $subfolder\monerod.exe -ArgumentList "$lmdb $prune"
        } Else {
            Write-Output "Monerod not found. Downloading latest from the web..."
            $url = "https://downloads.getmonero.org/cli/win64"
            $progresspreference = 'silentlyContinue'
            Invoke-WebRequest $url -OutFile $fPath\$fileName
            $progressPreference = 'Continue'
            $certUtilOutput = (certUtil -hashfile $fPath\$fileName SHA256) -split '\s+'
            $fileHash = $certUtilOutput[4]
            $hashURL = "https://www.getmonero.org/downloads/hashes.txt"
            Invoke-WebRequest $hashURL -OutFile $fPath\hashes.txt
            $hashTXT = Get-Content $fPath\hashes.txt
            ForEach ($line in $hashTXT){
                if ($line -like "*$fileHash*"){
                    $hMatch = $true
                }
            }
            if ($hMatch){
                $pgpSig =  [string] (& gpg --textmode --verify $fPath\hashes.txt 2>&1)
                if ($pgpSig -like "*Good signature from `"binaryFate <binaryfate@getmonero.org>*"){
                    Write-Output "PGP Signature good."
                    Write-Output "Hash match confirmed. Extracting download..."
                    Expand-Archive -LiteralPath $fPath\$fileName -DestinationPath $fPath -Force
                    $varName = "monero-x86_64-w64-mingw32-v"+$fileName.Substring(16,$fileName.Length-20)
                    If (test-path $subfolder) {
                        Move-Item $fPath\$varName\* $subfolder\ -Force
                        Remove-Item $fPath\$varName
                        Remove-Item $fPath\$fileName
                    } Else {
                        Rename-Item $fPath\$varName $subfolder
                    }
                    Write-Output "Starting monerod.exe..."
                    Start-Process $subfolder\monerod.exe -ArgumentList "$lmdb $prune"
                } Else {
                    Write-Output $pgpSig
                    Write-Output "PGP Signature unverifiable! https://www.getmonero.org/resources/user-guides/verification-windows-beginner.html"
                }
            } Else {
                Write-Output "No Hash match found, automatic update will not proceed."
            }
        }
    }
}
