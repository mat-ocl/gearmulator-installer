# Gearmulator VST3 installer for Windows
# https://github.com/mat-ocl

# --- Load .NET assemblies ---
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Net.Http
Add-Type -AssemblyName System.IO.Compression.FileSystem

# --- SETUP ---
$repoOwner = "dsp56300"
$repoName  = "gearmulator"
$baseCacheDir = ".\Gearmulator_Cache"
$versionFile  = ".\gearmulator_installed_version.txt"
$vst3Dir      = "$env:CommonProgramFiles\VST3\gearmulator"

# --- GUI XAML ---
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Gearmulator VST3 Manager" Height="700" Width="700" Background="#1E1E1E" WindowStartupLocation="CenterScreen">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"></RowDefinition>
            <RowDefinition Height="Auto"></RowDefinition>
            <RowDefinition Height="*"></RowDefinition>
        </Grid.RowDefinitions>
        
        <StackPanel Grid.Row="0" Margin="0,0,0,15">
            <TextBlock Text="GEARMULATOR VST3 MANAGER" FontSize="20" FontWeight="Bold" Foreground="#00ADB5"></TextBlock>
            <TextBlock Text="Automated Installer &amp; Lifecycle Management Tool" FontSize="11" Foreground="#888888"></TextBlock>
        </StackPanel>

        <Border Grid.Row="1" Background="#252526" CornerRadius="5" Padding="10" Margin="0,0,0,15">
            <DockPanel LastChildFill="False">
                
                <StackPanel DockPanel.Dock="Left" Orientation="Horizontal" VerticalAlignment="Center">
                    <Button Name="BtnInstallLatest" Content="Install Latest Release" Background="#00ADB5" Foreground="White" Width="140" Height="32" FontWeight="SemiBold" BorderThickness="0" Margin="0,0,10,0"></Button>
                    <TextBlock Text="OR" VerticalAlignment="Center" Foreground="#555555" Margin="5,0,15,0" FontWeight="Bold"></TextBlock>
                    
                    <ComboBox Name="CmbVersions" Width="100" Height="32" VerticalContentAlignment="Center" Background="#2D2D30" Foreground="Black" BorderBrush="#3F3F46" Padding="5,0"></ComboBox>
                    
                    <Button Name="BtnInstallVersion" Content="Install Selected Tag" Background="#3F3F46" Foreground="White" Width="130" Height="32" BorderThickness="0" Margin="8,0,0,0"></Button>
                </StackPanel>
                
                <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" VerticalAlignment="Center">
                    <CheckBox Name="ChkForce" Content="Force" Foreground="#CCCCCC" VerticalAlignment="Center" Margin="0,0,15,0"></CheckBox>
                    <Button Name="BtnMenu" Content="More Actions..." Background="#2D2D30" Foreground="#00ADB5" BorderBrush="#00ADB5" BorderThickness="1" Width="110" Height="32"></Button>
                    
                    <Popup Name="MenuPopup" StaysOpen="False" Placement="Bottom">
                        <Border Background="#1E1E1E" BorderBrush="#3F3F46" BorderThickness="1" Padding="5" CornerRadius="3">
                            <StackPanel Width="220">
                                <Button Name="MenuCheckCurrent" Content="Check Current Active Version" Background="Transparent" Foreground="White" BorderThickness="0" Height="28" HorizontalContentAlignment="Left" Padding="10,0"></Button>
                                <Button Name="MenuFetchTags" Content="Refresh Versions From GitHub" Background="Transparent" Foreground="White" BorderThickness="0" Height="28" HorizontalContentAlignment="Left" Padding="10,0"></Button>
                                <Border BorderBrush="#333333" BorderThickness="0,1,0,0" Margin="2,4"></Border>
                                <Button Name="MenuOpenDir" Content="Open VST3 Folder in Explorer" Background="Transparent" Foreground="White" BorderThickness="0" Height="28" HorizontalContentAlignment="Left" Padding="10,0"></Button>
                                <Border BorderBrush="#333333" BorderThickness="0,1,0,0" Margin="2,4"></Border>
                                <Button Name="MenuPrune" Content="Prune Cached Installer ZIPs" Background="Transparent" Foreground="White" BorderThickness="0" Height="28" HorizontalContentAlignment="Left" Padding="10,0"></Button>
                                <Button Name="MenuUninstall" Content="Completely Uninstall Plugin" Background="Transparent" Foreground="#FF4B4B" BorderThickness="0" Height="28" HorizontalContentAlignment="Left" Padding="10,0"></Button>
                            </StackPanel>
                        </Border>
                    </Popup>
                </StackPanel>
                
            </DockPanel>
        </Border>

        <Grid Grid.Row="2">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"></RowDefinition>
                <RowDefinition Height="*"></RowDefinition>
            </Grid.RowDefinitions>
            <TextBlock Grid.Row="0" Text="ACTIVITY TERMINAL OUTPUT" FontSize="11" FontWeight="Bold" Foreground="#555555" Margin="2,0,0,4"/>
            <TextBox Name="TerminalLog" Grid.Row="1" Background="#111111" Foreground="#A9B7C6" FontFamily="Consolas" FontSize="12" IsReadOnly="True" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap" Padding="8" BorderBrush="#2D2D30"/>
        </Grid>
    </Grid>
</Window>
"@

# Parsing layout structures
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Hooking UI elements to script space
$btnInstallLatest  = $window.FindName("BtnInstallLatest")
$btnInstallVersion = $window.FindName("BtnInstallVersion")
$cmbVersions       = $window.FindName("CmbVersions")
$chkForce          = $window.FindName("ChkForce")
$btnMenu           = $window.FindName("BtnMenu")
$menuPopup         = $window.FindName("MenuPopup")
$terminalLog       = $window.FindName("TerminalLog")

# Dropdown sub-actions mapping
$menuCheckCurrent  = $window.FindName("MenuCheckCurrent")
$menuFetchTags     = $window.FindName("MenuFetchTags")
$menuOpenDir       = $window.FindName("MenuOpenDir")
$menuPrune         = $window.FindName("MenuPrune")
$menuUninstall     = $window.FindName("MenuUninstall")

# Setup the initial placeholder text
[void]$cmbVersions.Items.Add("Loading tags...")
$cmbVersions.SelectedIndex = 0

# --- CUSTOM WINDOW FUNCTIONS ---
function Write-Log {
    param([string]$Message)
    $window.Dispatcher.Invoke({
        $terminalLog.AppendText("[$([DateTime]::Now.ToString('HH:mm:ss'))] $Message`r`n")
        $terminalLog.ScrollToEnd()
    })
}

# Icons
$iconPath = Resolve-Path ".\icon\dsp56300.ico" -ErrorAction SilentlyContinue
if ($iconPath -and (Test-Path $iconPath.Path)) {
    $window.Icon = [Windows.Media.Imaging.BitmapFrame]::Create($iconPath.Path)
}

function Populate-GitHubTags {
    Write-Log "Polling active version tags list from GitHub repository..."
    
    # Use HttpClient asynchronously to avoid blocking the UI thread
    $client = New-Object System.Net.Http.HttpClient
    $client.DefaultRequestHeaders.UserAgent.ParseAdd("PowerShellWPF")
    
    $url = "https://api.github.com/repos/$repoOwner/$repoName/releases?per_page=20"
    
    # Fetch data in the background
    $task = $client.GetStringAsync($url)
    
    # Let the GUI breathe while waiting for the response
    while (-not $task.IsCompleted) {
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
            [System.Windows.Threading.DispatcherPriority]::Background,
            [Action]{}
        )
        Start-Sleep -Milliseconds 50
    }

    try {
        $json = $task.Result
        $allReleases = ConvertFrom-Json $json

        $cmbVersions.Items.Clear()
        if ($allReleases.Count -gt 0) {
            foreach ($release in $allReleases) {
                [void]$cmbVersions.Items.Add($release.tag_name)
            }
            $cmbVersions.SelectedIndex = 0
            Write-Log "Successfully loaded ($($allReleases.Count)) tags into selection dropdown."
        } else {
            [void]$cmbVersions.Items.Add("No tags found")
            $cmbVersions.SelectedIndex = 0
        }
    } catch {
        Write-Log "[ERROR] Failed to populate repository tags: $_"
        $cmbVersions.Items.Clear()
        [void]$cmbVersions.Items.Add("Error loading tags")
        $cmbVersions.SelectedIndex = 0
    }
    
    $client.Dispose()
}

function Run-Installation {
    param(
        [switch]$Latest,
        [string]$VersionTarget
    )
    
    $ForceFlag = $chkForce.IsChecked

    if ($Latest) {
        $apiUrl = "https://api.github.com/repos/$repoOwner/$repoName/releases/latest"
        Write-Log "Checking GitHub for the latest release configuration..."
    } else {
        if ([string]::IsNullOrWhiteSpace($VersionTarget) -or $VersionTarget -eq "Loading tags..." -or $VersionTarget -eq "Error loading tags") {
            Write-Log "[ERROR] Installation failed. Select a valid release version tag from the dropdown."
            return
        }
        $apiUrl = "https://api.github.com/repos/$repoOwner/$repoName/releases/tags/$VersionTarget"
        Write-Log "Checking GitHub for targeted release version '$VersionTarget'..."
    }

    try {
        $client = New-Object System.Net.Http.HttpClient
        $client.DefaultRequestHeaders.UserAgent.ParseAdd("PowerShellWPF")
        
        $task = $client.GetStringAsync($apiUrl)
        while (-not $task.IsCompleted) {
            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [Action]{})
            Start-Sleep -Milliseconds 50
        }
        
        $json = $task.Result
        $releaseInfo = ConvertFrom-Json $json
        $remoteTag   = $releaseInfo.tag_name
        
        if (Test-Path -Path $versionFile) {
            $localTag = Get-Content -Path $versionFile
            if ($localTag -eq $remoteTag -and -not $ForceFlag) {
                Write-Log "Version ($remoteTag) is already installed. Enable 'Force' to re-run execution explicitly."
                $client.Dispose()
                return
            }
        }

        $versionCacheDir = Join-Path -Path $baseCacheDir -ChildPath $remoteTag
        $needsDownload = $true

        if (Test-Path -Path $versionCacheDir) {
            $cachedZips = Get-ChildItem -Path $versionCacheDir -Filter *.zip
            if ($cachedZips.Count -gt 0 -and -not $ForceFlag) {
                Write-Log "Target signature $remoteTag verified inside local folder cache. Moving straight to extraction processing..."
                $needsDownload = $false
            }
        }

        if ($needsDownload) {
            if (-not (Test-Path -Path $versionCacheDir)) {
                New-Item -ItemType Directory -Path $versionCacheDir | Out-Null
            }

            if ($releaseInfo.assets.Count -gt 0) {
                $activeJobs = @()

                # 1. Start downloads in parallel
                foreach ($asset in $releaseInfo.assets) {
                    if ($asset.name -match "win64" -and $asset.name -match "vst3") {
                        $destination = Join-Path -Path $versionCacheDir -ChildPath $asset.name
                        
                        Write-Log "Queueing parallel download for '$($asset.name)'..."
                        $job = Start-BitsTransfer -Source $asset.browser_download_url -Destination $destination -Asynchronous
                        $activeJobs += $job
                    }
                }

                if ($activeJobs.Count -eq 0) {
                    Write-Log "[ERROR] No viable deployment structures detected within GitHub package arrays."
                    $client.Dispose()
                    return
                }

                # 2. Monitor all jobs simultaneously without blocking the UI thread
                Write-Log "Downloading all payloads down to physical staging cache asynchronously..."
                while ($true) {
                    $runningJobs = $activeJobs | Where-Object { $_.JobState -in @("Transferring", "Connecting", "Queued") }
                    
                    # Calculate aggregate download progress across all active assets
                    $totalBytes = 0
                    $bytesTransferred = 0
                    
                    foreach ($job in $activeJobs) {
                        if ($job.BytesTotal -gt 0) {
                            $totalBytes += $job.BytesTotal
                            $bytesTransferred += $job.BytesTransferred
                        }
                    }

                    # Update the Window Title bar with real-time stats if data exists
                    if ($totalBytes -gt 0) {
                        $percent = [math]::Round(($bytesTransferred / $totalBytes) * 100)
                        $mbTransferred = [math]::Round($bytesTransferred / 1MB, 1)
                        $mbTotal = [math]::Round($totalBytes / 1MB, 1)
                        
                        # Change window title to show live progress
                        $window.Title = "Gearmulator VST3 Manager - Downloading: $percent% ($mbTransferred MB / $mbTotal MB)"
                    }

                    if ($null -eq $runningJobs -or $runningJobs.Count -eq 0) {
                        break # All jobs have finished
                    }

                    # Let the WPF engine paint logs and stay responsive
                    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
                        [System.Windows.Threading.DispatcherPriority]::Background,
                        [Action]{}
                    )
                    Start-Sleep -Milliseconds 200
                }

                # Reset the window title back to default when the batch completes
                $window.Title = "Gearmulator VST3 Manager"


                # 3. Finalize and complete each job safely
                foreach ($job in $activeJobs) {
                    if ($job.JobState -eq "Transferred") {
                        Complete-BitsTransfer -BitsJob $job
                    } else {
                        Write-Log "[WARN] A download job failed or was interrupted. State: $($job.JobState)"
                        Remove-BitsTransfer -BitsJob $job
                    }
                }
                Write-Log "All active parallel download jobs resolved."
                
            } else {
                Write-Log "[ERROR] No files (assets) were found attached to this release."
                $client.Dispose()
                return
            }
        } else {
            # Explicitly log when the cache check passes
            Write-Log "Cache Verification Passed: Using local cached assets for version $remoteTag."
        }

        # Check that there is files
        $zipFiles = Get-ChildItem -Path $versionCacheDir -Filter *.zip
        if ($zipFiles.Count -eq 0) {
            Write-Log "[ERROR] Operations halted. No .zip files materialized."
            $client.Dispose()
            return
        }

        # Extraction Handling
        foreach ($zip in $zipFiles) {
            Write-Log "Opening archive: $($zip.Name)..."
            
            try {
                # Open the zip archive via native .NET
                $archive = [System.IO.Compression.ZipFile]::OpenRead($zip.FullName)
                
                foreach ($entry in $archive.Entries) {
                    # Skip empty directory entries
                    if ([string]::IsNullOrEmpty($entry.Name)) { continue }
                    
                    # Log the specific item being extracted
                    Write-Log " -> Extracting: $($entry.Name)"
                    
                    # Define full target deployment path
                    $targetPath = Join-Path -Path $vst3Dir -ChildPath $entry.FullName
                    $targetFolder = Split-Path -Path $targetPath
                    
                    # Ensure destination subfolders exist
                    if (-not (Test-Path -Path $targetFolder)) {
                        New-Item -ItemType Directory -Path $targetFolder | Out-Null
                    }
                    
                    # Extract item and overwrite if it already exists
                    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $targetPath, $true)
                    
                    # Force a repaint of the terminal window
                    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
                        [System.Windows.Threading.DispatcherPriority]::Background,
                        [Action]{}
                    )
                }
                
                $archive.Dispose()
                Write-Log "Processing for $($zip.Name) successfully completed."
                
            } catch {
                Write-Log "[ERROR] Extraction failed for $($zip.Name): $_"
                if ($null -ne $archive) { $archive.Dispose() }
                $client.Dispose()
                return
            }
        }

        # Save versionfile
        Set-Content -Path $versionFile -Value $remoteTag
        Write-Log "SUCCESS: Gearmulator version $remoteTag succesfully installed!"

    } catch {
        Write-Log "[CRITICAL ERROR] Execution Exception: $_"
    } finally {
        if ($null -ne $client) { $client.Dispose() }
    }
}


function CurrentVersion {
    if (Test-Path -Path $versionFile) {
        $installed = Get-Content -Path $versionFile
        Write-Log "System State Verification: Active Installation reads ($installed)."
    } else {
        Write-Log "No installation version discovered locally."
    }
}

# --- EVENT ROUTING CONTROLS ---
$btnMenu.Add_Click({
    $menuPopup.IsOpen = $true
})

$btnInstallLatest.Add_Click({
    Run-Installation -Latest
})

$btnInstallVersion.Add_Click({
    $selectedTag = $cmbVersions.SelectedItem
    Run-Installation -VersionTarget $selectedTag
})

$menuCheckCurrent.Add_Click({
    $menuPopup.IsOpen = $false
    CurrentVersion
})

$menuFetchTags.Add_Click({
    $menuPopup.IsOpen = $false
    Populate-GitHubTags
})

$menuOpenDir.Add_Click({
    $menuPopup.IsOpen = $false
    if (Test-Path -Path $vst3Dir) {
        Write-Log "Opening the VST3 folder: $vst3Dir location..."
        Start-Process explorer.exe $vst3Dir
    } else {
        Write-Log "[WARN] Target output directory not yet deployed."
    }
})

$menuPrune.Add_Click({
    $menuPopup.IsOpen = $false
    if (Test-Path -Path $baseCacheDir) {
        Remove-Item -Path $baseCacheDir -Recurse -Force
        Write-Log "All downloaded zip files removed from cache directory."
    } else {
        Write-Log "Cache targets clear. No operations required."
    }
})

$menuUninstall.Add_Click({
    $menuPopup.IsOpen = $false
    Write-Log "Initializing global removal routine..."
    if (Test-Path -Path $vst3Dir) {
        Remove-Item -Path $vst3Dir -Recurse -Force
        Write-Log "VST3 plugins uninstalled."
    }
    if (Test-Path -Path $versionFile) {
        Remove-Item -Path $versionFile -Force
        Write-Log "Versionfile removed."
    }
    Write-Log "Uninstallation complete."
})

# Queue up the Github retrieval after the GUI is fully visible
$window.Add_ContentRendered({
    CurrentVersion
    Write-Log "Initializing GitHub repository discovery..."
    Populate-GitHubTags
})

# Close the UI and stop the pipeline
$window.Add_Closed({
    # Stop all BITS downloads if any are active
    if ($activeJobs) {
        $activeJobs | Where-Object { $_.JobState -in @("Transferring", "Connecting", "Queued") } | Remove-BitsTransfer
    }
    
    # Check if we are running inside an interactive editor host (like ISE or VS Code)
    if ($host.Name -match "Visual Studio" -or $host.Name -match "ISE") {
        # Just close the window object and return, don't close the editor
        return
    } else {
        # If running as a standalone script or EXE, exit cleanly
        Exit
    }
})

# Launch the Application
$window.ShowDialog() | Out-Null