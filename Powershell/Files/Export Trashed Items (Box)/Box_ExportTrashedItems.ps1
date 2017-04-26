# Exports Trashed Items from Box into csv format file.
# Use referenced Box.V21.dll (rebuild as standard .NET class library)
# Uses Box .NET SDK, standard .NET library included
# Update the script location below as well as the clientid, secret, redirecturi and developer token from Box developer account
# Output files will be located in "<ScriptLocation>\CSVFiles\TrashedItems-yyyy-MM-dd HH.mm.ss.csv"
# Author: jackb@dropbox.com
# Updated: 4/3/2017

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
$clientId = "CLIENT ID"
$clientSecret = "CLIENT SECRET"
$redirectUri = "REDIRECT URI"

#good for 60 min, get new developer token at https://app.box.com/developers/services
$token = "DEVELOPER TOKEN"

########################
#Variables to NOT change
########################
$scriptName = "Box Export Trashed Items Script"
$docTitle =  "{0:yyyy-MM-dd HH.mm.ss}" -f (Get-Date)                                                                                    
$userIdFile =  $ScriptLocation + "CSVFiles\TrashedItems" + $docTitle + ".csv"
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

function ExportTrashedItems()
{
        GetLogger "Getting trashed items from Box..." $true

        Try
        {
            #create userId CSV file and write out headers
            $createCsvFile = New-Item $userIdFile -type file -force
            [void] $createCsvFile
            $outstring = "Name,Type,Id,TrashedAt,PurgedAt"
            $outstring | Out-File -FilePath $userIdFile -Encoding utf8 -Append

            #create Box client
            $config = New-Object BoxConfig($clientId, $clientSecret, $redirectUri)
            $session = New-Object OAuthSession($token, $refreshToken, $expiresIn, "bearer")  
            $client = New-Object BoxClient($config, $session)

            #get enterprise users and write to CSV file
            #Make sure we loop through all using offset and limit
            $offset = 0
            $limit = 1000

            $resultSet = $client.FoldersManager.GetTrashItemsAsync($limit, $offset, $null, $false).Result
            $results = $resultSet.Entries
            foreach ($result in $results)
            {   
                $id = $result.Id
                $type = $result.Type
                $name = $result.Name
                $trashedAt = $result.TrashedAt
                $purgedAt = $result.PurgedAt

                $outstring = "$name,$type,$id,$trashedAt,$purgedAt"
                $outstring | Out-File -FilePath $userIdFile -Encoding utf8 -Append
                $count++
            }

            $offset = $offset + $limit
            $resultCount = $resultSet.TotalCount
            if ($resultCount -ge $offset)
            {
                $pageBool = $true
            }
            if ($resultCount -lt $offset)
            {
                $pageBool = $false
            }
            while ($pageBool)
            {
                $resultSet = $client.FoldersManager.GetTrashItemsAsync($limit, $offset, $null, $false).Result
                $results = $resultSet.Entries
                foreach ($result in $results)
                {   
                    $id = $result.Id
                    $type = $result.Type
                    $name = $result.Name
                    $trashedAt = $result.TrashedAt
                    $purgedAt = $result.PurgedAt

                $outstring = "$name,$type,$id,$trashedAt,$purgedAt"
                $outstring | Out-File -FilePath $userIdFile -Encoding utf8 -Append
                $count++
                }
                $offset = $offset + $limit
                $resultCount = $resultSet.TotalCount
                if ($resultCount -ge $offset)
                {
                    $pageBool = $true
                }
                if ($resultCount -lt $offset)
                {
                    $pageBool = $false
                }
            }
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
        GetLogger "Box Trash export completed. Total item's exported: $count" $true        
}

####################
#SCRIPT ENTRY POINT
###################
CreateLogFile

GetLogger "-----Beginning script: [$scriptName]-----" $true
GetLogger "-----Parameters: [LogFile]: $logfile [Script Location]: $ScriptLocation-----" $true

ExportTrashedItems

GetLogger "-----Completed script: [$scriptName]-----" $true