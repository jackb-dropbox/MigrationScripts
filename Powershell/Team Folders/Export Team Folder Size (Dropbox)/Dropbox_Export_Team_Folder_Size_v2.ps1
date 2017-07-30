# Export team folder size content (in MB) in Dropbox to CSV file

# To use: Update $token with Dropbox Business team member file access token
# as well as the member Id of an admin on your DfB account

# Uses Dropbox .NET SDK, standard .NET library included
# Update the script location below as well as the token
# Uses Powershell 5.0..if not on this you can update your system at: 
# https://www.microsoft.com/en-us/download/details.aspx?id=50395
# Author: jackb@dropbox.com
# Date: 7/27/2017

using namespace Dropbox.Api

####################
#Variables to update
####################
$ScriptLocation = "C:\Scripts\"

#Needs team member management token for script, as well as admin memberId
$token = "ENTER TEAM MEMBER FILE ACCESS TOKEN HERE"
$adminId = "ENTER DFB ADMIN MEMBERID HERE"

########################
#Variables to NOT change
########################
$scriptName = "Export Team Folder Size To CSV"
$docTitle =  "{0:yyyy-MM-dd HH.mm.ss}" -f (Get-Date)
$logfile = $ScriptLocation + "Logs\scriptlog.txt"
$teamFolderIds = $ScriptLocation + "CSVFiles\teamFolderIds.csv"
$teamFolderFile = $ScriptLocation + "CSVFiles\content.csv"
$teamFolderFinalSorted = $ScriptLocation + "CSVFiles\TeamFolders-" + $docTitle + ".csv"

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
# Functions
###############
function ExportTeamFolderInfo()
{
    try
    {
        #create our client to use
        $teamClient = New-Object DropboxTeamClient($token)
        
        #create CSV file and write out headers first
        $createCsvFile = New-Item $teamFolderFile -type file -force
        [void] $createCsvFile
        $outstring = "TeamFolderName,Size,Name"
        $outstring | Out-File -FilePath $teamFolderFile -Encoding utf8 -Append

        #create CSV file and write out headers first
        $createCsvFile = New-Item $teamFolderIds -type file -force
        [void] $createCsvFile
        $outstring = "TeamFolderName,TeamFolderId"
        $outstring | Out-File -FilePath $teamFolderIds -Encoding utf8 -Append

        #get list of team folders
        GetLogger "Pulling team folder list..." $true

        $teamFolderList = $teamClient.Team.TeamFolderListAsync(1000).Result
        $teamFolderListData = $teamFolderList.TeamFolders
        $cursor = $teamFolderList.Cursor
        $count = $teamFolderList.TeamFolders.Count
     
        foreach ($teamFolderListDataMember in $teamFolderListData)
        {
            $status = $teamFolderListDataMember.Status
            if ($status.IsActive)
            {
                $name = $teamFolderListDataMember.Name
                $teamFolderId = $teamFolderListDataMember.TeamFolderId
                $outstring = "$name,$teamFolderId"
                $outstring | Out-File -FilePath $teamFolderIds -Encoding utf8 -Append    
            }
        }
        while ($cursor -ne $null -and $count -gt 0)
        {
            GetLogger "Pulling next team folder continuation list..." $true

            $teamFolderListCont = $teamClient.Team.TeamFolderListContinueAsync($cursor).Result
            $teamFolderListData = $teamFolderListCont.Members
            $cursor = $teamFolderListCont.Cursor
            $count = $teamFolderListCont.TeamFolders.Count

            if ($count -gt 0)
            {
                foreach ($teamFolderListDataMember in $teamFolderListData)
                {
                    $name = $teamFolderListDataMember.TeamFolderName
                    $teamFolderId = $teamFolderListDataMember.TeamFolderId
                    $outstring = "$name,$teamFolderId"
                    $outstring | Out-File -FilePath $teamFolderIds -Encoding utf8 -Append
                } 
            }
        } 
        #load this into the script for use
        $existingTeamFolders = Import-Csv $teamFolderIds

        foreach($teamFolder in $existingTeamFolders)
        {
            $folderName = $teamFolder.TeamFolderName
            $folderId = $teamFolder.TeamFolderId
			$folder = "ns:" + $folderId

            GetLogger "Pulling team folder content for [$folderName]..." $true

            $content = $teamClient.AsAdmin($adminId).Files.ListFolderAsync($folder, $true, $false, $false, $false)
            $contentResult = $content.Result
            $contentEntries = $contentResult.Entries
            $contentEntriesCount = $contentEntries.Count

            $hasMore = $contentResult.HasMore
            $cursor = $contentResult.Cursor

            #may not be mounted
            if ($contentEntriesCount -gt 0)
            {
                foreach ($entry in $contentEntries) 
                {
                    $name = $entry.Name
                    if ($entry.IsFolder)
                    {
                        $size = "0"
                        $pathLower = $entry.PathLower

                        $outstring = "$folderName,$size,$name"
                        $outstring | Out-File -FilePath $teamFolderFile -Encoding utf8 -Append
                    }
                    if ($entry.IsFile)
                    {
                        $pathLower = $entry.PathLower
                        $size = $entry.AsFile.Size

                        $outstring = "$folderName,$size,$name"
                        $outstring | Out-File -FilePath $teamFolderFile -Encoding utf8 -Append
                    }
                }
                while ($hasMore)
                {
                    $contentCont = $teamClient.AsAdmin($adminId).Files.ListFolderContinueAsync($cursor)
                    $contentContResult = $contentCont.Result
                    $contentEntries = $contentContResult.Entries
                    $contentEntriesCount = $contentEntries.Count
        
                    $hasMore = $contentContResult.HasMore
                    $cursor = $contentContResult.Cursor

                    foreach ($entry in $contentEntries)  
                    {
                        $name = $entry.Name
                        if ($entry.IsFolder)
                        {
                            $size = "0"
                            $pathLower = $entry.PathLower

                            $outstring = "$folderName,$size,$name"
                            $outstring | Out-File -FilePath $teamFolderFile -Encoding utf8 -Append
                        }
                        if ($entry.IsFile)
                        {
                            $pathLower = $entry.PathLower
                            $size = $entry.AsFile.Size
                   
                            $outstring = "$folderName,$size,$name"
                            $outstring | Out-File -FilePath $teamFolderFile -Encoding utf8 -Append
                        }
                    }
                }
            }            
        }    
        GetLogger "-----User team folder content retrieval completed.-----" $true
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

ExportTeamFolderInfo

GetLogger "Sorting team folder data and creating final csv file..." $true

$teamFoldersUnique = Import-Csv $teamFolderFile | Sort-Object * -Unique | Group-Object -Property TeamFolderName | % {$b=$_.name -split ', ';$c=($_.group | Measure-Object -Property Size -Sum).Sum;[PScustomobject]@{TeamFolderName=$b[0];Size=$c}}

#create CSV file and write out headers first
$createCsvFile = New-Item $teamFolderFinalSorted -type file -force
[void] $createCsvFile
$outstring = "TeamFolderName,Size(MB)"
$outstring | Out-File -FilePath $teamFolderFinalSorted -Encoding utf8 -Append

foreach ($teamFolder in $teamFoldersUnique)
{
    $tf = $teamFolder.TeamFolderName
    $size = $teamFolder.Size / 1048576
    $roundedSizeMB = [math]::Round($size,4)
    $outstring = "$tf,$roundedSizeMB"
    $outstring | Out-File -FilePath $teamFolderFinalSorted -Encoding utf8 -Append 
}

GetLogger "Cleaning up temp files..." $true
 
Remove-Item $teamFolderFile
Remove-Item $teamFolderIds

GetLogger "-----Script complete. Output at [$teamFolderFinalSorted]-----" $true

 