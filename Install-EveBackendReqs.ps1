#========================================================================
# Created on:   02/21/2019 (MM/DD/YYYY)
# Created by:   Marco Crank
# Organization: Nashville Software School
# Filename:     Install-EveBackendReqs.ps1
# Version:      2.0
# Disclaimer:   THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF
#               ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO
#               THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
#               PARTICULAR PURPOSE.
#
#               IN NO EVENT SHALL "Nashville Software School" AND/OR ITS RESPECTIVE SUPPLIERS
#               BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY
#               DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS
#               WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS
#               ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
#               OF THIS CODE OR INFORMATION.
#
#
# What it Do:   Downloads and installs the necessary tools for the Evening Back End
#               class on Windows devices.
#
# Updates:      1.0 - (02/21/2019) Initial Release
#               2.0 - (08/15/2019) Updated for 2019, Added .Net Core SDK
#========================================================================

#requires -RunAsAdministrator

Clear-Host

# Constants
# Path Variables need to end in FolderPath as I am reading them in to create the Folder Hierarchy in the

# *** Root Folder ***
$RootFolderPath = 'C:\Nss_Install'

# *** SSMS ***
$SsmsRequiredVersion = '15.0.18142.0' # SSMS 17 RTM (https://sqlserverbuilds.blogspot.com/2018/01/sql-server-management-studio-ssms.html)
$SsmsFolderPath = "$RootFolderPath\SSMS" #SSMS-Setup-ENU.exe
$SsmsUrl = 'https://go.microsoft.com/fwlink/?linkid=2099720'

# *** SQL Developer Edition ***
$SqlRequiredVersion = '14.0.1000.169' # SQL 2017 RTM (http://sqlserverbuilds.blogspot.com/)
$SqlFolderPath = "$RootFolderPath\SQL" # SQLServer2017-SSEI-Dev.exe
$SqlUrl = 'https://go.microsoft.com/fwlink/?linkid=853016'
$SqlConfigUrl = 'https://bit.ly/2GTSp36'

# *** VS Community Edition 2019 ***
$VsFolderPath = "$RootFolderPath\VS" # vs_community.exe
$VsCommunityUrl = 'https://download.visualstudio.microsoft.com/download/pr/818029a2-ea31-4a6a-8bed-f50abbaf9716/ff2d0f080b97ad9de29126e301f93a26/vs_community.exe'

# *** .Net Core 2.2.401 SDK (VS 2019 Version)
# Hardcoding to this version as it is the latest.  No easy way to just get the latest because Microsoft is stupid with the versioning of .net core now
#   and grabbing the release from Github...Well yeah all the links are in markdown files so this is what you get
$DotNetFolderPath = "$RootFolderPath\DotNetCore"
$DotNetUrl = 'https://download.visualstudio.microsoft.com/download/pr/c76aa823-bbc7-4b21-9e29-ab24ceb14b2d/9de2e14be600ef7d5067c09ab8af5063/dotnet-sdk-2.2.401-win-x64.exe'

# *** KDiff3 ***
# Hasn't been updated in many moons
$Kdiff3FolderPath = "$RootFolderPath\KDiff" #KDiff3-64bit-Setup_0.9.98-2.exe
$Kdiff3Url = 'https://svwh.dl.sourceforge.net/project/kdiff3/kdiff3/0.9.98/KDiff3-64bit-Setup_0.9.98-2.exe'

# *** Git ***
# Git is a bit different since they have version in the name.  Let's grab the latest from the API
$LatestGitFerWindersRelease = (Invoke-WebRequest 'https://api.github.com/repos/git-for-windows/git/releases/latest' -UseBasicParsing -Headers @{"Accept" = "application/json" }).Content | ConvertFrom-Json
$GitDownloadUrl = ($LatestGitFerWindersRelease.assets | Where-Object { $_.Name -like "Git-*-64-bit.exe" }).browser_download_url
$GitName = ($LatestGitFerWindersRelease.assets | Where-Object { $_.Name -like "Git-*-64-bit.exe" }).name
$GitConfigIniUrl = 'https://bit.ly/31Bi2Nl'
$GitFolderPath = "$RootFolderPath\Git"

function Out-Console ()
{
  Param(
    [string]$Message,
    [ValidateSet('Info', 'Check', 'Error')]
    [string]$Mode
  )
  switch ($Mode)
  {
    'Info' { $ForeColor = 'Green' }
    'Check' { $ForeColor = 'Yellow' }
    'Error' { $ForeColor = 'Red' }
    Default { $ForeColor = 'Green' }
  }
  Write-Host "`n$Message`n" -BackgroundColor Black -ForegroundColor $ForeColor
}

function New-NSSFolders ()
{
  Param([string]$Path)
  if (!(Test-Path -Path $Path))
  {
    New-Item -Path $Path -ItemType Directory -Force
  }
}

function Confirm-VisualStudio ()
{
  if (Get-Package -Name "Visual Studio Community 2019" -ProviderName Programs -ErrorAction SilentlyContinue)
  {
    Out-Console -Message "Visual Studio Already Installed" -Mode Check
    return $true
  }
  else
  {
    Out-Console -Message "Visual Studio not installed. Downloading Installation." -Mode Check
    Start-BitsTransfer -Source $VsCommunityUrl -Destination "$VsFolderPath\vs_community.exe"
    return $false
  }
}

function Confirm-DotnetCore
{
  if (Get-Package -ProviderName Programs -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*Microsoft .NET Core SDK 2.2*" -and $_.Version -ge '2.2.401' })
  {
    Out-Console -Message "Required .Net Core SDK Already Installed" -Mode Check
    return $true
  }
  else
  {
    Out-Console -Message "Required .Net Core SDK not found. Downloading Installation" -Mode Check
    Start-BitsTransfer -Source $DotNetUrl -Destination "$DotNetFolderPath\dotnet-sdk-2.2.401-win-x64.exe"
    return $false
  }
}

function Confirm-SqlInstall ()
{
  $SqlInstances = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server' -ErrorAction SilentlyContinue).InstalledInstances
  if (!($SqlInstances -contains "MSSQLSERVER"))
  {
    # Default instance not found so
    Out-Console -Message "SQL 2017 Instance not found. Downloading Installation" -Mode Check
    Start-BitsTransfer -Source $SqlConfigUrl -Destination "$SqlFolderPath\ConfigurationFile.ini"
    Start-BitsTransfer -Source $SqlUrl -Destination "$SqlFolderPath\SQLServer2017-SSEI-Dev.exe"
    return $false
  }
  else
  {
    # Found a SQL install.  Check if it is at least ther version we need based on $SqlRequiredVersion
    $SqlDefaultInstance = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL').MSSQLSERVER
    if ((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$SqlDefaultInstance\Setup").Version -ge $SqlRequiredVersion)
    {
      Out-Console -Message "SQL Server Already Installed" -Mode Check
      return $true
    }
    else
    {
      # Found a default instance but it is lower version than SQL 2017.  Manual upgrade
      Out-Console -Message "***** Older SQL server version found please upgrade manually ******" -Mode Error
      return $true
    }
  }
}

function Confirm-SSMS ()
{
  $SSMSVersion = (Get-Package -Name "Microsoft SQL Server Management Studio*" -ProviderName 'Programs' -ErrorAction SilentlyContinue).Version
  if ($SSMSVersion -ge $SsmsRequiredVersion)
  {
    Out-Console -Message "SSMS Already Installed" -Mode Check
    return $true
  }
  else
  {
    Out-Console -Message "SSMS version not met. Downloading Installation" -Mode Check
    Start-BitsTransfer -Source $SsmsUrl -Destination "$SsmsFolderPath\SSMS-Setup-ENU.exe"
    return $false
  }
}

function Confirm-Kdiff
{
  if (Get-Package -Name *Kdiff* -ProviderName Programs -ErrorAction SilentlyContinue)
  {
    Out-Console -Message "KDiff Already Installed" -Mode Check
    return $true
  }
  else
  {
    Start-BitsTransfer -Source $Kdiff3Url -Destination "$Kdiff3FolderPath\KDiff3-64bit-Setup_0.9.98-2.exe"
    return $false
  }
}

function Confirm-Git
{
  if (Get-Package -Name *git* -ProviderName Programs -ErrorAction SilentlyContinue)
  {
    Out-Console -Message "Git for Windows already installed" -Mode Check
    return $true
  }
  else
  {
    Start-Process bitsadmin.exe -ArgumentList " /transfer GitDownload /dynamic /priority FOREGROUND $GitDownloadUrl $GitFolderPath\$GitName" -WindowStyle Hidden -Wait
    Invoke-WebRequest -Uri $GitConfigIniUrl -OutFile "$GitFolderPath\GitConfig.ini"
    return $false
  }
}

function Confirm-GitConfig
{
  Param ([string]$Command)
  # merge.tool=kdiff3
  # mergetool.kdiff3.path=C:/Program Files/KDiff3/kdiff3.exe
  Start-Process -FilePath "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList "git config --get $Command" -RedirectStandardOutput 'C:\Nss_Install\check_gitconfig.txt' -NoNewWindow -Wait
  $Result = Get-Content -Path  'C:\Nss_Install\check_gitconfig.txt'
  if ($Result -eq 'kdiff3')
  {
    return $true
  }
  else
  {
    return $false
  }
}

Out-Console -Message "Setting Execution policy to Bypass"
Set-ExecutionPolicy Bypass -Scope Process -Force

# Check Operating System Architecture. Requires 64-Bit
Out-Console -Message "Checking Operating System Architecture"
$OSArchitecture = (Get-CimInstance -ClassName Win32_OperatingSystem).OSArchitecture
if ($OSArchitecture -ne "64-Bit")
{
  Out-Console -Message "This script requires you to be running 64-Bit Windows. NSS requirements need manual install" -Mode Error
  break
}

# Check/Create our folders
Out-Console -Message "Creating Folder Hierarchy at: $RootFolderPath"
$FolderPaths = @($(Get-Variable | Where-Object { $_.Name -Like "*FolderPath" }))
foreach ($Path in ($FolderPaths | Sort-Object -Property 'Value'))
{
  New-NSSFolders -Path "$($Path.Value)"
}

Out-Console -Message "Installing Git for Windows"
# Check if git is installed, At this point it should be unless a fresh install
if (!(Confirm-Git))
{
  Start-Process -FilePath "$GitFolderPath\$GitName" -ArgumentList "/VERYSILENT /LOADINF=GitConfig.inf /NORESTART" -NoNewWindow -Wait
}

Out-Console -Message "Installing Visual Studio 2019 Community"
# Command line options
# https://docs.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2019
# If VS fails to install check out the %TEMP% Directory and look for logs that begin with dd_bootstrapper, dd_client, dd_setup for errors
# Might need to uninstall and run the script again
# https://docs.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2019#error-codes
if (!(Confirm-VisualStudio))
{
  Start-Process -FilePath "$VsFolderPath\vs_community.exe" -ArgumentList "--includeRecommended --quiet --add Microsoft.VisualStudio.Workload.ManagedDesktop --add Microsoft.VisualStudio.Workload.NetCoreTools --add Microsoft.VisualStudio.Workload.NetWeb --norestart" -NoNewWindow -Wait
}

Out-Console -Message "Installing .Net Core SDK"
if (!(Confirm-DotnetCore))
{
  Start-Process -FilePath "$DotNetFolderPath\dotnet-sdk-2.2.401-win-x64.exe" -ArgumentList "/quiet /norestart /log $DotNetFolderPath\dotnet_install.txt" -NoNewWindow -Wait
}

Out-Console -Message "Downloading SQL Server 2017 Developer Edition Bootstrap files"
if (!(Confirm-SqlInstall))
{
  Start-Process -FilePath "$SqlFolderPath\SQLServer2017-SSEI-Dev.exe" -ArgumentList "/ACTION=Install /CONFIGURATIONFILE=$SqlFolderPath\ConfigurationFile.ini /IACCEPTSQLSERVERLICENSETERMS /MEDIAPATH=$SqlFolderPath /QUIET" -NoNewWindow -Wait
}

Out-Console -Message "Installing SQL Server Management Studio (SSMS)"
if (!(Confirm-SSMS))
{
  Start-Process -FilePath "$SsmsFolderPath\SSMS-Setup-ENU.exe" -ArgumentList "/install /quiet /norestart" -NoNewWindow -Wait
}

Out-Console -Message "Installing KDiff3"
if (!(Confirm-Kdiff))
{
  Start-Process -FilePath "$Kdiff3FolderPath\KDiff3-64bit-Setup_0.9.98-2.exe" -ArgumentList "/S" -NoNewWindow -Wait
}

Out-Console -Message "Configuring git with KDiff3"
# See if the config already exists because you can actually put multiple entries in the config, might not be an issue but I don't like it
# Going to assume if merge.tool does not exist neither does the other
if (!(Confirm-GitConfig -Command "merge.tool"))
{
  Start-Process -FilePath "C:\Program Files\Git\bin\git.exe" -ArgumentList "config --global merge.tool kdiff3" -WindowStyle Minimized -Wait
  Start-Process -FilePath "C:\Program Files\Git\bin\git.exe" -ArgumentList "config --global mergetool.kdiff3.path C:\Progra~1\KDiff3\kdiff3.exe" -WindowStyle Minimized -Wait
}

Write-Host "*** You may need to open SQL Server Management Studio (SSMS) with Admin Rights if you get a logon error ***`n" -BackgroundColor Black -ForegroundColor Cyan