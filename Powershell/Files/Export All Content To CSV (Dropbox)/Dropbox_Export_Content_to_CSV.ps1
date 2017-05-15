#Export file and folder content in Dropbox to CSV file

#To use: Update $token with Dropbox Business team member file access token

# Uses Dropbox .NET SDK, standard .NET library included
# Update the script location below as well as the token
# Uses Powershell 5.0..if not on this you can update your system at: 
# https://www.microsoft.com/en-us/download/details.aspx?id=50395
# Author: jackb@dropbox.com
# Date: 5/15/2017

using namespace Dropbox.Api

####################
#Variables to update
####################
$ScriptLocation = “C:\Scripts\"

#Needs team member management token for script
$token = "ENTER TEAM MEMBER FILE ACCESS TOKEN HERE"

########################
#Variables to NOT change
########################
$scriptName = "Export file and folder contents to CSV"
$docTitle =  "{0:yyyy-MM-dd HH.mm.ss}" -f (Get-Date)
$logfile = $ScriptLocation + "Logs\scriptlog.txt"
$contentFile = $ScriptLocation + "CSVFiles\content-" + $docTitle + ".csv"
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
# Functions
###############
function ExportContent()
{
    try
    {
        #create CSV file and write out headers first
        $createCsvFile = New-Item $contentFile -type file -force
        [void] $createCsvFile
        $outstring = "Email,Name,Type,Path,Size"
        $outstring | Out-File -FilePath $contentFile -Encoding utf8 -Append

        #create our client to use
        $teamClient = New-Object DropboxTeamClient($token)

        #get list of Dropbox members to export content for
        $members = $teamClient.Team.MembersListAsync().Result
        $memberinfo = $members.Members
        $hasMore = $members.HasMore
        $cursor = $members.Cursor

        foreach ($member in $memberinfo)
        {
            $email = $member.Profile.Email
            $memberId = $member.Profile.TeamMemberId 

            $listFolderArg = New-Object Files.ListFolderArg("", $true)
            $content = $teamClient.AsMember($memberId).Files.ListFolderAsync($listFolderArg).Result
            $contentEntries = $content.Entries
            $contentEntriesCount = $contentEntries.Count
        
            $hasMoreContent = $content.HasMore
            $cursorContent = $content.Cursor
            
            GetLogger "Exporting content for [$email]" $true

            For ($i=0; $i -le $contentEntriesCount; $i++) 
            {
                $name = $contentEntries[$i].Name
                if ($contentEntries[$i].IsFolder)
                {
                    $type = "Folder"
                    $pathDisplay = $contentEntries[$i].PathDisplay
                    $size = "0"
                    $pathLower = $contentEntries[$i].PathLower

                    $outstring = "$email,$name,$type,$pathLower,$size"
                    $outstring | Out-File -FilePath $contentFile -Encoding utf8 -Append
                    $count++
                }
                if ($contentEntries[$i].IsFile)
                {
                    $type = "File"
                    $pathDisplay = $contentEntries[$i].PathDisplay
                    $pathLower = $contentEntries[$i].PathLower
                    $size = $contentEntries[$i].AsFile.Size

                    $outstring = "$email,$name,$type,$pathLower,$size"
                    $outstring | Out-File -FilePath $contentFile -Encoding utf8 -Append
                    $count++
                }
            }
            while ($hasMoreContent)
            {
                $contentCont = $teamClient.AsMember($memberId).Files.ListFolderContinueAsync($cursorContent).Result
                $contentEntries = $contentCont.Entries
                $contentEntriesCount = $contentEntries.Count
        
                $hasMoreContent = $contentCont.HasMore
                $cursorContent = $contentCont.Cursor

                For ($i=0; $i -le $contentEntriesCount; $i++) 
                {
                    $name = $contentEntries[$i].Name
                    if ($contentEntries[$i].IsFolder)
                    {
                        $type = "Folder"
                        $pathDisplay = $contentEntries[$i].PathDisplay
                        $size = "0"
                        $pathLower = $contentEntries[$i].PathLower

                        $outstring = "$email,$name,$type,$pathLower,$size"
                        $outstring | Out-File -FilePath $contentFile -Encoding utf8 -Append
                        $count++
                    }
                    if ($contentEntries[$i].IsFile)
                    {
                        $type = "File"
                        $pathDisplay = $contentEntries[$i].PathDisplay
                        $pathLower = $contentEntries[$i].PathLower
                        $size = $contentEntries[$i].AsFile.Size

                        $outstring = "$email,$name,$type,$pathLower,$size"
                        $outstring | Out-File -FilePath $contentFile -Encoding utf8 -Append
                        $count++
                    }
                }
            }
      }
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

            $content = $teamClient.AsMember($memberId).Files.ListFolderAsync($listFolderArg).Result
            $contentEntries = $content.Entries
            $contentEntriesCount = $contentEntries.Count
        
            For ($i=0; $i -le $contentEntriesCount; $i++) 
            {
                $name = $contentEntries[$i].Name
                if ($contentEntries[$i].IsFolder)
                {
                    $type = "Folder"
                    $pathDisplay = $contentEntries[$i].PathDisplay
                    $size = "0"
                    $pathLower = $contentEntries[$i].PathLower

                    $outstring = "$email,$name,$type,$pathLower,$size"
                    $outstring | Out-File -FilePath $contentFile -Encoding utf8 -Append
                    $count++
                 
                 }
                 if ($contentEntries[$i].IsFile)
                 {
                    $type = "File"
                    $pathDisplay = $contentEntries[$i].PathDisplay
                    $pathLower = $contentEntries[$i].PathLower
                    $size = $contentEntries[$i].AsFile.Size

                    $outstring = "$email,$name,$type,$pathLower,$size"
                    $outstring | Out-File -FilePath $contentFile -Encoding utf8 -Append
                    $count++
                 }
             }
        }
        while ($hasMoreContent)
        {
            $contentCont = $teamClient.AsMember($memberId).Files.ListFolderContinueAsync($cursorContent).Result
            $contentEntries = $contentCont.Entries
            $contentEntriesCount = $contentEntries.Count
        
            $hasMoreContent = $contentCont.HasMore
            $cursorContent = $contentCont.Cursor

            For ($i=0; $i -le $contentEntriesCount; $i++) 
            {
                $name = $contentEntries[$i].Name
                if ($contentEntries[$i].IsFolder)
                {
                    $type = "Folder"
                    $pathDisplay = $contentEntries[$i].PathDisplay
                    $size = "0"
                    $pathLower = $contentEntries[$i].PathLower

                    $outstring = "$email,$name,$type,$pathLower,$size"
                    $outstring | Out-File -FilePath $contentFile -Encoding utf8 -Append
                    $count++
                }
                if ($contentEntries[$i].IsFile)
                {
                    $type = "File"
                    $pathDisplay = $contentEntries[$i].PathDisplay
                    $pathLower = $contentEntries[$i].PathLower
                    $size = $contentEntries[$i].AsFile.Size

                    $outstring = "$email,$name,$type,$pathLower,$size"
                    $outstring | Out-File -FilePath $contentFile -Encoding utf8 -Append
                    $count++
                }
            }
        }
     }  
     GetLogger "-----Completed. Items exported [$count]-----" $true
    }
    catch
    {
        $errorMessage = $_.Exception.Message
        GetLogger "***Error during content extraction,  Exception: [$errorMessage]***" $true
    }
}

###############
# SCRIPT BEGIN
###############
CreateLogFile

GetLogger "-----Beginning script: [$scriptName]-----" $true
GetLogger "-----Parameters: LogFile: [$logfile] Script Location: [$ScriptLocation]-----" $true

GetLogger "-----Exporting content list from Dropbox to file: [$contentFile]-----" $true

ExportContent

