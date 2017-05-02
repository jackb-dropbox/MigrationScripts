# Exports user's shared folder permissions from Dropbox into csv format file.
# Uses Dropbox .NET SDK, standard .NET library included
# Update the script location below as well as the token
# Author: jackb@dropbox.com
# Date: 5/2/2017

using namespace Dropbox.Api

####################
#Variables to update
####################
$ScriptLocation = “C:\Scripts\"
$token = "ENTER TEAM MEMBER FILE ACCESS TOKEN HERE"

########################
#Variables to NOT change
########################
$scriptName = "Export Dropbox Member's Shared Folder Permissions to CSV File"
$logfile = $ScriptLocation + "Logs\scriptlog.txt"
$memberIdFile = $ScriptLocation + "CSVFiles\UserSharedFolderPermissions.csv"
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

#create CSV file and write out headers first
$createCsvFile = New-Item $memberIdFile -type file -force
[void] $createCsvFile
$outstring = "Email,MemberId,SharedFolderName,SharedFolderId"
$outstring | Out-File -FilePath $memberIdFile -Encoding utf8 -Append

GetLogger "-----Pulling members information-----" $true

#get first set of memberId's
$teamClient = New-Object DropboxTeamClient($token)
$members = $teamClient.Team.MembersListAsync().Result
$memberinfo = $members.Members
$hasMore = $members.HasMore
$cursor = $members.Cursor

$client = New-Object DropboxClient($token)

foreach ($member in $memberinfo)
{
    $email = $member.Profile.Email
    $memberId = $member.Profile.TeamMemberId 

    GetLogger "-----Getting shared folders for [$email]-----" $true

    #now get shared folders they have access to
    #$sharingFoldersArgs = New-Object Sharing.ListFoldersArgs

    $sharedFolders = $teamClient.AsMember($memberId).Sharing.ListFoldersAsync(1000, $null).Result
    $sharedFoldersInfo = $sharedFolders.Entries

    foreach ($sharedFolderInfo in $sharedFoldersInfo)
    {
        $name = $sharedFolderInfo.Name
        $sharedFolderId = $sharedFolderInfo.SharedFolderId
        $access = $sharedFolderInfo.AccessType
        $accessType = "Unknown"
        if ($access.AsOwner)
        {
            $accessType = "Owner"
        }
        if ($access.AsEditor)
        {
            $accessType = "Editor"
        }
        if ($access.AsViewer)
        {
            $accessType = "Viewer"
        }
        if ($access.AsOther)
        {
            $accessType = "Other"
        }
        $outstring = "$email,$memberId,$name,$sharedFolderId,$accessType"
        $outstring | Out-File -FilePath $memberIdFile -Encoding utf8 -Append
        $count++
    }
}
#if a continuation token, keep grabbing and writing them to file
while ($hasMore)
{
    $membersCont = $teamClient.Team.MembersListContinueAsync($cursor).Result
    $memberinfo = $membersCont.Members
    $cursor = $membersCont.Cursor
    $hasMore = $membersCont.HasMore 

    foreach ($member in $memberinfo)
    {
        $email = $member.Profile.Email
        $memberId = $member.Profile.TeamMemberId 

        GetLogger "-----Getting shared folders for [$email]-----" $true

        #now get shared folders they have access to
        $sharedFolders = $teamClient.AsMember($memberId).Sharing.ListFoldersAsync(1000, $null).Result
        $sharedFoldersInfo = $sharedFolders.Entries

        foreach ($sharedFolderInfo in $sharedFoldersInfo)
        {
            $name = $sharedFolderInfo.Name
            $sharedFolderId = $sharedFolderInfo.SharedFolderId
            $access = $sharedFolderInfo.AccessType
            $accessType = "Unknown"
            if ($access.AsOwner)
            {
                $accessType = "Owner"
            }
            if ($access.AsEditor)
            {
                $accessType = "Editor"
            }
            if ($access.AsViewer)
            {
                $accessType = "Viewer"
            }
            if ($access.AsOther)
            {
                $accessType = "Other"
            }
            $outstring = "$email,$memberId,$name,$sharedFolderId,$accessType"
            $outstring | Out-File -FilePath $memberIdFile -Encoding utf8 -Append
            $count++
        }
    }
}
GetLogger "-----Completed. Total user permissions exported: [$count]-----" $true