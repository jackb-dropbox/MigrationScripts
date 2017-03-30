# Creates Groups and Group members import scripts for Dropbox from Box exported group member script.
# Group script: Outputs 2 columns, group name and "user_managed". If company_managed will have to be changed manually
# Group members script: Outputs 3 columns, groupname, groupid, memberemail for each group emember.
# when complete, scripts are ready to be imported to Admin Toolkit, running groups script first, then the group member script

# Variables to change
# ===================
# Change $boxGroupScript path to the CSV file you exported from Box, and add your Dropbox team access token

# Uses Dropbox .NET SDK, standard .NET library included
# Update the script location below as well as the token
# Uses Powershell 5.0. If not on this version you can update your system at: 
# https://www.microsoft.com/en-us/download/details.aspx?id=50395

# Author: jackb@dropbox.com
# Date: 3/30/2017

using namespace Dropbox.Api

####################
#Variables to update
####################
$ScriptLocation = “C:\Scripts\"
$boxGroupMemberScript = "C:\Scripts\boxGroups.csv"

#Needs provision token to complete
$token = "DROPBOX TEAM ACCESS TOKEN"

########################
#Variables to NOT change
########################
$scriptName = "Create Groups and Group Members Import Scripts for Dropbox Admin Toolkit"
$docTitle =  "{0:yyyy-MM-dd HH.mm.ss}" -f (Get-Date)

$userManaged = "user_managed"
$logfile = $ScriptLocation + "Logs\scriptlog.txt"
$dropboxGroupMemberScript = $ScriptLocation + "CSVFiles\DropboxGroupMembersImport-" + $docTitle + ".csv"
$dropboxGroupScript = $ScriptLocation + "CSVFiles\DropboxGroupsImport-" + $docTitle + ".csv"
$count = 0

[void][Reflection.Assembly]::LoadFile($ScriptLocation + "Dlls\Dropbox.Api.dll”)
[void][Reflection.Assembly]::LoadFile($ScriptLocation + "Dlls\Newtonsoft.Json.dll”)

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

try
{
    GetLogger "Creating file for Group script..." $true

    $createCsvFile2 = New-Item $dropboxGroupScript -type file -force
    [void] $createCsvFile2

    GetLogger "Importing list of Box group names and group members from CSV file..." $true

    #import groups list from Box script
    $boxGroups = Import-Csv $boxGroupMemberScript 
    #get unique list for groups script
    $uniqueBoxGroups = Import-Csv $boxGroupMemberScript | sort GroupName -Unique

    GetLogger "Creating script entries for unique Box groups..." $true

    foreach ($boxGroup in $uniqueBoxGroups)
    {
        $boxGroupName = $boxGroup.GroupName
        $outstring = "$boxGroupName,$userManaged"
        $outstring | Out-File -FilePath $dropboxGroupScript -Encoding utf8 -Append
    }

    #create our client to use
    $client = New-Object DropboxTeamClient($token)

    GetLogger "Creating CSV file and headers for Group Member script..." $true

    #create CSV file first for group member script
    $createCsvFile = New-Item $dropboxGroupMemberScript -type file -force
    [void] $createCsvFile  

    GetLogger "Gathering Dropbox groups for group Id information..." $true

    $groups = $client.Team.GroupsListAsync(1000).Result
    $groupsInfo = $groups.Groups
   
    GetLogger "Creating script entries for group members..." $true

    foreach ($group in $boxGroups)
    {
        $groupName = $group.GroupName
        $memberEmail = $group.MemberEmail

        foreach ($dropboxGroup in $groupsInfo)
        {
            if ($groupName -eq $dropboxGroup.GroupName)
            {
                $groupId = $dropboxGroup.GroupId
                $outstring = "$groupName,$groupId,$memberEmail"
                $outstring | Out-File -FilePath $dropboxGroupMemberScript -Encoding utf8 -Append
            }
        } 
    }
}
catch
{
    $errorMessage = $_.Exception.Message
    GetLogger "***Error during group script process,  Exception: [$errorMessage]***" $true
}

GetLogger "Group Output Script Location [$dropboxGroupScript]-----" $true
GetLogger "Group Member Output Script Location [$dropboxGroupMemberScript]-----" $true
GetLogger "-----Script completed.-----" $true

