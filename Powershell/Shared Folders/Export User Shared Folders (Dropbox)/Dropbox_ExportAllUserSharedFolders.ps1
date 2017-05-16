# Exports user's (including external collaborators) shared folder permissions from Dropbox into csv format file.

# To use: Update $token with team member file access token

# Uses Dropbox .NET SDK, standard .NET library included
# Update the script location below as well as the token
# Author: jackb@dropbox.com
# Date: 5/16/2017

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
$docTitle =  "{0:yyyy-MM-dd HH.mm.ss}" -f (Get-Date)
$logfile = $ScriptLocation + "Logs\scriptlog.txt"
$memberIdFile = $ScriptLocation + "CSVFiles\UserSharedFolderPermissions-" + $docTitle + ".csv"
$external = "External Collaborator"
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
    #create CSV file and write out headers first
    $createCsvFile = New-Item $memberIdFile -type file -force
    [void] $createCsvFile
    $outstring = "Email,Id,SharedFolderName,SharedFolderId,AccessType,IsTeamFolder,TeamFolderStatus,IsInsideTeamFolder"
    $outstring | Out-File -FilePath $memberIdFile -Encoding utf8 -Append

    GetLogger "Pulling members information..." $true

    #get first set of memberId's
    $teamClient = New-Object DropboxTeamClient($token)
    $members = $teamClient.Team.MembersListAsync().Result
    $memberinfo = $members.Members
    $hasMore = $members.HasMore
    $cursor = $members.Cursor

    $client = New-Object DropboxClient($token)

    GetLogger "Building team folder list..." $true

    #get team folder list
    $teamFolders = $teamClient.Team.TeamFolderListAsync(1000).Result
    $teamFoldersInfo = $teamFolders.TeamFolders

    foreach ($member in $memberinfo)
    {
        $email = $member.Profile.Email
        $memberId = $member.Profile.TeamMemberId 

        GetLogger "Getting shared folders for [$email]..." $true

        #now get shared folders they have access to
        #$sharingFoldersArgs = New-Object Sharing.ListFoldersArgs

        $sharedFolders = $teamClient.AsMember($memberId).Sharing.ListFoldersAsync(1000, $null).Result
        $sharedFoldersInfo = $sharedFolders.Entries

        foreach ($sharedFolderInfo in $sharedFoldersInfo)
        {
            $name = $sharedFolderInfo.Name
            $sharedFolderId = $sharedFolderInfo.SharedFolderId
            $access = $sharedFolderInfo.AccessType
            $isTeamFolder = $sharedFolderInfo.IsTeamFolder
            $isInsideTeamFolder = $sharedFolderInfo.IsInsideTeamFolder
            $accessType = "Unknown"
            $teamFolderStatus = $null
            
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
            if ($access.AsViewerNoComment)
            {
                $accessType = "Viewer No Comment"
            }

            #get team folder folder status if a team folder
            foreach ($teamFolderInfo in $teamFoldersInfo)
            {
                $teamFolderId = $teamFolderInfo.TeamFolderId
                if ($sharedFolderId -eq $teamFolderId)
                {
                    $status = $teamFolderInfo.Status
                    if ($status.AsActive)
                    {
                        $teamFolderStatus = "Active"
                        $accessType = $null
                    }
                    if ($status.AsArchived)
                    {
                        $teamFolderStatus = "Archived"
                        $accessType = $null
                    }
                    if ($status.AsArchiveInProgress)
                    {
                        $teamFolderStatus = "Archive In Progress"
                        $accessType = $null
                    }
                    if ($status.AsOther)
                    {
                        $teamFolderStatus = "Other"
                        $accessType = $null
                    }
                }
            }
            $outstring = "$email,$memberId,$name,$sharedFolderId,$accessType,$isTeamFolder,$teamFolderStatus,$isInsideTeamFolder"
            $outstring | Out-File -FilePath $memberIdFile -Encoding utf8 -Append
            $count++
        }
    }
    #if a continuation token, keep grabbing and writing them to file
    while ($hasMore)
    {
        GetLogger "Pulling next member continuation list..." $true

        $membersCont = $teamClient.Team.MembersListContinueAsync($cursor).Result
        $memberinfo = $membersCont.Members
        $cursor = $membersCont.Cursor
        $hasMore = $membersCont.HasMore 

        foreach ($member in $memberinfo)
        {
            $email = $member.Profile.Email
            $memberId = $member.Profile.TeamMemberId 

            GetLogger "Getting shared folders for [$email]-----" $true

            #now get shared folders they have access to
            $sharedFolders = $teamClient.AsMember($memberId).Sharing.ListFoldersAsync(1000, $null).Result
            $sharedFoldersInfo = $sharedFolders.Entries

            foreach ($sharedFolderInfo in $sharedFoldersInfo)
            {
                $name = $sharedFolderInfo.Name
                $sharedFolderId = $sharedFolderInfo.SharedFolderId
                $access = $sharedFolderInfo.AccessType
                $isTeamFolder = $sharedFolderInfo.IsTeamFolder
                $isInsideTeamFolder = $sharedFolderInfo.IsInsideTeamFolder
                $accessType = "Unknown"
                $teamFolderStatus = $null

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
                if ($access.AsViewerNoComment)
                {
                    $accessType = "Viewer No Comment"
                }

                #get team folder folder status if a team folder
                foreach ($teamFolderInfo in $teamFoldersInfo)
                {
                    $teamFolderId = $teamFolderInfo.TeamFolderId

                    if ($sharedFolderId -eq $teamFolderId)
                    {
                        $status = $teamFolderInfo.Status
                        if ($status.AsActive)
                        {
                            $teamFolderStatus = "Active"
                            $accessType = $null
                        }
                        if ($status.AsArchived)
                        {
                            $teamFolderStatus = "Archived"
                            $accessType = $null
                        }
                        if ($status.AsArchiveInProgress)
                        {
                            $teamFolderStatus = "Archive In Progress"
                            $accessType = $null
                        }
                        if ($status.AsOther)
                        {
                            $teamFolderStatus = "Other"
                            $accessType = $null
                        }
                    }
                }
                $outstring = "$email,$memberId,$name,$sharedFolderId,$accessType,$isTeamFolder,$teamFolderStatus,$isInsideTeamFolder"
                $outstring | Out-File -FilePath $memberIdFile -Encoding utf8 -Append
                $count++
            }
        }
    }

    #now to build new csv file with unique list of shared folders
    GetLogger "Importing list of unique shared folder ids from CSV file..." $true

    #import shared folder list from members list already written out
    $sharedFolders = Import-Csv $memberIdFile | sort SharedFolderId -Unique

    GetLogger "Getting list of external collaborators users from shared folder list..." $true

    foreach ($sharedFolder in $sharedFolders)
    {
        $sharedFolderId = $sharedFolder.SharedFolderId
        $memberId = $sharedFolder.Id
        $name = $sharedFolder.SharedFolderName
        $isTeamFolder = $sharedFolder.IsTeamFolder
        $isInsideTeamFolder = $sharedFolder.IsInsideTeamFolder
  
        $sharedFolderMembers = $teamClient.AsMember($memberId).Sharing.ListFolderMembersAsync($sharedFolderId, $null, 1000).Result
        $sharedFolderInfo = $sharedFolderMembers.Users

        foreach ($sharedUserInfo in $sharedFolderInfo)
        {
            $accountId = $sharedUserInfo.User.AccountId
            $teamMemberId = $sharedUserInfo.User.TeamMemberId
            $sameTeam = $sharedUserInfo.User.SameTeam

            $user = $teamClient.AsMember($memberId).Users.GetAccountAsync($accountId).Result 
            $email = $user.Email

            if ($teamMemberId -eq $null)
            {
                $outstring = "$email,$accountId,$name,$sharedFolderId,$external,$isTeamFolder,$teamFolderStatus,$isInsideTeamFolder"
                $outstring | Out-File -FilePath $memberIdFile -Encoding utf8 -Append
                $count++
            }
        }
    }
}
catch
{
    $errorMessage = $_.Exception.Message
    GetLogger "***Error during group script process,  Exception: [$errorMessage]***" $true
}
GetLogger "-----Completed. Total user permissions exported: [$count]-----" $true