# Exports enterprise users from Box into csv format file. Can be used to import for other scripts here
# Use referenced Box.V21.dll (rebuild as standard .NET class library)
# Uses Box .NET SDK, standard .NET library included
# Update the script location below as well as the userType, clientid, secret, redirecturi and developer token from Box developer account
# Output files will be located in "<ScriptLocation>\CSVFiles\yyyy-MM-dd HH.mm.ss.csv"
# Author: jackb@dropbox.com
# Updated: 3/21/2017

using namespace Box.V2
using namespace Box.V2.Auth
using namespace Box.V2.Config
using namespace Box.V2.Converter
using namespace Box.V2.Exceptions
using namespace Box.V2.Managers
using namespace Box.V2.Models
using namespace Box.V2.Plugins
using namespace Box.V2.Request
using namespace Box.V2.Services
using namespace Nito.AsyncEx

####################
#Variables to update
####################

#Valid values are all, external or managed
$userType = "managed"

$ScriptLocation = “C:\Scripts\"
$clientId = "CLIENT ID"
$clientSecret = "CLIENT SECRET"
$redirectUri = "REDIRECT URI"

#good for 60 min, get new developer token at https://app.box.com/developers/services
$token = "DEVELOPER TOKEN"

########################
#Variables to NOT change
########################
$scriptName = "Box Export Users Script"
$docTitle =  "{0:yyyy-MM-dd HH.mm.ss}" -f (Get-Date)                                                                                    
$userIdFile =  $ScriptLocation + "CSVFiles\userIds" + $docTitle + ".csv"
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

function ExportUsers()
{
        GetLogger "Getting enterprise users from Box ($userType users)..." $true

        Try
        {
            #create userId CSV file and write out headers
            $createCsvFile = New-Item $userIdFile -type file -force
            [void] $createCsvFile
            $outstring = "Login,Id"
            $outstring | Out-File -FilePath $userIdFile -Encoding utf8 -Append

            #create Box client
            $config = New-Object BoxConfig($clientId, $clientSecret, $redirectUri)
            $session = New-Object OAuthSession($token, $refreshToken, $expiresIn, "bearer")  
            $client = New-Object BoxClient($config, $session)

            #get enterprise users and write to CSV file
            #Make sure we loop through all using offset and limit
            $offset = 0
            $limit = 1000

            $entItems = $client.UsersManager.GetEnterpriseUsersAsync("", $offset, $limit, $null, $userType, $false).Result
            $users = $entItems.Entries
            foreach ($user in $users)
            {   
                $id = $user.Id
                $login = $user.Login
                $outstring = "$login,$id"
                $outstring | Out-File -FilePath $userIdFile -Encoding utf8 -Append
                $count++
            }

            $offset = $offset + $limit
            $entCount = $entItems.TotalCount
            if ($entCount -ge $offset)
            {
                $pageBool = $true
            }
            if ($entCount -lt $offset)
            {
                $pageBool = $false
            }
            while ($pageBool)
            {
                $entItems = $client.UsersManager.GetEnterpriseUsersAsync("", $offset, $limit, $null, $userType, $false).Result
                $users = $entItems.Entries
                foreach ($user in $users)
                {   
                    $id = $user.Id
                    $login = $user.Login
                    $outstring = "$login,$id"
                    $outstring | Out-File -FilePath $userIdFile -Encoding utf8 -Append
                    $count++
                }
                $entCount = $entItems.TotalCount
                $offset = $offset + $limit
                if ($entCount -ge $offset)
                {
                    $pageBool = $true
                }
                if ($entCount -lt $offset)
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
        GetLogger "User export completed. Total User's dumped: $count" $true        
}

####################
#SCRIPT ENTRY POINT
###################
CreateLogFile

GetLogger "-----Beginning script: [$scriptName]-----" $true
GetLogger "-----Parameters: [LogFile]: $logfile [Script Location]: $ScriptLocation-----" $true

ExportUsers

GetLogger "-----Completed script: [$scriptName]-----" $true