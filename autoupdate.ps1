<#
Written for PowerShell 5 (Windows 10) - for running as a scheduled task.

The first six variables are all user configurable.
fPath is the parent folder of the cli wallet, log, and updates folder, needs about 70MB of free space.
lmdb is the path to the parent folder of your blockchain storage
    Do not include the lmdb folder itself in the path.
    The default location for lmdb is inside: C:\ProgramData\bitmonero\
    SSD with >100GB free space recommended for unpruned (pruned currently 30GB) 
log is the log filename
prune can be set to "" if you do not require blockchain pruning
subfolder is the extracted cli wallet
tFolder is a temp folder used to expand the update archives
#>

$fPath = "<Your_filepath>"
$lmdb = "--data-dir C:\ProgramData\bitmonero\"
$log = "$fPath\Update.log"
$prune = "--prune-blockchain"
$sFolder = "$fPath\monero-cli"
$tFolder = "$env:TEMP\Updates"
$required = $false
$url = "https://downloads.getmonero.org/cli/win64"
$monerod = (Get-Process -Name monerod -EA SilentlyContinue).id
If (!(Test-Path $tFolder)){
    New-Item -Path $tFolder -ItemType Directory | Out-Null
}
If ($monerod){
    $update = [string] (& (Get-Process -Name monerod -FileVersionInfo).FileName update check)
    If ($update -like "*No update available"){
        Write-Output "No updates required."
    } Else {
        $required = $true
    }
} Else {
    Add-Content $log "$(Get-Date -Format "dd/MM/yyyy HH:mm:ss")> Daemon not running."
    If (Test-Path "$sFolder\monerod.exe"){
        Add-Content $log "$(Get-Date -Format "dd/MM/yyyy HH:mm:ss")> Starting monerod.exe..."
        Start-Process $sFolder\monerod.exe -ArgumentList "$lmdb $prune"
    } Else {
        $required = $true
    }
}
If ($required){
        Add-Content $log "$(Get-Date -Format "dd/MM/yyyy HH:mm:ss")> Update required. Downloading from the web..."
        $progresspreference = 'silentlyContinue'
        Invoke-WebRequest $url -OutFile $tFolder\Monero.zip
        $progressPreference = 'Continue'
        If (VerifyHash){
            If ($monerod){
                Add-Content $log "$(Get-Date -Format "dd/MM/yyyy HH:mm:ss")> Hash match confirmed. Killing monerod and Extracting download..."
                Stop-Process -id $monerod | Wait-Process
            } Else {
                Add-Content $log "$(Get-Date -Format "dd/MM/yyyy HH:mm:ss")> Hash match confirmed. Extracting download..."
            }
            $folderList = (Get-Childitem $tFolder | ? {$_.Attributes -eq "Directory"} | Where-Object {($_.name -like "monero-x86_64-w64-mingw32-v*")})
            ForEach ($folder in $folderList){
                Remove-Item $tFolder\$folder -Recurse
            }
            Expand-Archive -LiteralPath $tFolder\Monero.zip -DestinationPath $tFolder -Force
            $mFolder = (Get-Childitem $tFolder | ? {$_.Attributes -eq "Directory"} | Where-Object {($_.name -like "monero-x86_64-w64-mingw32-v*")})
            If (Test-Path $sFolder) {
                Move-Item $tFolder\$mFolder\* $sFolder\ -Force
                Remove-Item $tFolder\$mFolder -Recurse
                Remove-Item $tFolder\Monero.zip
            } Else {
                Move-Item $tFolder\$mFolder $fPath -Recurse
                Rename-Item $fPath\$mFolder $sFolder
            }
            Add-Content $log "$(Get-Date -Format "dd/MM/yyyy HH:mm:ss")> Restarting monerod.exe..."
            Start-Process $sFolder\monerod.exe -ArgumentList "$lmdb $prune"
        } Else {
            Add-Content $log "$(Get-Date -Format "dd/MM/yyyy HH:mm:ss")> Hashes/PGP Signature unverifiable! Follow: https://www.getmonero.org/resources/user-guides/verification-windows-beginner.html"
        }
}
Function VerifyHash {
    $match = $false
    Invoke-WebRequest "https://www.getmonero.org/downloads/hashes.txt" -OutFile $fPath\Hashes.txt
    $pgpSig =  [string] (& gpg --textmode --verify $fPath\Hashes.txt 2>&1)
    If ($pgpSig -like "*Good signature from `"binaryFate <binaryfate@getmonero.org>*"){
        $certUtilOutput = (certUtil -hashfile $tFolder\monero.zip SHA256) -split '\s+'
        If ((Get-Content $fPath\Hashes.txt | %{$_ -match $certUtilOutput[4]}) -contains $true) {
            $match = $true
        }
    }
    Return $match
}
