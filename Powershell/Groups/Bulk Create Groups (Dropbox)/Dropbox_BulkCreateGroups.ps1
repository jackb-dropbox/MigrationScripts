# Bulk creates groups in Dropbox Business. Create a csv file with 2 column headers of: GroupName,GroupType 
# (GroupType is either user_managed or company_managed)

# Example:

# GroupName,GroupType
# TestGroup1,user_managed
# TestGroup2,user_managed
# TestGroup3,company_managed

# Uses Dropbox .NET SDK, standard .NET library included
# Update the script location below as well as the token
# Uses Powershell 5.0..if not on this you can update your system at: 
# https://www.microsoft.com/en-us/download/details.aspx?id=50395
# Author: jackb@dropbox.com
# Date: 3/9/2017

using namespace Dropbox.Api

####################
#Variables to update
####################
$ScriptLocation = "C:\Scripts\"

#Needs team member management token to run
$token = "ENTER TEAM MEMBER MANAGEMENT TOKEN HERE"

########################
#Variables to NOT change
########################
$scriptName = "Bulk Create Groups in Dropbox Dropbox"
$logfile = $ScriptLocation + "Logs\scriptlog.txt"
$groupFile = $ScriptLocation + "CSVFiles\groups.csv"
$count = 0

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

GetLogger "-----Bulk creating list of group names from CSV file-----" $true

try
{
    #import groups list
    $groups = Import-Csv $groupFile

    #create our client to use
    $client = New-Object DropboxTeamClient($token)

    $user = [TeamCommon.GroupManagementType+UserManaged]
    $company = [TeamCommon.GroupManagementType+CompanyManaged]
    
    foreach ($group in $groups)
    {
        $groupName = $group.GroupName
        $groupType = $group.GroupType

        if ($groupType -eq "user_managed")
        {
            $create = $client.Team.GroupsCreateAsync($groupName, $user)
        
        }
        if ($groupType -eq "company_managed")
        {
            $create = $client.Team.GroupsCreateAsync($groupName, $company)
        }
        $count++
    }
}
catch
{
    $errorMessage = $_.Exception.Message
    GetLogger "***Error during group creation process,  Exception: [$errorMessage]***" $true
}

GetLogger "-----Completed. Total groups created: [$count]-----" $true

