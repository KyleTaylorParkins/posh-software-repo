<#
.SYNOPSIS
    Script to update application installers.

.PARAMETER
    Config: Specify a path to a config.
    RepositoryLocation: Override the repository path from the config file
    
.EXAMPLE
    
.NOTES
    Script name: Update-Repository.ps1
    Version:     1.3
    Author:      Kaalus
    DateCreated: 20210408
    LastUpdate:  20211014

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
    if ($LogFile) {
        Add-Content -Path $LogFile -Value $($TimeStamp + " " + $LogMessage)
    }
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
}

if (!$RepositoryLocation) {
    Write-Error "Config file doesn't contain a repository location! Exiting..."
    exit
}

$global:subDirectories = $JSONConfig.settings.createSubdirectories

$LogFile = "installer_download.log"

Write-Log "Installer download script started, gathering jobs..."

# Loop over all backup objects
foreach ($installer in $JSONConfig.installers) {
    # Check the URL
    if (!$installer.url -and !$installer.repository) {
        Write-Error "No download URL path defined, skipping this installer!"
        # Go to the next installer
        continue
    }

    # Check the destination location
    if (!$installer.path) { 
        Write-Error "No destination path defined, skipping this installer!"
        continue
    }

    if (!$installer.name -or !$installer.path -or !$installer.executable) {
        continue
    }

    $type = if ($installer.type) { $installer.type } else { "direct" }

    $global:url = ""
    switch($type) {
        "github" {
            if (!$installer.repository) { continue }
            # Obtain the latest release from Github
            $url = "https://api.github.com/repos/" + $installer.repository + "/releases/latest"
            Write-Host "Getting latest release for " + $installer.repository
            $version = Invoke-RestMethod -Uri $url
            $url = $version.assets[0].browser_download_url
            # Hacky way to workarround powertoys arm64 installer being the first result
            if ($url.toLower().Contains("arm64")) {
                $url = $version.assets[1].browser_download_url
            }
        }
        "direct" {
            $url = $installer.url
        }
    }

    if (!$url -like "http*") {
        Write-Error "Invalid download URL, skipping this installer."
        continue
    }

    # Create the outputfolder to download the installer to
    $targetfolder = if ($subDirectories) { Join-Path -Path $RepositoryLocation -ChildPath $installer.path } else { $RepositoryLocation }
    $downloadfile = Join-Path -Path $targetfolder -ChildPath $installer.executable

    if (!(Test-Path $targetfolder)) {
        New-Item -Path $targetfolder -ItemType Directory | Out-Null
    }

    # Download the setup file
    Write-Log ("Downloading: " + $installer.name + ", from: " + $url)
    Invoke-RestMethod -Uri $url -OutFile $downloadfile
    Write-Log ($installer.name + " download finished!")
}

Write-Log "All jobs finished!"

Pop-Location