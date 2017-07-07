# Bulk creates team folders in Dropbox Business. Edit the csv file (located in <SCRIPTDIR>\CSVFiles\teamFolders.csv
# with 1 column header of: TeamFolderName

# Example:

# TeamFolderName
# TeamFolder1
# TeamFolder2

# Uses Dropbox .NET SDK, standard .NET library included
# Update the script location below as well as the token
# Uses Powershell 5.0..if not on this you can update your system at: 
# https://www.microsoft.com/en-us/download/details.aspx?id=50395
# Author: jackb@dropbox.com
# Date: 3/9/2017

using namespace Dropbox.Api

####################
#Variables to update
####################
$ScriptLocation = "C:\Scripts\"

#Needs team member access token to complete
$token = "ENTER TEAM MEMBER FILE ACCESS TOKEN HERE"

########################
#Variables to NOT change
########################
$scriptName = "Bulk Create Team Folders in Dropbox"
$logfile = $ScriptLocation + "Logs\scriptlog.txt"
$teamFolderFile = $ScriptLocation + "teamFolders.csv"
$count = 0

[void][Reflection.Assembly]::LoadFile($ScriptLocation + "Dlls\Dropbox.Api.dll")
[void][Reflection.Assembly]::LoadFile($ScriptLocation + "Dlls\Newtonsoft.Json.dll")

##################
#Script Functions
##################
function CreateLogFile
{  
    $createLogFile = New-Item $logfile -type file -force
    [void] $createLogFile
}
function GetLogger($log, [bool]$output)
{
    $timestamp = Get-Date -format G
    $logString = "[$timestamp] $log"
    $logString | Out-File -FilePath $logfile -Append
    if ($output -eq $true)
    {
        Write-Output $logstring
    }
}

###############
# SCRIPT BEGIN
###############
CreateLogFile

GetLogger "-----Beginning script: [$scriptName]-----" $true
GetLogger "-----Parameters: [LogFile]: $logfile [Script Location]: $ScriptLocation-----" $true

GetLogger "-----Bulk creating list of team folder names from CSV file-----" $true

try
{
    #import team folders list
    $teamFolders = Import-Csv $teamFolderFile

    #create our client to use
    $client = New-Object DropboxTeamClient($token)
    
    foreach ($teamFolder in $teamFolders)
    {
        $teamFolderName = $teamFolder.TeamFolderName
        $create = $client.Team.TeamFolderCreateAsync($teamFolderName)    
        $count++
    }
}
catch
  {
    $errorMessage = $_.Exception.Message
    GetLogger "***Error during team folder creation process,  Exception: [$errorMessage]***" $true
  }
GetLogger "-----Completed. Total team folders created: [$count]-----" $true

