# Sets enterprise users from Box to Read-Only, Active or Inactive. Uses exclusion list to ignore any users if needed
# Use referenced Box.V21.dll (rebuild as standard .NET class library)
# Uses Box .NET SDK, standard .NET library included
# Update the variables below: script location, status, clientid, secret, redirecturi and developer token from Box developer account
# Author: jackb@dropbox.com
# Date: 1/31/2017

using namespace Box.V2
using namespace Box.V2.Auth
using namespace Box.V2.Config
using namespace Box.V2.Converter
using namespace Box.V2.Exceptions
using namespace Box.V2.Models
using namespace Box.V2.Managers
using namespace Box.V2.Plugins
using namespace Box.V2.Request
using namespace Box.V2.Services
using namespace Nito.AsyncEx

####################
#Variables to update
####################
#change to ReadOnly, Active, or Inactive
$status = "Active"
$ScriptLocation = “C:\Scripts\"
$clientId = "CLIENT ID"
$clientSecret = "CLIENT SECRET"
$redirectUri = "REDIRECT URI"

#good for 60 min, get new developer token at https://app.box.com/developers/services
$token = "DEVELOPER TOKEN"

########################
#Variables to NOT change
########################

$scriptName = "Update Box Enterprise Users Status Script"
$exclusionFile =  $ScriptLocation + "CSVFiles\exclusions.csv"
$logfile = $ScriptLocation + "Logs\scriptlog.txt"
$refreshToken = "anything"
$expiresIn = 3600
$statusCount = 0
$count = 0
$activeStatus = "active"
$inactiveStatus = "inactive"
$readOnlyStatus = "cannot_delete_edit_upload"

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

function ChangeUserStatus()
{
        GetLogger "Getting enterprise users from Box..." $true

        Try
        {
            #create Box client
            $config = New-Object BoxConfig($clientId, $clientSecret, $redirectUri)
            $session = New-Object OAuthSession($token, $refreshToken, $expiresIn, "bearer")  
            $client = New-Object BoxClient($config, $session)

            #get status choice that was made in variables
            if ($status -eq "ReadOnly")
            {
                $statusChoice = $readOnlyStatus
            }
            if ($status -eq "Active")
            {
                $statusChoice = $activeStatus
            }
            if ($status -eq "Inactive")
            {
                $statusChoice = $inactiveStatus
            }

            #import exclusion list
            $exclusions = Import-Csv $exclusionFile
        
            #get enterprise users
            $entItems = $client.UsersManager.GetEnterpriseUsersAsync().Result
            $users = $entItems.Entries

            #set each user to read-only not in exclusions list
            foreach ($user in $users)
            {   
                $id = $user.Id
                $login = $user.Login
           
                $exclude = $exclusions | Where-Object {$_.Login -eq $login}
            
                #not excluded
                if ($exclude -eq $null)
                {
                    #set to read-only
                    $userRequest = New-Object BoxUserRequest
                    $userRequest.Id = $id
                    $userRequest.Status = $statusChoice
                
                    $user = $client.UsersManager.UpdateUserInformationAsync($userRequest).Result
                    $statusCount++
                }
                $count++
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
        GetLogger "User Id's set to $status completed. Total User's: [$count] Total set to $status [$statusCount]" $true 
}

####################
#SCRIPT ENTRY POINT
###################
CreateLogFile

GetLogger "-----Beginning script: [$scriptName]-----" $true
GetLogger "-----Parameters: [Status choice] $status [LogFile]: $logfile [Script Location]: $ScriptLocation-----" $true

ChangeUserStatus

GetLogger "-----Completed script: [$scriptName]-----" $true