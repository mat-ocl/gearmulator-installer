# Gearmulator VST3 Installer & Manager for Windows

A lightweight PowerShell utility to automate the downloading, caching, and installation of the [DSP56300 Gearmulator](https://github.com/dsp56300/gearmulator) VST3 plugins on Windows. 


---

## ✨ Features

* **Installation:** Fetches the `win64` VST3 zip files directly from GitHub and extracts them to your system's VST3 directory.
* **Caching:** Saves downloaded versions in a local `Gearmulator_Cache` folder. If you roll back or reinstall a previously downloaded version, it extracts instantly without hitting the network.
* **Version Control:** Easily switch between the absolute latest release or any older specific version tag.
* **CLI Tools:** Check your currently installed version, quickly open the VST3 folder, browse available GitHub releases, or wipe your cache.
* **Uninstall:** Completely removes the gearmulator VST3 plugin files with a single command.

## 🚀 Ways to run it

### 1. Binary finary -New feature
1. Download binary (.exe) from releases.
2. Run the `gm-manager.exe`

### 2. Use the original CLI script
1. Download the `gm-install.ps1` script to your preferred working directory.
2. Open PowerShell.
3. Run the script with no arguments to see the help menu, or use the `-Latest` flag to install the latest version immediately.

```powershell
.\gm-install.ps1 -Latest
```

### 3. Use the helper batch file
1. Download `gm-install.ps1` script and `gm-install.bat` to your preferred working directory.
2. Run `gm-install.bat` by double cliking on it. This will always install the latest versions. Easy peasy.

### 4. Run the new Gui version from powershell
1. Download the `gm-install-gui.ps1` script to your preferred working directory.
2. Open PowerShell.
3. Run the script and the Gui will pop up.

