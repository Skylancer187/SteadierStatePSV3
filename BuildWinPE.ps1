# PowerShell Script to automate creating a bootable USB or ISO for WinPE
# Fully updated to follow Microsoft's official WinPE setup guide

param (
    [string]$ISOPath = "C:\Tech\SteadierStateV3\ISO",     # Output ISO location (optional)
    [string]$USBDrive,    # USB Drive letter (optional)
    [string]$ExtraFiles = "C:\Tech\SteadierStateV3\ExtraFiles",   # Additional files to be included (optional)
    [string]$DriversPath = "C:\Tech\SteadierStateV3\Drivers",  # Adjust path to driver storage
    [string]$ExtraApps = "C:\Tech\SteadierStateV3\Applications", # Additional Apps to be included (optional)
    [string]$language = "en-us" # Language for modules to use
)

# Disable automatic errors from stopping the script
$ErrorActionPreference = "Stop"

# Set ADK and WinPE paths
$ADKPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit"
$WinPEAddonPath = "$ADKPath\Windows Preinstallation Environment"
$DeploymentToolsPath = "$ADKPath\Deployment Tools"
$OscdimgPath = "$DeploymentToolsPath\amd64\Oscdimg"
$CopypeCmdPath = "$WinPEAddonPath\copype.cmd"
$MakeWinPEMediaCmdPath = "$WinPEAddonPath\makewinpemedia.cmd"

# Ensure required directories are in the system PATH
$RequiredPaths = @($DeploymentToolsPath, $WinPEAddonPath, $OscdimgPath)
$CurrentPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
$MissingPaths = $RequiredPaths | Where-Object { $CurrentPath -notlike "*$_*" }

if ($MissingPaths) {
    $NewPath = ($CurrentPath + ";" + ($MissingPaths -join ";")).TrimEnd(';')
    [System.Environment]::SetEnvironmentVariable("Path", $NewPath, [System.EnvironmentVariableTarget]::Machine)
    Write-Host "Updated system PATH to include required directories. Please restart your session for changes to take effect."
    exit 1
}

# Check OS build version
$OSBuild = [System.Environment]::OSVersion.Version.Build
if ($OSBuild -le 10240) {
        Write-Host "Your host OS build $OSBuild is too old to run this WinPE Builder Tool.`nPlease upgrade or use another computer with Windows 10 or 11 23H2 or newer."
        exit 1
}

# Check ADK Paths
if (!(Test-Path $ADKPath) -or !(Test-Path $WinPEAddonPath) -or !(Test-Path $CopypeCmdPath) -or !(Test-Path $MakeWinPEMediaCmdPath)) {
        Write-Host "Windows ADK or WinPE Add-on not found. Please install them before proceeding."
        Write-Host "Download Windows ADK: https://go.microsoft.com/fwlink/?linkid=2289980"
        Write-Host "Download WinPE Add-on: https://go.microsoft.com/fwlink/?linkid=2289981"
        exit 1
}

# Replace copype.cmd with fixed version before execution
$FixedCopypeCmdPath = "C:\Tech\SteadierStateV3\WinPEFix\copype.cmd"
if (Test-Path $FixedCopypeCmdPath) {
    Copy-Item -Path $FixedCopypeCmdPath -Destination $CopypeCmdPath -Force
    Write-Host "Replaced copype.cmd with fixed version."
}

# Remove any old DISM Mounts
$MountPath = "$env:SystemDrive\WinPE\Mount"
if (Test-Path $MountPath) {
    Write-Host "A previous mount exists. Forcing unmount without saving changes."
    if ((Get-ChildItem -Path $MountPath -Recurse -ErrorAction Ignore).count -ge "1")
    {
    Dismount-WindowsImage -Path $MountPath -Discard -ErrorAction SilentlyContinue
    }
    Remove-Item -Recurse -Force $MountPath
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
New-Item -ItemType Directory -Path $MountPath | Out-Null
Mount-WindowsImage -ImagePath "$PEPath\Media\sources\boot.wim" -Index 1 -Path $MountPath

# Adding required WinPE Features
$Packages = @(
    "WinPE-WMI.cab", "en-us\WinPE-WMI_en-us.cab",
    "WinPE-NetFX.cab", "en-us\WinPE-NetFX_en-us.cab",
    "WinPE-Scripting.cab", "en-us\WinPE-Scripting_en-us.cab",
    "WinPE-PowerShell.cab", "en-us\WinPE-PowerShell_en-us.cab",
    "WinPE-StorageWMI.cab", "en-us\WinPE-StorageWMI_en-us.cab",
    "WinPE-DismCmdlets.cab", "en-us\WinPE-DismCmdlets_en-us.cab"
)

foreach ($Package in $Packages) {
    $PackagePath = "$WinPEAddonPath\amd64\WinPE_OCs\$Package"
    if (Test-Path $PackagePath) {
        Write-Host "Adding package: $Package"
        Add-WindowsPackage -Path $MountPath -PackagePath $PackagePath
    } else {
        Write-Error "Package not found: $Package"
        exit 1
    }
}

# Download and apply the latest Windows update (Future Work)
#Write-Host "Downloading the latest Windows 10 update..."
#$UpdateURL = (Invoke-WebRequest -Uri "https://www.catalog.update.microsoft.com/Search.aspx?q=Windows10.0-KB" | Select-String -Pattern "https://download.windowsupdate.com/.*?\.msu" | Select-Object -First 1).Matches.Value
#$UpdateFile = "$TempDir\Windows10-Update.msu"
#Invoke-WebRequest -Uri $UpdateURL -OutFile $UpdateFile

#Write-Host "Applying update $UpdateFile..."
#Add-WindowsPackage -Path $MountPath -PackagePath $UpdateFile

# Copy necessary files into specific directories
$SRSDest = "$MountPath\SRS"
$HooksDest = "$MountPath\hooks"
$HooksSamplesDest = "$MountPath\hooks-samples"
$RootDest = "$MountPath"
$AppsDest = "$MountPath\Apps"
New-Item -ItemType Directory -Path $SRSDest, $HooksDest, $HooksSamplesDest, $AppsDest -Force | Out-Null

Write-Host "Copying specific files to designated directories..."
Copy-Item "$ExtraFiles\SRS\*" -Destination $SRSDest -Recurse -Force
Copy-Item "$ExtraFiles\hooks\*" -Destination $HooksDest -Recurse -Force
Copy-Item "$ExtraFiles\hooks-samples\*" -Destination $HooksSamplesDest -Recurse -Force
Copy-Item "$ExtraFiles\Root\*" -Destination $RootDest -Recurse -Force
Copy-Item "$ExtraApps\*" -Destination $AppsDest -Recurse -Force

# Update wallpaper with winpe.jpg
$WallpaperSource = "$ExtraFiles\Wallpaper\winpe.jpg"
$WallpaperDestination = "$MountPath\Windows\Web\Wallpaper\winpe.jpg"
if (Test-Path $WallpaperSource) {
    Write-Host "Updating default wallpaper..."
    New-Item -ItemType Directory -Path "$MountPath\Windows\Web\Wallpaper" -Force | Out-Null
    Copy-Item $WallpaperSource -Destination $WallpaperDestination -Force
}

# Add drivers from specified directory
if (Test-Path $DriversPath) {
    Write-Host "Adding drivers from: $DriversPath"
    $DriverFiles = Get-ChildItem -Path $DriversPath -Recurse -Filter "*.inf"
    foreach ($Driver in $DriverFiles) {
        Write-Host "Adding driver: $($Driver.FullName)"
        Add-WindowsDriver -Path $MountPath -Driver $Driver.FullName
    }
} else {
    Write-Host "Drivers directory not found, skipping driver addition."
}

# Unmount and Save Changes
Write-Host "Finalizing and unmounting WinPE image..."
Dismount-WindowsImage -Path $MountPath -Save

# Prompt user to create USB, ISO, or both
$Choice = Read-Host "Do you want to create (1) USB, (2) ISO, or (3) both?"
switch ($Choice) {
    "1" {
        if (-not $USBDrive) {
            $USBDrive = Read-Host "Enter USB drive letter (e.g., E:)"
        }
        Write-Host "Creating bootable USB..."
        #& "$MakeWinPEMediaCmdPath" /UFD "$PEPath" $USBDrive
        $arg = "/UFD $PEPath $USBDrive"
        Start-Process -FilePath "makewinpemedia" -ArgumentList "$arg" -Wait
    }
    "2" {
        Write-Host "Creating bootable ISO..."
        #& "$MakeWinPEMediaCmdPath" /ISO "$PEPath" "$ISOPath\WinPE.iso"
        $arg = "/ISO /f $PEPath $ISOPath\WinPE.iso"
        Start-Process -FilePath "makewinpemedia" -ArgumentList "$arg" -Wait
    }
    "3" {
        if (-not $USBDrive) {
            $USBDrive = Read-Host "Enter USB drive letter (e.g., E:)"
        }
        Write-Host "Creating both USB and ISO..."
        #& "$MakeWinPEMediaCmdPath" /UFD "$PEPath" $USBDrive
        #& "$MakeWinPEMediaCmdPath" /ISO "$PEPath" "$ISOPath\WinPE.iso"
        # ISO
        $argISO = "/ISO /f $PEPath $ISOPath\WinPE.iso"
        Start-Process -FilePath "makewinpemedia" -ArgumentList "$argISO" -Wait
        # USB
        $argUSB = "/UFD $PEPath $USBDrive"
        Start-Process -FilePath "makewinpemedia" -ArgumentList "$argUSB" -Wait

    }
    default {
        Write-Host "Invalid selection. Exiting."
        exit 1
    }
}

Write-Host "Process completed successfully."

Start-Sleep -Seconds 30