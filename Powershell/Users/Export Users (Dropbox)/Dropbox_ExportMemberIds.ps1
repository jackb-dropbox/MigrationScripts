# Exports enterprise users from Dropbox into csv format file. Can be used to import for other scripts here
# Uses Dropbox .NET SDK, standard .NET library included
# Update the script location below as well as the token
# Author: jackb@dropbox.com
# Date: 1/27/2017

using namespace Dropbox.Api

####################
#Variables to update
####################
$ScriptLocation = "C:\Scripts\"
$token = "ENTER TEAM MEMBER FILE ACCESS TOKEN HERE"

########################
#Variables to NOT change
########################
$scriptName = "Export Dropbox Member ID's to CSV File"
$logfile = $ScriptLocation + "Logs\scriptlog.txt"
$memberIdFile = $ScriptLocation + "CSVFiles\memberIds.csv"
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

#create CSV file and write out headers first
$createCsvFile = New-Item $memberIdFile -type file -force
[void] $createCsvFile
$outstring = "email,memberId"
$outstring | Out-File -FilePath $memberIdFile -Encoding utf8 -Append

GetLogger "-----Exporting memberId's to CSV file: $memberIdFile-----" $true

#get first set of memberId's
$client = New-Object DropboxTeamClient($token)
$members = $client.Team.MembersListAsync().Result
$memberinfo = $members.Members
$hasMore = $members.HasMore
$cursor = $members.Cursor

foreach ($member in $memberinfo)
{
    $email = $member.Profile.Email
    $memberId = $member.Profile.TeamMemberId 
    $outstring = "$email,$memberId"
    $outstring | Out-File -FilePath $memberIdFile -Encoding utf8 -Append
    $count++
}
#if a continuation token, keep grabbing and writing them to file
while ($hasMore)
{
    $membersCont = $client.Team.MembersListContinueAsync($cursor).Result
    $memberinfo = $membersCont.Members
    $cursor = $membersCont.Cursor
    $hasMore = $membersCont.HasMore 

    foreach ($member in $memberinfo)
    {
        $email = $member.Profile.Email
        $memberId = $member.Profile.TeamMemberId
        $outstring = "$email,$memberId"
        $outstring | Out-File -FilePath $memberIdFile -Encoding utf8 -Append
        $count++
    }
}
GetLogger "-----Completed. Total memberId's exported: [$count]-----" $true