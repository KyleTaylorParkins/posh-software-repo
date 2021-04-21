# Script to update application installers. ® Kaalus (kyle@kaalus.nl), 2021
# v1.0 (20210408): First version

$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Push-Location $ScriptDir

if (Test-Path config.json) {
    $JSONConfig = Get-Content config.json | Out-String | ConvertFrom-Json
} else {
    Write-Error "Config file not found, please create 'config.json' in the same folder as this script!" -Category ReadError
    exit
}

if (!$JSONConfig.settings.repositorylocation) {
    Write-Error "Config file doesn't contain a repository location! Exiting..." -Category ReadError
    exit
}

$logfile = "installer_download.log"

Write-Host "Installer download script started, gathering jobs..." | Tee-Object -FilePath $logfile

# Loop over all backup objects
foreach ($installer in $JSONConfig.installers) {
    # Check the URL
    if (!$installer.url) {
        Write-Error "No download URL path defined, skipping this installer!" | Tee-Object -FilePath $logfile -Append
        # Go to the next installer
        continue
    }

    # Check the destination location
    if (!$installer.path) { 
        Write-Error "No destination path defined, skipping this installer!" | Tee-Object -FilePath $logfile -Append
        continue
    }

    if (!$installer.name -or !$installer.path -or !$installer.executable -or !$installer.url) {
        continue
    }

    # TODO verify that the URL is a valid http/https URL and not some bogus string

    # Create the outputfolder to download the installer to
    $targetfolder = Join-Path -Path $JSONConfig.settings.repositorylocation -ChildPath $installer.path
    $downloadfile = Join-Path -Path $targetfolder -ChildPath $installer.executable

    if (!(Test-Path $targetfolder)) {
        New-Item -Path $targetfolder -ItemType Directory | Out-Null
    }

    # Download the setup file
    Write-Host "Downloading:" $installer.name | Tee-Object -FilePath $logfile -Append
    Invoke-RestMethod -Uri $installer.url -OutFile $downloadfile
    Write-Host "Download finished!" | Tee-Object -FilePath $logfile -Append
}

Write-Host "All jobs finished!" | Tee-Object -FilePath $logfile -Append

Pop-Location