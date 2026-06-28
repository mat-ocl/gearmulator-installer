#Install-Module -Name ps2exe -Force
Invoke-PS2EXE -InputFile ".\gm-install-gui.ps1" -OutputFile ".\gm-manager.exe" -Title "Gearmulator VST3 Manager" -Description "Automated Lifecycle Tool" -IconFile ".\icon\dsp56300.ico" -NoConsole
