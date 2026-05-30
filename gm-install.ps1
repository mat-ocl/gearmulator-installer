# Gearmulator VST3 installer for Windows
# https://github.com/mat-ocl

param (
    [Alias("l")]
    [switch]$Latest,

    [Alias("v")]
    [string]$Version,

    [Alias("t")]
    [switch]$Tags,

    [Alias("c")]
    [switch]$Current,

    [Alias("f")]
    [switch]$Force,

    [Alias("p")]
    [switch]$Prune,

    [Alias("u")]
    [switch]$Uninstall,
    
    [Alias("o")]
    [switch]$Open
)

# GitHub API setup
$repoOwner = "dsp56300"
$repoName  = "gearmulator"

# Base cache folder, version tracker, and VST3 installation directory
$baseCacheDir = ".\Gearmulator_Cache"
$versionFile  = ".\gearmulator_installed_version.txt"
$vst3Dir      = "$env:CommonProgramFiles\VST3\gearmulator"

# --- DEFAULT BEHAVIOR (INFO / HELP MENU) ---
if ($PSBoundParameters.Count -eq 0) {
    Write-Host "=========================================================" -ForegroundColor Cyan
    Write-Host " Gearmulator VST3 Plugin Installer / Manager for Windows" -ForegroundColor Cyan
    Write-Host "=========================================================" -ForegroundColor Cyan
    Write-Host "This script automates downloading and installing"
    Write-Host "the DSP56300 Gearmulator VST3 plugins directly from GitHub."
    Write-Host ""
    Write-Host "Available Options:" -ForegroundColor Yellow
    Write-Host "  -Latest, -l      Download and install the absolute latest release."
    Write-Host "  -Version, -v     Download and install a specific version tag (e.g., -v 'v1.2.0')."
    Write-Host "  -Tags, -t        List all available release versions from the GitHub repository."
    Write-Host "  -Current, -c     Display the currently installed version of Gearmulator."
    Write-Host "  -Force, -f       Bypass version checks to force a redownload or re-extraction."
    Write-Host "  -Prune, -p       Wipe the entire local cache folder structure to free up space."
    Write-Host "  -Uninstall, -u   Completely remove the installed VST3 plugin folder and tracking file."
    Write-Host "  -Open, -o        Open the VST3 installation folder in Windows Explorer."
    Write-Host ""
    Write-Host "Usage Examples:" -ForegroundColor DarkGray
    Write-Host "  .\install_gearmulator.ps1 -Latest"
    Write-Host "  .\install_gearmulator.ps1 -Version '2.1.1'"
    Write-Host "  .\install_gearmulator.ps1 -Tags"
    Write-Host "=========================================================" -ForegroundColor Cyan
    exit
}

# --- PRUNE ---
if ($Prune) {
    if (Test-Path -Path $baseCacheDir) {
        Write-Host "Pruning cache directory and all saved ZIPs..." -ForegroundColor Yellow
        Remove-Item -Path $baseCacheDir -Recurse -Force
        Write-Host "Cache pruned successfully!" -ForegroundColor Green
    } else {
        Write-Host "No cache directory found to prune. It's already clean." -ForegroundColor DarkGray
    }
    exit 
}

# --- UNINSTALL ---
if ($Uninstall) {
    Write-Host "Preparing to uninstall Gearmulator..." -ForegroundColor Cyan
    $uninstalledSomething = $false

    if (Test-Path -Path $vst3Dir) {
        Write-Host "Removing VST3 directory: $vst3Dir" -ForegroundColor Yellow
        Remove-Item -Path $vst3Dir -Recurse -Force
        $uninstalledSomething = $true
    }

    if (Test-Path -Path $versionFile) {
        Write-Host "Clearing active version tracker..." -ForegroundColor Yellow
        Remove-Item -Path $versionFile -Force
        $uninstalledSomething = $true
    }

    if ($uninstalledSomething) {
        Write-Host "Gearmulator has been successfully uninstalled!" -ForegroundColor Green
    } else {
        Write-Host "Gearmulator is not currently installed. Nothing to remove." -ForegroundColor DarkGray
    }
    exit 
}

# --- FETCH TAGS ---
if ($Tags) {
    Write-Host "Fetching available versions for $repoOwner/$repoName..." -ForegroundColor Cyan
    $tagsUrl = "https://api.github.com/repos/$repoOwner/$repoName/releases?per_page=100"
    
    try {
        $allReleases = Invoke-RestMethod -Uri $tagsUrl
        if ($allReleases.Count -gt 0) {
            Write-Host "`nAvailable Versions:" -ForegroundColor Green
            foreach ($release in $allReleases) {
                Write-Host "  - $($release.tag_name)"
            }
            Write-Host "" 
        } else {
            Write-Host "No releases found for this repository." -ForegroundColor Yellow
        }
    } catch {
        Write-Error "An error occurred while trying to fetch the tags."
        Write-Error $_.Exception.Message
    }
    exit 
}

# --- CURRENT VERSION ---
if ($Current) {
    if (Test-Path -Path $versionFile) {
        $installedVersion = Get-Content -Path $versionFile
        Write-Host "Currently installed version: " -NoNewline
        Write-Host $installedVersion -ForegroundColor Green
    } else {
        Write-Host "Gearmulator is not currently installed (no tracking file found)." -ForegroundColor Yellow
    }
    exit 
}

# --- OPEN DIRECTORY ---
if ($Open) {
    if (Test-Path -Path $vst3Dir) {
        Write-Host "Opening VST3 directory..." -ForegroundColor Cyan
        Start-Process explorer.exe $vst3Dir
    } else {
        Write-Host "The VST3 folder does not exist yet ($vst3Dir). Try installing Gearmulator first." -ForegroundColor Yellow
    }
    exit 
}

# --- DETERMINE ENDPOINT ---
if ($Latest) {
    $apiUrl = "https://api.github.com/repos/$repoOwner/$repoName/releases/latest"
} elseif (-not [string]::IsNullOrWhiteSpace($Version)) {
    $apiUrl = "https://api.github.com/repos/$repoOwner/$repoName/releases/tags/$Version"
} else {
    Write-Host "Error: You must specify either -Latest or -Version to run an installation." -ForegroundColor Red
    exit
}

# --- DOWNLOAD & CACHE ---
try {
    if ($Latest) {
        Write-Host "Checking GitHub for the latest release of $repoOwner/$repoName..."
    } else {
        Write-Host "Checking GitHub for release '$Version' of $repoOwner/$repoName..."
    }
    
    # Fetch the release information from the GitHub API
    $releaseInfo = Invoke-RestMethod -Uri $apiUrl
    $remoteTag   = $releaseInfo.tag_name
    
    # Check if this version is already installed based on our versionfile
    if (Test-Path -Path $versionFile) {
        $localTag = Get-Content -Path $versionFile
        
        if ($localTag -eq $remoteTag -and -not $Force) {
            Write-Host "You already have version ($remoteTag) actively installed." -ForegroundColor Green
            Write-Host "Use the -Force (or -f) parameter if you want to reinstall it anyway." -ForegroundColor DarkGray
            exit
        } elseif ($localTag -ne $remoteTag) {
            Write-Host "Different version requested! ($localTag -> $remoteTag)." -ForegroundColor Cyan
        }
    } else {
        Write-Host "No previous installation recorded. Target release is $remoteTag." -ForegroundColor Cyan
    }

    # Define the specific cache folder for this exact version
    $versionCacheDir = Join-Path -Path $baseCacheDir -ChildPath $remoteTag
    $needsDownload = $true

    # Cache Check: Does the folder exist and contain a zip file?
    if (Test-Path -Path $versionCacheDir) {
        $cachedZips = Get-ChildItem -Path $versionCacheDir -Filter *.zip
        if ($cachedZips.Count -gt 0 -and -not $Force) {
            Write-Host "Version $remoteTag found in local cache! Skipping download..." -ForegroundColor Green
            $needsDownload = $false
        }
    }

    # If it's not cached (or if the user forced it), download it
    if ($needsDownload) {
        if (-not (Test-Path -Path $versionCacheDir)) {
            New-Item -ItemType Directory -Path $versionCacheDir | Out-Null
            Write-Host "Created new cache directory: $versionCacheDir" -ForegroundColor DarkGray
        }

        if ($releaseInfo.assets.Count -gt 0) {
            foreach ($asset in $releaseInfo.assets) {
                if ($asset.name -match "win64" -and $asset.name -match "vst3") {
                    $downloadUrl = $asset.browser_download_url
                    $fileName    = $asset.name
                    $destination = Join-Path -Path $versionCacheDir -ChildPath $fileName

                    Write-Host "Downloading $fileName to cache..."
                    Invoke-WebRequest -Uri $downloadUrl -OutFile $destination
                    Write-Host "Successfully cached: $fileName" -ForegroundColor Yellow
                } else {
                    Write-Host ("Skipping " + $asset.name) -ForegroundColor DarkGray
                }
            }
        } else {
            Write-Host "No files (assets) were found attached to this release." -ForegroundColor Red
            exit
        }
    }
} catch {
    Write-Host "An error occurred while trying to fetch the release or download files." -ForegroundColor Yellow
    Write-Host "Make sure your version tag exactly matches the GitHub release (e.g., 'v1.2.3')." -ForegroundColor Yellow
    Write-Host "You can list the tags with -Tags or -t" -ForegroundColor Yellow
    exit
}

# --- EXTRACTION ---
$zipFiles = Get-ChildItem -Path $versionCacheDir -Filter *.zip

if ($zipFiles.Count -eq 0) {
    Write-Host "No ZIP files found in the cache ($versionCacheDir)." -ForegroundColor Red
    Exit
}

foreach ($zip in $zipFiles) {
    Write-Host "`nExtracting: $($zip.Name)..." -ForegroundColor Cyan
    
    Expand-Archive -Path $zip.FullName -DestinationPath $vst3Dir -Force
    
    Write-Host "  -> Done! (Kept $($zip.Name) in cache)" -ForegroundColor Green
}

# Update the tracker
Set-Content -Path $versionFile -Value $remoteTag
Write-Host "`nInstallation tracker updated. Currently active version: $remoteTag" -ForegroundColor DarkGray
