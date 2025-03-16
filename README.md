# SteadierStatePSV3
This is the migration from CMD files to support PowerShell versions of Mark Minasi and 7thMC's work.

Requirements:
Windows 10/11 x64 - Editions Enterprise, Education, LTSC, LTSC-IOT (It's possible to use Pro, but not recommended)
Hard Drive with at least 256GB, it is recommended to use an SSD/M.2 drive. Be sure to update your WinPE with any required drivers.
When creating your VHD, you'll need 2.5-2.9 times the space on the physical volume to allow for dynamic expansion.
The host computer must be Windows 10/11 23H2 or newer when creating your WinPE image.

Tasks:
1. BuildPE - Completed - Build Testing
2. CVT2VHD - Not Started
3. PREPNEWPC - Not Started
4. StartnetHD - Not Started
5. BCDDefault - Not Started
6. FirstRun - Not Started
7. Merge - Not Started
8. Rollback - Not Started

Future Tasks and Features:
1. VHD Network Updates
2. Automate Startup Scripts
3. Automate WSUS Updates
4. Automate NUGET/Chocolately 3rd Party
5. Automate Scheduled Events (Restarts/Rollbacks/Merges/Shutdown)

If you're interested in this project, please feel free to reach out and coordinate with me. This is a passion project that I started using back during the Windows 7 days; I have recently picked it back up since I want a solution that's 100% free to anyone who wants a solution for similar needs that I have. I currently took a position to operate an expanded CyberCafe at my local University. I need to use this solution outside of the paid solution we use for most computers we operate like our StreamCaster production systems and our Steam TV PCs.

Again, thanks to anyone who downloads, shares, and commits to the project.

-Skylancer
Matthew - Programs Manager Garnet Gaming Lounge and Esports
