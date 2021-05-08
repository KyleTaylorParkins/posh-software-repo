<#
.SYNOPSIS
    Script to update application installers.

.PARAMETER
    Config: Specify a path to a config.
    RepositoryLocation: Override the repository path from the config file
    
.EXAMPLE
    
.NOTES
    Script name: Update-Repository.ps1
    Version:     1.0
    Author:      Kaalus
    DateCreated: 20210408
    LastUpdate:  20210506

#>

param(
	[string]$Config,
    [string]$RepositoryLocation
)

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $LogMessage
    )

    $TimeStamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    Write-Host ($TimeStamp + " " + $LogMessage)
    Add-Content -Path $LogFile -Value $($TimeStamp + " " + $LogMessage)
}

$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Push-Location $ScriptDir

if ($Config) {
    $JSONConfig = $configPath
} elseif (Test-Path config.json) {
    $JSONConfig = Get-Content config.json | Out-String | ConvertFrom-Json
} else {
    Write-Error "Config file not found, please specify a path or create a 'config.json' in the current folder."
}

if (!$RepositoryLocation -and $JSONConfig.settings.repositorylocation) {
    $RepositoryLocation = $JSONConfig.settings.repositorylocation
} else {
    Write-Error "Config file doesn't contain a repository location! Exiting..."
    exit
}

$LogFile = "installer_download.log"

Write-Log "Installer download script started, gathering jobs..."

# Loop over all backup objects
foreach ($installer in $JSONConfig.installers) {
    # Check the URL
    if (!$installer.url) {
        Write-Error "No download URL path defined, skipping this installer!"
        # Go to the next installer
        continue
    }

    # Check the destination location
    if (!$installer.path) { 
        Write-Error "No destination path defined, skipping this installer!"
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
    Write-Log ("Downloading: " + $installer.name)
    Invoke-RestMethod -Uri $installer.url -OutFile $downloadfile
    Write-Log ($installer.name + " download finished!")
}

Write-Log "All jobs finished!"

Pop-Location