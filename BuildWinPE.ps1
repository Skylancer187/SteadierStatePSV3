# PowerShell Script to automate creating a bootable USB or ISO for WinPE
# Fully updated to follow Microsoft's official WinPE setup guide

param (
    [string]$ISOPath = "C:\Tech\SteadierStateV3\ISO",     # Output ISO location (optional)
    [string]$USBDrive,    # USB Drive letter (optional)
    [string]$ExtraFiles = "C:\Tech\SteadierStateV3\ExtraFiles",   # Additional files to be included (optional)
    [string]$DriversPath = "C:\Tech\SteadierStateV3\Drivers",  # Adjust path to driver storage
    [string]$ExtraApps = "C:\Tech\SteadierStateV3\Applications" # Additional Apps to be included (optional)
)

# Disable automatic errors from stopping the script
$ErrorActionPreference = "Stop"

# Set ADK and WinPE paths
$ADKPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit"
$WinPEAddonPath = "$ADKPath\Windows Preinstallation Environment"
$DeploymentToolsPath = "$ADKPath\Deployment Tools"
$CopypeCmdPath = "$WinPEAddonPath\copype.cmd"
$MakeWinPEMediaCmdPath = "$WinPEAddonPath\makewinpemedia.cmd"

# Check OS build version
$OSBuild = [System.Environment]::OSVersion.Version.Build
if ($OSBuild -le 10240) {
    if (!(Test-Path $ADKPath) -or !(Test-Path $WinPEAddonPath) -or !(Test-Path $CopypeCmdPath) -or !(Test-Path $MakeWinPEMediaCmdPath)) {
        Write-Host "Windows ADK or WinPE Add-on not found. Please install them before proceeding."
        Write-Host "Download Windows ADK: https://go.microsoft.com/fwlink/?linkid=2289980"
        Write-Host "Download WinPE Add-on: https://go.microsoft.com/fwlink/?linkid=2289981"
        exit 1
    }
}

# Replace copype.cmd with fixed version before execution
$FixedCopypeCmdPath = "C:\Tech\SteadierStateV3\WinPEFix\copype.cmd"
if (Test-Path $FixedCopypeCmdPath) {
    Copy-Item -Path $FixedCopypeCmdPath -Destination $CopypeCmdPath -Force
    Write-Host "Replaced copype.cmd with fixed version."
}

# Create a working directory on the system drive
$TempDir = "$env:SystemDrive\WinPE"
if (Test-Path $TempDir) {
    Remove-Item -Recurse -Force $TempDir
}
New-Item -ItemType Directory -Path $TempDir | Out-Null

# Create WinPE working environment using official method
$PEPath = "$TempDir\WinPE_amd64"
Write-Host "Creating WinPE environment..."
& "$CopypeCmdPath" amd64 "$PEPath"

# Check for success
if (!(Test-Path "$PEPath\Media")) {
    Write-Error "WinPE files were not generated correctly. Exiting."
    exit 1
}

# Mount WinPE Image for Customization
Write-Host "Mounting WinPE image for customization..."
$MountPath = "$TempDir\Mount"
New-Item -ItemType Directory -Path $MountPath | Out-Null
Start-Process -NoNewWindow -Wait -FilePath "cmd.exe" -ArgumentList "/c dism /Mount-Image /ImageFile:`"$PEPath\Media\sources\boot.wim`" /Index:1 /MountDir:`"$MountPath`""

# Adding PowerShell Feature
Write-Host "Adding PowerShell support to WinPE..."
Start-Process -NoNewWindow -Wait -FilePath "cmd.exe" -ArgumentList "/c dism /Image:`"$MountPath`" /Add-Package /PackagePath:`"$WinPEAddonPath\WinPE_OCs\WinPE-PowerShell.cab`""

# Download and apply the latest Windows update
Write-Host "Downloading the latest Windows 10 update..."
$UpdateURL = (Invoke-WebRequest -Uri "https://www.catalog.update.microsoft.com/Search.aspx?q=Windows10.0-KB" | Select-String -Pattern "https://download.windowsupdate.com/.*?\.msu" | Select-Object -First 1).Matches.Value
$UpdateFile = "$TempDir\Windows10-Update.msu"
Invoke-WebRequest -Uri $UpdateURL -OutFile $UpdateFile

Write-Host "Applying update $UpdateFile..."
Start-Process -NoNewWindow -Wait -FilePath "cmd.exe" -ArgumentList "/c dism /Image:`"$MountPath`" /Add-Package /PackagePath:`"$UpdateFile`""

# Adding Apps Files (if specified)
Copy-Item "$ExtraApps\*" -Destination "$MountPath\Apps" -Recurse -Force

# Copy necessary files into specific directories
$SRSDest = "$MountPath\SRS"
$HooksDest = "$MountPath\hooks"
$HooksSamplesDest = "$MountPath\hooks-samples"
$RootDest = "$MountPath\"
New-Item -ItemType Directory -Path $SRSDest, $HooksDest, $HooksSamplesDest -Force | Out-Null

Write-Host "Copying specific files to designated directories..."
Copy-Item "$ExtraFiles\SRS\*" -Destination $SRSDest -Recurse -Force
Copy-Item "$ExtraFiles\hooks\*" -Destination $HooksDest -Recurse -Force
Copy-Item "$ExtraFiles\hooks-samples\*" -Destination $HooksSamplesDest -Recurse -Force
Copy-Item "$ExtraFiles\Root\*" -Destination $RootDest -Recurse -Force

# Update wallpaper with winpe.jpg
$WallpaperSource = "$ExtraFiles\Wallpaper\winpe.jpg"
$WallpaperDestination = "$MountPath\Windows\Web\Wallpaper\winpe.jpg"
if (Test-Path $WallpaperSource) {
    Write-Host "Updating default wallpaper..."
    New-Item -ItemType Directory -Path "$MountPath\Windows\Web\Wallpaper" -Force | Out-Null
    Copy-Item $WallpaperSource -Destination $WallpaperDestination -Force
}

# Unmount and Save Changes
Write-Host "Finalizing and unmounting WinPE image..."
Start-Process -NoNewWindow -Wait -FilePath "cmd.exe" -ArgumentList "/c dism /Unmount-Image /MountDir:`"$MountPath`" /Commit"

# Prompt user to create USB, ISO, or both
Write-Host "Process completed successfully."
