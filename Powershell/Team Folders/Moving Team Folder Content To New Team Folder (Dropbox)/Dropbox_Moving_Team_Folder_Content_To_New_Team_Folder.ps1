# Move team folder contents to another team folder.

# Update script location, as well as $token with team member file access token 
# You will also need the member ID of a team admin for the $adminToken variable. 
# This can be obtained through the Admin Toolkit or member Id script at:
# https://github.com/DropboxServices/MigrationScripts/tree/master/Powershell/Users/Export%20Users%20(Dropbox)

# Create CSV File in CSV folder, naming file folderPaths.csv. Add your team
# folder sources and destinations. Format is:

#Source,Destination
#TeamFolder1,TeamFolder1Dest1
#TeamFolder2,TeamFolder1Dest2
#TeamFolder3,TeamFolder1Dest3

# Uses Dropbox .NET SDK, standard .NET library included
# Update the script location below as well as the token
# Author: jackb@dropbox.com
# Date: 7/6/2017

using namespace Dropbox.Api

####################
#Variables to update
####################
$ScriptLocation = "C:\Scripts\"
$token = "ENTER TEAM MEMBER FILE ACCESS TOKEN HERE"
$adminToken = "ENTER TEAM ADMIN MEMBER ID HERE"

########################
#Variables to NOT change
########################
$scriptName = "Move Dropbox Team folder content to another team folder."
$logfile = $ScriptLocation + "Logs\scriptlog.txt"
$folderPathFile = $ScriptLocation + "CSVFiles\folderPaths.csv"

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
GetLogger "-----Importing team folder information from CSV file-----" $true

try
{
    $teamClient = New-Object DropboxTeamClient($token)

    #import members from CSV file
    $folderPaths = Import-Csv $folderPathFile

    foreach ($folderPath in $folderPaths)
    {
        $folder = "/" + $folderPath.Source
        $source = $folderPath.Source
        $destination = $folderPath.Destination

        GetLogger "Getting content for [$folder] as admin..." $true

        $content = $teamClient.AsAdmin($adminToken).Files.ListFolderAsync($folder, $true, $false, $false, $false)
        $result = $content.Result
        $contentEntries = $result.Entries
        $contentEntriesCount = $contentEntries.Count

        $hasMore = $result.HasMore
        $cursor = $result.Cursor

        #may not be mounted
        if ($contentEntriesCount -gt 0)
        {
            if ($contentEntriesCount -ge 10000)
            {
                #need code to split folders
                GetLogger "[$source] has 10,000 items or higher and can't be moved as is.." $true
            }
            if ($contentEntriesCount -ilt 10000)
            {
                For ($i=0; $i -le $contentEntriesCount; $i++) 
                {
                    $name = $contentEntries[$i].Name

                    if ($name -ne $source -and $name -ne $null)
                    {
                        $pathLower = $contentEntries[$i].PathLower
                        $path = $contentEntries[$i].PathDisplay
                        $name = $contentEntries[$i].Name
                        $newPath = $pathLower.Replace($source.ToLower(), $destination.ToLower())

                        if (!$newPath.StartsWith("/"))
                        {
                            $newPath = "/" + $newPath
                        }
                        $source = "/" + $folderPath.Source

                        if ($pathLower.Contains($source.ToLower()))
                        {
                            $move = $teamClient.AsAdmin($adminToken).Files.MoveAsync($path, $newpath, $true, $false)
                            $outcome = $move.Result

                            if ($move -eq $null)
                            {
                                GetLogger "No content to move for [$source]." $true
                            }
                        } 
                    }  
                }
            }
        }
        while ($hasMore)
        {
            $contentCont  = $teamClient.AsAdmin($adminToken).Files.ListFolderContinueAsync($cursor)
            $result = $contentCont.Result
            $contentEntries = $result.Entries
            $contentEntriesCount = $contentEntries.Count

            $hasMore = $result.HasMore
            $cursor = $result.Cursor

            #may not be mounted
            if ($contentEntriesCount -gt 0)
            {
                if ($contentEntriesCount -ge 10000)
                {
                    #need code to split folders
                    GetLogger "[$source] has 10,000 items or higher and can't be moved as is.." $true
                }
                if ($contentEntriesCount -ilt 10000)
                {
                    For ($i=0; $i -le $contentEntriesCount; $i++) 
                    {
                        $name = $contentEntries[$i].Name
                        if ($name -ne $source -and $name -ne $null)
                        {
                            $pathLower = $contentEntries[$i].PathLower
                            $path = $contentEntries[$i].PathDisplay
                            $name = $contentEntries[$i].Name
                            $newPath = $pathLower.Replace($source.ToLower(), $destination.ToLower())

                            if (!$newPath.StartsWith("/"))
                            {
                                $newPath = "/" + $newPath
                            }
                            $source = "/" + $folderPath.Source

                            if ($pathLower.Contains($source.ToLower()))
                            {
                                $move = $teamClient.AsAdmin($adminToken).Files.MoveAsync($path, $newpath, $true, $false)
                                $outcome = $move.Result

                                if ($move -eq $null)
                                {
                                    GetLogger "No content to move for [$source]." $true
                                }
                            }
                        }   
                    }
                }
            }
        }
    }
}
catch
{
    $errorMessage = $_.Exception.Message
    GetLogger "***Error during content extraction,  Exception: [$errorMessage]***" $true
}
GetLogger "-----Completed.-----" $true