# Exports enterprise users from Box into csv format file. Can be used to import for other scripts here
# Use referenced Box.V21.dll (rebuild as standard .NET class library)
# Uses Box .NET SDK, standard .NET library included
# Update the script location below as well as the clientid, secret, redirecturi and developer token from Box developer account
# Author: jackb@dropbox.com
# Date: 1/27/2017

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
$scriptName = "Box Export Users Script"
$userIdFile =  $ScriptLocation + "CSVFiles\userIds.csv"
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
[void][Reflection.Assembly]::LoadFile($ScriptLocation + "Dlls\bouncy_castle_hmac_sha_pcl.dll”)
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
        GetLogger "Getting enterprise users from Box..." $true

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
        $entItems = $client.UsersManager.GetEnterpriseUsersAsync().Result
        $users = $entItems.Entries
        foreach ($user in $users)
        {   
            $id = $user.Id
            $login = $user.Login
            $outstring = "$login,$id"
            $outstring | Out-File -FilePath $userIdFile -Encoding utf8 -Append
            $count++
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