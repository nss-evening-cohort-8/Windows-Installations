# NSS Evening Backend Requirements Installer

This PowerShell script will check your Windows machine to see if the required tools are installed and if not will download and install them for you.

## Requirements

- Windows Powershell running as Administrator
  - Click on Start button
  - Type Powershell
  - Right click and select `Run as Administrator`
  - OR
  - CTRL + SHIFT click on PowerShell icon
- 64-Bit Windows Operating System
- High speed Internet Connection

## How to Run

1. Click Start Button on taskbar
1. Start typing `PowerShell`
1. Right click on the PowerShell icon and select `Run as Administrator`
1. In your Powershell window change to your `Downloads` Directory by typing the following
   - `cd $env:HOMEPATH\Downloads`
1. Copy and paste the follwing into the Powershell window
   > iex ((New-Object System.Net.WebClient).DownloadString('https://bit.ly/2MjrDVf'))
1. Press Enter Key
1. ???
1. PROFIT!

## Items Installed

1. Git - Latest Version (This should already be installed from Front End)
1. Visual Studio Community 2019
1. .Net Core SDK 3.1.101 (Latest at the time of this commit)
1. SQL Server 2019 Developer
1. SQL Server Management Studio (SSMS) 18.4
