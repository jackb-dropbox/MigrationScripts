# Exports content from Box into csv format file.
# Use referenced Box.V21.dll (rebuild as standard .NET class library)
# Uses Box .NET SDK, standard .NET library included
# Update the script location below as well as the usertype, clientid, secret, redirecturi and developer token from Box developer account
# Output files will be located in "<ScriptLocation>\CSVFiles\BoxContent-yyyy-MM-dd HH.mm.ss.csv"
# Author: jackb@dropbox.com
# Updated: 5/16/2017

using namespace Box.V2
using namespace Box.V2.Auth
using namespace Box.V2.Config
using namespace Box.V2.Converter
using namespace Box.V2.Exceptions
using namespace Box.V2.Managers
using namespace Box.V2.Plugins
using namespace Box.V2.Request
using namespace Box.V2.Services
using namespace Nito.AsyncEx

####################
#Variables to update
####################
$ScriptLocation = “C:\Scripts\"
$clientId = "BOX CLIENT ID"
$clientSecret = "BOX CLIENT SECRET"
$redirectUri = "BOX REDIRECT URI FOR YOUR CONFIGURED APP"

#good for 60 min, get new developer token at https://app.box.com/developers/services
$token = "BOX DEVELOPER TOKEN"

########################
#Variables to NOT change
########################
$scriptName = "Box Export Content Script"
$docTitle =  "{0:yyyy-MM-dd HH.mm.ss}" -f (Get-Date)                                                                                    
$contentFile =  $ScriptLocation + "CSVFiles\BoxContent-" + $docTitle + ".csv"
$logfile = $ScriptLocation + "Logs\scriptlog.txt"
$refreshToken = "anything"
$expiresIn = 3600
$count = 0

[void][Reflection.Assembly]::LoadFile($ScriptLocation + "Dlls\Microsoft.Threading.Tasks.dll”)
[void][Reflection.Assembly]::LoadFile($ScriptLocation + "Dlls\Microsoft.Threading.Tasks.Extensions.dll")
[void][Reflection.Assembly]::LoadFile($ScriptLocation + "Dlls\Nito.AsyncEx.dll”)
[void][Reflection.Assembly]::LoadFile($ScriptLocation + "Dlls\Nito.AsyncEx.Concurrent.dll”)
[void][Reflection.Assembly]::LoadFile($ScriptLocation + "Dlls\Nito.AsyncEx.Enlightenment.dll”)
[void][Reflection.Assembly]::LoadFile($ScriptLocation + "Dlls\System.Net.Http.Extensions.dll”)
[void][Reflection.Assembly]::LoadFile($ScriptLocation + "Dlls\System.Net.Http.Primitives.dll”)
[void][Reflection.Assembly]::LoadFile($ScriptLocation + "Dlls\Newtonsoft.Json.dll”)
[void][Reflection.Assembly]::LoadFile($ScriptLocation + "Dlls\Box.V21.dll”)

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

##################
#Box Functions
##################

function ExportContent()
{
    GetLogger "Scanning Box account for content..." $true
    #(f.Name, id, size, ownedBy, userId, fullPath, created, modified)
    Try
    {
        #create userId CSV file and write out headers
        $createCsvFile = New-Item $contentFile -type file -force
        [void] $createCsvFile
        $outstring = "Name,Id,Type,OwnedBy,Size,FullPath,Created,Modified,TrashedAt"
        $outstring | Out-File -FilePath $contentFile -Encoding utf8 -Append

        #create Box client
        $config = New-Object BoxConfig($clientId, $clientSecret, $redirectUri)
        $session = New-Object OAuthSession($token, $refreshToken, $expiresIn, "bearer")  
        $client = New-Object BoxClient($config, $session)

        #start at root folder
        GetFolderContent("0")     
    }
    Catch [BoxException]
    {
        $errorMessage = $_.Message
        GetLogger "***Box Exception: [$errorMessage]***" $true
    }
    Catch
    {
        $errorMessage = $_.Exception.Message
        GetLogger "***Exception: [$errorMessage]***" $true
    }
    GetLogger "Content export completed." $true        
}

function GetFolderContent($contentId)
{
    #Make sure we loop through all using offset and limit
    $offset = 0
    $limit = 1000

    $content = $client.FoldersManager.GetFolderItemsAsync($contentId, $limit, $offset).Result
    $contentEntries = $content.Entries

    foreach ($contentEntry in $contentEntries)
    {   
        $type = $contentEntry.Type
        $contentId = $contentEntry.Id
        $name = $contentEntry.Name
        $fullPath = "/"            
        if ($type -eq "folder")
        {
            $outstring = "$name,$contentId,$type,$null,0,$fullPath,$null,$null,$null"
            $outstring | Out-File -FilePath $contentFile -Encoding utf8 -Append
            $count++

            GetFolderContent($contentId)
        }
        if ($type -eq "file")
        {
            $fileInfo = $client.FilesManager.GetInformationAsync($contentId)
            $file = $fileInfo.Result 
            $pathCollection = $file.PathCollection.Entries
            $pathCount = $pathCollection.Count
            if ($pathCount -gt 1)
            {
                For ($i=0; $i -le $pathCount; $i++) 
                {
                    $fullpath = $fullPath + $pathCollection[$i].Name + "/"
                }
                $fullPath = $fullPath -replace "//", "/"
            }
            $ownedBy = $file.OwnedBy.Login
            $size = $file.Size
            $version = $file.VersionNumber
            $createdAt = $file.CreatedAt
            $modifiedAt = $file.ModifiedAt
            $trashedAt = $file.TrashedAt

            $outstring = "$name,$contentId,$type,$ownedBy,$size,$fullPath,$createdAt,$modifiedAt,$trashedAt"
            $outstring | Out-File -FilePath $contentFile -Encoding utf8 -Append
            $count++
        }
    }
    $offset = $offset + $limit
    $contentCount = $content.TotalCount
    if ($contentCount -ge $offset)
    {
        $pageBool = $true
    }
    if ($contentCount -lt $offset)
    {
        $pageBool = $false
    }
    while ($pageBool)
    {
        $content = $client.FoldersManager.GetFolderItemsAsync($contentId, $limit, $offset).Result
        $contentEntries = $content.Entries

        foreach ($contentEntry in $contentEntries)
        {   
            $type = $contentEntry.Type
            $contentId = $contentEntry.Id
            $name = $contentEntry.Name
            $fullPath = "/" + $name
                
            if ($type -eq "folder")
            {
                $outstring = "$name,$contentId,$type,$null,0,$fullPath,$null,$null,$null"
                $outstring | Out-File -FilePath $contentFile -Encoding utf8 -Append
                $count++

                GetFolderContent($contentId)
            }
            if ($type -eq "file")
            {
                $fileInfo = $client.FilesManager.GetInformationAsync($contentId)
            $file = $fileInfo.Result 
            $pathCollection = $file.PathCollection.Entries
            $pathCount = $pathCollection.Count
            if ($pathCount -gt 1)
            {
                For ($i=0; $i -le $pathCount; $i++) 
                {
                    $fullpath = $fullPath + $pathCollection[$i].Name + "/"
                }
                $fullPath = $fullPath -replace "//", "/"
            }
            $ownedBy = $file.OwnedBy.Login
            $size = $file.Size
            $createdAt = $file.CreatedAt
            $modifiedAt = $file.ModifiedAt
            $trashedAt = $file.TrashedAt

            $outstring = "$name,$contentId,$type,$ownedBy,$size,$fullPath,$createdAt,$modifiedAt,$trashedAt"
            $outstring | Out-File -FilePath $contentFile -Encoding utf8 -Append
            $count++
            }
        }
        $contentCount = $content.TotalCount
        $offset = $offset + $limit
        if ($contentCount -ge $offset)
        {
            $pageBool = $true
        }
        if ($contentCount -lt $offset)
        {
            $pageBool = $false
        }
    }
}

####################
#SCRIPT ENTRY POINT
###################
CreateLogFile

GetLogger "-----Beginning script: [$scriptName]-----" $true
GetLogger "-----Parameters: [LogFile]: $logfile [Script Location]: $ScriptLocation-----" $true

ExportContent

GetLogger "-----Completed script: [$scriptName]-----" $true