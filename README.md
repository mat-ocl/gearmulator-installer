# Gearmulator VST3 Installer & Manager for Windows

A lightweight PowerShell utility to automate the downloading, caching, and installation of the [DSP56300 Gearmulator](https://github.com/dsp56300/gearmulator) VST3 plugins on Windows. 


---

## ✨ Features

* **Installation:** Fetches the `win64` VST3 zip files directly from GitHub and extracts them to your system's VST3 directory.
* **Caching:** Saves downloaded versions in a local `Gearmulator_Cache` folder. If you roll back or reinstall a previously downloaded version, it extracts instantly without hitting the network.
* **Version Control:** Easily switch between the absolute latest release or any older specific version tag.
* **CLI Tools:** Check your currently installed version, quickly open the VST3 folder, browse available GitHub releases, or wipe your cache.
* **Uninstall:** Completely removes the gearmulator VST3 plugin files with a single command.

## 🚀 Quick Start

1. Download the `gm-install.ps1` script to your preferred working directory.
2. Open PowerShell.
3. Run the script with no arguments to see the help menu, or use the `-Latest` flag to install the latest version immediately:

```powershell
.\gm-install.ps1 -Latest
