#========================================================================
# Created on:		02/21/2019 (MM/DD/YYYY)
# Created by:		Marco Crank
# Organization:	Nashville Software School
# Filename:			Install-EveBackendReqs.ps1
# Version:			Version
# Disclaimer:		THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF
#								ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO
#								THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
#								PARTICULAR PURPOSE.
#
#								IN NO EVENT SHALL "Nashville Software School" AND/OR ITS RESPECTIVE SUPPLIERS
#								BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY
#								DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS
#								WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS
#								ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
#								OF THIS CODE OR INFORMATION.
#
#
# What it Do:		Downloads and installs the necessary tools for the Evening Back End
#               class on Windows devices.
#
# Updates:			1.0 - Initial Release
#========================================================================

#requires -RunAsAdministrator

Clear-Host

# Constats
# Path Variables need to end in FolderPath

# *** Root Folder ***
$RootFolderPath = 'C:\Nss_Install'

# *** SSMS ***
$SsmsRequiredVersion = '14.0.17099.0' # SSMS 17 RTM (https://sqlserverbuilds.blogspot.com/2018/01/sql-server-management-studio-ssms.html)
$SsmsFolderPath = "$RootFolderPath\SSMS" #SSMS-Setup-ENU.exe
$SsmsUrl = 'https://go.microsoft.com/fwlink/?linkid=2043154'

# *** SQL Developer Edition ***
$SqlRequiredVersion = '14.0.1000.169' # SQL 2017 RTM (http://sqlserverbuilds.blogspot.com/)
$SqlFolderPath = "$RootFolderPath\SQL" # SQLServer2017-SSEI-Dev.exe
$SqlUrl = 'https://go.microsoft.com/fwlink/?linkid=853016'
$SqlConfigUrl = 'https://bit.ly/2GTSp36'

# *** VS Community Edition ***
$VsFolderPath = "$RootFolderPath\VS" # vs_community.exe
$VsCommunityUrl = 'https://download.visualstudio.microsoft.com/download/pr/41217ce6-f73c-48b9-b679-e5193984336b/500a2965365fa0283c3c31e4837487d9/vs_community.exe'

# *** KDiff3 ***
# Hasn't been updated in many moons
$Kdiff3FolderPath = "$RootFolderPath\KDiff" #KDiff3-64bit-Setup_0.9.98-2.exe
$Kdiff3Url = 'https://svwh.dl.sourceforge.net/project/kdiff3/kdiff3/0.9.98/KDiff3-64bit-Setup_0.9.98-2.exe'

# *** Git ***
# Git is a bit different since they have version in the name.  Let's grab the latest form the API
$LatestGitFerWindersRelease = (Invoke-WebRequest 'https://api.github.com/repos/git-for-windows/git/releases/latest' -UseBasicParsing -Headers @{"Accept" = "application/json"}).Content | ConvertFrom-Json
$GitDownloadUrl = ($LatestGitFerWindersRelease.assets | Where-Object { $_.Name -like "Git-*-64-bit.exe"}).browser_download_url
$GitName = ($LatestGitFerWindersRelease.assets | Where-Object {$_.Name -like "Git-*-64-bit.exe"}).name
$GitConfigIniUrl = 'https://bit.ly/2EdhG5z'
$GitFolderPath = "$RootFolderPath\Git"

function Out-Console ()
{
  Param(
    [string]$Message,
    [ValidateSet('Info', 'Check')]
    [string]$Mode
  )
  switch ($Mode)
  {
    'Info' { $ForeColor = 'Green' }
    'Check' { $ForeColor = 'Yellow' }
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
  if (Get-Package -Name "Visual Studio Community 2017" -ProviderName Programs -ErrorAction SilentlyContinue)
  {
    Out-Console -Message "Visual Studio Already Installed" -Mode Check
    return $true
  }
  else
  {
    Start-BitsTransfer -Source $VsCommunityUrl -Destination "$VsFolderPath\vs_community.exe"
    return $false
  }

}

function Confirm-SqlInstall ()
{
  $SqlInstances = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server').InstalledInstances
  if (!($SqlInstances -contains "MSSQLSERVER"))
  {
    # Default instance not found so
    Start-BitsTransfer -Source $SqlConfigUrl -Destination "$SqlFolderPath\ConfigurationFile.ini"
    Start-BitsTransfer -Source $SqlUrl -Destination "$SqlFolderPath\SQLServer2017-SSEI-Dev.exe"
    return $false
  }
  else
  {
    $SqlDefaultInstance = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL').MSSQLSERVER
    if ((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$SqlDefaultInstance\Setup").Version -ge $SqlRequiredVersion)
    {
      Out-Console -Message "SQL Server Already Installed" -Mode Check
      return $true
    }
    else
    {
      # Found a default instance but it is lower version than SQL 2017.  Manual upgrade
      Write-Host "***** Older SQL server version found please upgrade manually ******" -BackgroundColor Black -ForegroundColor Red
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
    # Start-BitsTransfer -Source $GitDownloadUrl -Destination "$GitFolderPath\$GitName"
    Invoke-WebRequest -Uri $GitConfigIniUrl -OutFile "$GitFolderPath\GitConfig.ini"
    # Start-BitsTransfer -Source $GitConfigIniUrl -Destination "$GitFolderPath\GitConfig.ini"
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

# Check/Create our folders
Out-Console -Message "Creating Folder Hierarchy at: $RootFolderPath"
$FolderPaths = @($(Get-Variable | Where-Object {$_.Name -Like "*FolderPath"}))
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

Out-Console -Message "Installing Visual Studio 2017 Community"
if (!(Confirm-VisualStudio))
{
  Start-Process -FilePath "$VsFolderPath\vs_community.exe" -ArgumentList "--includeRecommended --quiet --add Microsoft.VisualStudio.Workload.ManagedDesktop --add Microsoft.VisualStudio.Workload.NetCoreTools --add Microsoft.VisualStudio.Workload.NetWeb --norestart" -NoNewWindow -Wait
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
  Start-Process -FilePath "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList "git config --global --add merge.tool kdiff3; git config --global --add mergetool.kdiff3.path 'C:/Program Files/KDiff3/kdiff3.exe'" -WindowStyle Minimized -Wait
}

Write-Host "*** You may need to open SQL Server Management Studio (SSMS) with Admin Rights if you get a logon error ***`n" -BackgroundColor Black -ForegroundColor Red