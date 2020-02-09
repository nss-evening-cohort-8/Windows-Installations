#========================================================================
# Created on:   02/21/2019 (MM/DD/YYYY)
# Created by:   Marco Crank
# Organization: Nashville Software School
# Filename:     Install-EveBackendReqs.ps1
# Version:      3.0
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
#               3.0 - (02/08/2020) Updated dotnet (3.1), Updated SQL 2019 Dev, Remove KDiff
#                     Added file hash matching to prevent re-download of files
#========================================================================

#requires -RunAsAdministrator

Clear-Host

# Constants
# Path Variables need to end in FolderPath as I am reading them in to create the Folder Hierarchy in the

# *** Root Folder ***
$RootFolderPath = 'C:\Nss_Install'

# *** SSMS ***
$SsmsRequiredVersion = '15.0.18206.0' # SSMS 18 RTM (https://sqlserverbuilds.blogspot.com/2018/01/sql-server-management-studio-ssms.html)
$SsmsFolderPath = "$RootFolderPath\SSMS"
$SsmsInstallerHash = '5A0BCF1665C56B4EE839361CD1AB44AB7864A9361BC60C508B0100D00E58A5E2' # SHA256
$SsmsUrl = 'https://download.microsoft.com/download/1/9/4/1949aa9c-6536-48f2-81fa-e7bb07410b36/SSMS-Setup-ENU.exe'
$SsmsExecutable = ([uri]$SsmsUrl | Select-Object -ExpandProperty Segments)[([uri]$SsmsUrl | Select-Object -ExpandProperty Segments).length - 1]

# *** SQL Developer Edition ***
$SqlRequiredVersion = '15.0.2000.5' # SQL 2019 RTM (http://sqlserverbuilds.blogspot.com/)
$SqlFolderPath = "$RootFolderPath\SQL"
$SqlInstallerHash = 'FB67DB0057C0229F3A13AFCE79FA12F0926C644F8525AA27922FF53FA0305F6F' # SHA256
$SqlUrl = 'https://download.microsoft.com/download/b/8/c/b8ce1000-2e0b-4bc8-b4e4-646e9a439525/SQL2019-SSEI-Dev.exe'
$SqlExecutable = ([uri]$SqlUrl | Select-Object -ExpandProperty Segments)[([uri]$SqlUrl | Select-Object -ExpandProperty Segments).length - 1]
$SqlConfigUrl = 'https://bit.ly/2GTSp36'

# *** VS Community Edition 2019 ***
$VsFolderPath = "$RootFolderPath\VS" # vs_community.exe
$VsInstallerHash = '9BE9BFB28D3A96554915A4BEDF5FE733BC4C832B1079F3C884E138AFD21DD118' # SHA256
$VsCommunityUrl = 'https://download.visualstudio.microsoft.com/download/pr/818029a2-ea31-4a6a-8bed-f50abbaf9716/ff2d0f080b97ad9de29126e301f93a26/vs_community.exe'
$VsExecutable = ([uri]$VsCommunityUrl | Select-Object -ExpandProperty Segments)[([uri]$VsCommunityUrl | Select-Object -ExpandProperty Segments).length - 1]

# *** .Net Core 3.1.101 SDK
# Hardcoding to this version as it is the latest.  No easy way to just get the latest because Microsoft is stupid with the versioning of .net core now
#   and grabbing the release from Github...Well yeah all the links are in markdown files so this is what you get
$DotNetFolderPath = "$RootFolderPath\DotNetCore"
$DotNetHash = "eec02a5434de65b36b481136db06cd10eba4ca5c4947b536d567b003a8cac4f29012b74ad131a1e0dd4a79611702aa660f57949f0761259d1050d2481e4929cd" # SHA512
$DotNetUrl = 'https://download.visualstudio.microsoft.com/download/pr/854ca330-4414-4141-9be8-5da3c4be8d04/3792eafd60099b3050313f2edfd31805/dotnet-sdk-3.1.101-win-x64.exe'
$DotNetExecutableName = ([uri]$DotNetUrl | Select-Object -ExpandProperty Segments)[([uri]$DotNetUrl | Select-Object -ExpandProperty Segments).length - 1]

# *** Git ***
# Git is a bit different since they have version in the name.  Let's grab the latest from the API
$LatestGitFerWindersRelease = (Invoke-WebRequest 'https://api.github.com/repos/git-for-windows/git/releases/latest' -UseBasicParsing -Headers @{"Accept" = "application/json" }).Content | ConvertFrom-Json
$GitDownloadUrl = ($LatestGitFerWindersRelease.assets | Where-Object { $_.Name -like "Git-*-64-bit.exe" }).browser_download_url
$GitName = ($LatestGitFerWindersRelease.assets | Where-Object { $_.Name -like "Git-*-64-bit.exe" }).name
$GitHashStartIndex = $LatestGitFerWindersRelease.body.IndexOf($GitName)
$GitHash = $LatestGitFerWindersRelease.body.Substring($GitHashStartIndex, ($LatestGitFerWindersRelease.body.IndexOf("`n", $GitHashStartIndex) - $GitHashStartIndex)).split("|").trim()[1]
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
    $null = New-Item -Path $Path -ItemType Directory -Force
  }
}

function Confirm-VisualStudio ()
{
  if (Get-Package -Name "Visual Studio Community 2019" -ProviderName Programs -ErrorAction SilentlyContinue)
  {
    Out-Console -Message "`t- Visual Studio Already Installed" -Mode Check
    return $true
  }
  else
  {
    if (!(Compare-Checksum -SourceHash $VsInstallerHash -TargetPath "$VsFolderPath\$VsExecutable" -Algorithm SHA256))
    {
      Out-Console -Message "`t- Visual Studio not installed. Downloading and Installing. Please Wait..." -Mode Check
      Start-BitsTransfer -Source $VsCommunityUrl -Destination $VsFolderPath
    }
    else
    {
      Out-Console -Message "`t- Visual Studio Installer found locally. Installing..." -Mode Check

    }
    return $false
  }
}

function Confirm-DotnetCore
{
  $DotNetVersion = $DotNetExecutableName -match "\d+(\.\d+)+" | ForEach-Object { $Matches[0] }
  if (Get-Package -ProviderName Programs -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*Microsoft .NET Core SDK*" -and $_.Version -ge $DotNetVersion })
  {
    Out-Console -Message "`t- Required .Net Core SDK Already Installed" -Mode Check
    return $true
  }
  else
  {
    if (!(Compare-Checksum -SourceHash $DotNetHash -TargetPath "$DotNetFolderPath\$DotNetExecutableName" -Algorithm SHA512))
    {
      Out-Console -Message "`t- Required .Net Core SDK not found. Downloading Installation..." -Mode Check
      Start-BitsTransfer -Source $DotNetUrl -Destination $DotNetFolderPath
    }
    else
    {
      Out-Console -Message "`t- DotNet Core installer found locally. Installing..." -Mode Check
    }
    return $false
  }
}

function Confirm-SqlInstall ()
{
  $SqlInstances = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server' -ErrorAction SilentlyContinue).InstalledInstances
  if (!($SqlInstances -contains "MSSQLSERVER"))
  {
    if (!(Compare-Checksum -SourceHash $SqlInstallerHash -TargetPath "$SqlFolderPath\$SqlExecutable" -Algorithm SHA256))
    {
      # Default instance not found so
      Out-Console -Message "`t- SQL 2019 Instance not found. Downloading Installation..." -Mode Check
      Start-BitsTransfer -Source $SqlConfigUrl -Destination "$SqlFolderPath\ConfigurationFile.ini"
    }
    else
    {
      Out-Console -Message "`t- SQL Server Installer found locally.  Installing..." -Mode Check
    }
    # Grabbing the config file no matter what
    Start-BitsTransfer -Source $SqlUrl -Destination $SqlFolderPath
    return $false
  }
  else
  {
    # Found a SQL install.  Check if it is at least the version we need based on $SqlRequiredVersion
    $SqlDefaultInstance = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL').MSSQLSERVER
    if ((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$SqlDefaultInstance\Setup").Version -ge $SqlRequiredVersion)
    {
      Out-Console -Message "`t- SQL Server Already Installed" -Mode Check
      return $true
    }
    else
    {
      # Found a default instance but it is lower version than SQL 2019.  Manual upgrade
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
    Out-Console -Message "`t- SSMS Already Installed" -Mode Check
    return $true
  }
  else
  {
    if (!(Compare-Checksum -SourceHash $SsmsInstallerHash -TargetPath "$SsmsFolderPath\$SsmsExecutable" -Algorithm SHA256))
    {
      Out-Console -Message "`t- SSMS version not met. Downloading Installation" -Mode Check
      Start-BitsTransfer -Source $SsmsUrl -Destination $SsmsFolderPath
    }
    else
    {
      Out-Console -Message "`t- SSMS Installater found locally.  Installing..." -Mode Check
    }
    return $false
  }
}

function Confirm-Git ()
{
  if (Get-Package -Name *git* -ProviderName Programs -ErrorAction SilentlyContinue)
  {
    Out-Console -Message "`t- Git for Windows already installed" -Mode Check
    return $true
  }
  else
  {
    if (!(Compare-Checksum -SourceHash $GitHash -TargetPath "$GitFolderPath\$GitName" -Algorithm SHA256))
    {
      Out-Console -Message "`t- Git not installed. Downloading" -Mode Check
      Start-Process bitsadmin.exe -ArgumentList " /transfer GitDownload /dynamic /priority FOREGROUND $GitDownloadUrl $GitFolderPath\$GitName" -WindowStyle Hidden -Wait
    }
    else
    {
      Out-Console -Message "`t- Git Installer found locally. Installing..." -Mode Check
    }
    # Grab the got config no matter what
    Invoke-WebRequest -Uri $GitConfigIniUrl -OutFile "$GitFolderPath\GitConfig.ini"
    return $false
  }
}

function Compare-Checksum ()
{
  Param(
    [string]$SourceHash,
    [string]$TargetPath,
    [string]$Algorithm
  )
  if (!(Test-Path -Path $TargetPath))
  {
    return $false
  }
  else
  {
    $TargetHash = (Get-FileHash -Path $TargetPath -Algorithm $Algorithm).Hash
    if ($SourceHash -eq $TargetHash)
    {
      return $true
    }
    else
    {
      return $false
    }
  }
}

Out-Console -Message "Setting Execution policy to Bypass"
Set-ExecutionPolicy Bypass -Scope Process -Force

# Check Operating System Architecture. Requires 64-Bit
Out-Console -Message "Checking Operating System Architecture"
$OSArchitecture = (Get-CimInstance -ClassName Win32_OperatingSystem).OSArchitecture
if ($OSArchitecture -ne "64-Bit")
{
  Out-Console -Message "This script requires you to be running 64-Bit Windows. NSS C# Backend requirements need to be manually installed" -Mode Error
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
# Check if git is installed, At this point it should be from Front End unless a fresh install
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
  Start-Process -FilePath "$VsFolderPath\$VsExecutable" -ArgumentList "--includeRecommended --quiet --add Microsoft.VisualStudio.Workload.ManagedDesktop --add Microsoft.VisualStudio.Workload.NetCoreTools --add Microsoft.VisualStudio.Workload.NetWeb --norestart" -NoNewWindow -Wait
}

Out-Console -Message "Installing .Net Core SDK"
if (!(Confirm-DotnetCore))
{
  Start-Process -FilePath "$DotNetFolderPath\$DotNetExecutableName" -ArgumentList "/quiet /norestart /log $DotNetFolderPath\dotnet_install.txt" -NoNewWindow -Wait
}

Out-Console -Message "Downloading SQL Server 2019 Developer Edition Bootstrap files"
if (!(Confirm-SqlInstall))
{
  Start-Process -FilePath "$SqlFolderPath\$SqlExecutable" -ArgumentList "/ACTION=Install /CONFIGURATIONFILE=$SqlFolderPath\ConfigurationFile.ini /IACCEPTSQLSERVERLICENSETERMS /MEDIAPATH=$SqlFolderPath /QUIET" -NoNewWindow -Wait
}

Out-Console -Message "Installing SQL Server Management Studio (SSMS)"
if (!(Confirm-SSMS))
{
  Start-Process -FilePath "$SsmsFolderPath\$SsmsExecutable" -ArgumentList "/install /quiet /norestart" -NoNewWindow -Wait
}

Write-Host "*** You may need to open SQL Server Management Studio (SSMS) with Admin Rights if you get a logon error ***`n" -BackgroundColor Black -ForegroundColor Cyan