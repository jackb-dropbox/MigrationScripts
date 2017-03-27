# Exports list of groups and their users from Box into csv format file. One line for each user/group combination
# Use referenced Box.V21.dll (rebuild as standard .NET class library)
# Uses Box .NET SDK, standard .NET library included
# Update the script location below as well as the clientid, secret, redirecturi and developer token from Box developer account
# Author: jackb@dropbox.com
# Date: 3/24/2017

using namespace Box.V2
using namespace Box.V2.Auth
using namespace Box.V2.Config
using namespace Box.V2.Converter
using namespace Box.V2.Exceptions
using namespace Box.V2.Managers
using namespace Box.V2.Models
using namespace Box.V2.Models.Request
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
$scriptName = "Box - Export Box Groups and Users to CSV File"
$docTitle =  "{0:yyyy-MM-dd HH.mm.ss}" -f (Get-Date)
$boxGroupsFile =  $ScriptLocation + "CSVFiles\boxGroups-"  + $docTitle + ".csv"
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

function ExportGroupsAndMembers()
{
        GetLogger "Getting Box Groups and Users..." $true

        Try
        {
            #create userId CSV file and write out headers
            $createCsvFile = New-Item $boxGroupsFile -type file -force
            [void] $createCsvFile
            $outstring = "GroupName,GroupId,GroupType,MemberEmail,MemberId,Role,Status"
            $outstring | Out-File -FilePath $boxGroupsFile -Encoding utf8 -Append

            #create Box client
            $config = New-Object BoxConfig($clientId, $clientSecret, $redirectUri)
            $session = New-Object OAuthSession($token, $refreshToken, $expiresIn, "bearer")  
            $client = New-Object BoxClient($config, $session)

            #get Box Groups and write to CSV file
            #Make sure we loop through all using offset and limit
            $offset = 0
            $limit = 1000
        
            $groupCollection = New-Object BoxGroup
            $groupCollection = $client.GroupsManager.GetAllGroupsAsync($limit, $offset, $null, $false);
            $groupsResult = $groupCollection.Result
            $groups = $groupsResult.Entries
            foreach ($group in $groups)
            {
                $membercount = 0
                $name = $group.Name
                $id = $group.Id
                $type = $group.Type
                $count++

                #Make sure we loop through all members using new offset and limit
                $gOffset = 0
                $gLimit = 1000

                #get membership for each group
                $groupMembership = New-Object BoxGroupMembership
                $groupMembership = $client.GroupsManager.GetAllGroupMembershipsForGroupAsync($id, $gLimit, $gOffset, $null, $false)
                $groupMembersResult = $groupMembership.Result
                $groupMembers = $groupMembersResult.Entries
                foreach ($groupMember in $groupMembers)
                {
                    $memberId = $groupMember.User.Id
                    #we need more information on user like email
                    $member = New-Object BoxUser
                    $memberInfoObject = $client.UsersManager.GetUserInformationAsync($memberId)
                    $memberResult = $memberInfoObject.Result
                    $email = $memberResult.Login
                    $role = $memberResult.Role
                    $status = $memberResult.Status

                    $outstring = "$name,$id,$type,$email,$memberId,$role,$status"
                    $outstring | Out-File -FilePath $boxGroupsFile -Encoding utf8 -Append
                    $membercount++
                }
                $gOffset = $gOffset + $gLimit
                $groupCount = $groupMembersResult.TotalCount
                if ($groupCount -ge $gOffset)
                {
                    $gPageBool = $true
                }
                if ($groupCount -lt $gOffset)
                {
                    $gPageBool = $false
                }
                while ($gPageBool)
                {
                    #get membership for each group
                    $groupMembership = New-Object BoxGroupMembership
                    $groupMembership = $client.GroupsManager.GetAllGroupMembershipsForGroupAsync($id, $gLimit, $gOffset, $null, $false)
                    $groupMembersResult = $groupMembership.Result
                    $groupMembers = $groupMembersResult.Entries
                    foreach ($groupMember in $groupMembers)
                    {
                        $memberId = $groupMember.User.Id

                        #we need more information on user like email
                        $member = New-Object BoxUser
                        $memberInfoObject = $client.UsersManager.GetUserInformationAsync($memberId)
                        $memberResult = $memberInfoObject.Result
                        $email = $memberResult.Login
                        $role = $memberResult.Role
                        $status = $memberResult.Status

                        $outstring = "$name,$id,$type,$email,$memberId,$role,$status"
                        $outstring | Out-File -FilePath $boxGroupsFile -Encoding utf8 -Append
                        $membercount++
                    }
                    $gOffset = $gOffset + $gLimit
                    $groupCount = $groupMembersResult.TotalCount
                    if ($groupCount -ge $gOffset)
                    {
                        $gPageBool = $true
                    }
                    if ($groupCount -lt $gOffset)
                    {
                        $gPageBool = $false
                    }
                }                  
                GetLogger "Box Group [$name] exported successfully. Total members: [$membercount]" $true        
            }
            $offset = $offset + $limit
            $groupCount = $groupMembersResult.TotalCount
            if ($groupCount -ge $offset)
            {
                $pageBool = $true
            }
            if ($groupCount -lt $offset)
            {
                $pageBool = $false
            }
            while ($pageBool)
            {
                $groupCollection = New-Object BoxGroup
                $groupCollection = $client.GroupsManager.GetAllGroupsAsync($limit, $offset, $null, $false);
                $groupsResult = $groupCollection.Result
                $groups = $groupsResult.Entries
                foreach ($group in $groups)
                {
                    $membercount = 0
                    $name = $group.Name
                    $id = $group.Id
                    $type = $group.Type
                    $count++

                    #Make sure we loop through all members using new offset and limit
                    $gOffset = 0
                    $gLimit = 1000

                    #get membership for each group
                    $groupMembership = New-Object BoxGroupMembership
                    $groupMembership = $client.GroupsManager.GetAllGroupMembershipsForGroupAsync($id, $gLimit, $gOffset, $null, $false)
                    $groupMembersResult = $groupMembership.Result
                    $groupMembers = $groupMembersResult.Entries
                    foreach ($groupMember in $groupMembers)
                    {
                        $memberId = $groupMember.User.Id
                        #we need more information on user like email
                        $member = New-Object BoxUser
                        $memberInfoObject = $client.UsersManager.GetUserInformationAsync($memberId)
                        $memberResult = $memberInfoObject.Result
                        $email = $memberResult.Login
                        $role = $memberResult.Role
                        $status = $memberResult.Status

                        $outstring = "$name,$id,$type,$email,$memberId,$role,$status"
                        $outstring | Out-File -FilePath $boxGroupsFile -Encoding utf8 -Append
                        $membercount++
                    }
                    $gOffset = $gOffset + $gLimit
                    $groupCount = $groupMembersResult.TotalCount
                    if ($groupCount -ge $gOffset)
                    {
                        $gPageBool = $true
                    }
                    if ($groupCount -lt $gOffset)
                    {
                        $gPageBool = $false
                    }
                    while ($gPageBool)
                    {
                        #get membership for each group
                        $groupMembership = New-Object BoxGroupMembership
                        $groupMembership = $client.GroupsManager.GetAllGroupMembershipsForGroupAsync($id, $gLimit, $gOffset, $null, $false)
                        $groupMembersResult = $groupMembership.Result
                        $groupMembers = $groupMembersResult.Entries
                        foreach ($groupMember in $groupMembers)
                        {
                            $memberId = $groupMember.User.Id

                            #we need more information on user like email
                            $member = New-Object BoxUser
                            $memberInfoObject = $client.UsersManager.GetUserInformationAsync($memberId)
                            $memberResult = $memberInfoObject.Result
                            $email = $memberResult.Login
                            $role = $memberResult.Role
                            $status = $memberResult.Status

                            $outstring = "$name,$id,$type,$email,$memberId,$role,$status"
                            $outstring | Out-File -FilePath $boxGroupsFile -Encoding utf8 -Append
                            $membercount++
                        }
                        $gOffset = $gOffset + $gLimit
                        $groupCount = $groupMembersResult.TotalCount
                        if ($groupCount -ge $gOffset)
                        {
                            $gPageBool = $true
                        }
                        if ($groupCount -lt $gOffset)
                        {
                            $gPageBool = $false
                        }
                    }
                    GetLogger "Box Group [$name] exported successfully. Total members: [$membercount]" $true                                            
                 }
                 $offset = $offset + $limit
                 $groupCount = $groupMembersResult.TotalCount
                 if ($groupCount -ge $offset)
                 {
                     $pageBool = $true
                 }
                 if ($groupCount -lt $offset)
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
        GetLogger "Box Groups export completed. Total groups: [$count]" $true  
}

####################
#SCRIPT ENTRY POINT
###################
CreateLogFile

GetLogger "-----Beginning script: [$scriptName]-----" $true
GetLogger "-----Parameters: [LogFile]: $logfile [Script Location]: $ScriptLocation-----" $true

ExportGroupsAndMembers

GetLogger "-----Completed script: [$scriptName]-----" $true