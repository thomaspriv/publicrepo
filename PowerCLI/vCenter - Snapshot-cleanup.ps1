<#
####################################################################################################################
Author:           Merckx Thomas
Changelog:
    20221012: initial version
    20221026: rework of preparation and deletion
    20221107: added disconnect function
    20221110: added extra comments
    20221212: added loop to write all current snapshots + added excludekeyword parameter to exclude snapshots
    20230119: rework of exclude snapshot part



Summary:          This script will cleanup all snapshots older than X days.
####################################################################################################################
#>

# #####################################################################################################################
# Variables

#vCenters
    #BE

    $vCenter = "vCenter FQDN"


#to use encrypted XML files
    $Credential = import-clixml "$PSScriptRoot\..\Credentials-USER.xml"
#if you don't want to use the encrypted XML files
    #$Credential = Get-Credential

$LogPath = "C:\Temp\Script_Logs"

# show all snapshots or limit snapshots to below variable locations
$VMLocationsall = "all" #all/limited

#Specify allowed cluster and resourcepool names here where snapshots can be deleted. (set $VMLocationsall to "no")
$VMLocations = (
#clusternames
"CLUSTER1","CLUSTER2",
"CLUSTER3","CLUSTER4",
#resourcepools
"Resourcepool1","Resourcepool1"
)

# Amount of days to keep the snapshots
$daystokeep = 10

# will the script be used in an automated way or manually run
$automation = "manual" # auto / manual

# exclude snapshots where snapshot name contains specific word
$excludekeyword = "DO-NOT-DELETE"

$Date = get-date -f yyyyMMdd_HHmm

# End of variable configuration
# #####################################################################################################################

# #####################################################################################################################
# functions
function DisconnectVIServer {
    # Disconnect the vCenter Server

    #disconnect only vcenter from variable
    #Disconnect-VIServer -Server $vCenter -confirm:$false
    #disconnect all vcenters
    Disconnect-VIServer -Server * -confirm:$false
}
function ConnectVIServer {
    # Reject participation in CEIP and ignore invalid certs
    #Import-Module vmware.powercli
    Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -confirm:$false -ErrorAction SilentlyContinue | Out-Null
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false  | Out-Null
    Set-PowerCLIConfiguration -DefaultVIServerMode Single -Confirm:$false | Out-Null

    # Check the Connectivity of vCenter Server and terminate if not pingable
    if ( -not (Test-Connection -ComputerName $vCenter -Count 1 -Quiet) )
    {
        Write-Host "'nProvided vCenter Server # $vCenter # is Not Reachable, please enter a valid FQDN or IP Address"
        exit
    }

    Write-Host "`nConnecting to vCenter `"$vCenter`"..." -ForegroundColor Green
    # Check if vCenter is already connected
    if (($global:DefaultVIServer).Name -ne $vCenter) {
        $VCConnection = Connect-VIServer -Server $vCenter -Credential $Credential -ErrorAction 'Stop' | Out-Null
        Write-Host ("`nSuccessfully Connected to vCenter Server `"$vCenter`"") -ForegroundColor Green
    }else {
        Write-Host ("`nAlready connected to `"$vCenter`"") -ForegroundColor Red
    }
}
function LogCleanup
{
    # Cleanup logs older than 1000 days.
    Get-ChildItem -path $LogPath -Recurse -Force | Where-Object {!$_.PSIsContainer -and $_.LastWriteTime -lt (Get-Date).AddDays(-1000)} | Remove-Item -Force
}

function WriteLog
{
Param ([string]$LogString)
$LogMessage = "$Date - $LogString"
Write-Host $LogString
Add-content $LogPath\"$Date"_Snapshot-cleanup.log -value $LogMessage
}


# End of function definition
# #####################################################################################################################

# #####################################################################################################################
# start of script

Clear-Host
Write-Host  " "
Write-Host  "######################## Snapshot-cleanup.ps1 ##########################"
Write-Host  " "
Write-Host  "      This script will cleanup all snapshots older than X days."
Write-Host  " "
Write-Host  "######################################################################"
Write-Host  " "

# Verify if the log folder exists.
If(!(Test-Path $LogPath)){
    Write-Host "Log path not found, creating folder."
    New-Item $LogPath -Type Directory
}
Write-Host "Writing logs to: $LogPath "

ConnectVIServer





# ----------- preparation part -----------

    # compile list of all VMs from allowed cluster and resourcepool
    if($VMLocationsall -eq "limited") {
        $AllowedVMs = Get-VM -Location $VMLocations -erroraction 'silentlycontinue'
    }
    Else{
        $AllowedVMs = Get-VM -erroraction 'silentlycontinue' 
    }

    Write-Host "`nGenerating list of all snapshots..." -ForegroundColor Green

    # generate list of all snapshots where date generated is older than $daystokeep
    $snapshotlistall = get-snapshot -vm $AllowedVMs | Select-Object VM, SizeMB,Created, @{Name="Age in days";Expression={((Get-Date)-$_.Created).Days}}, Name, Description
    $snapshotlistolderthanxdays = get-snapshot -vm $AllowedVMs | Where-Object {$_.Created -lt (Get-Date).AddDays(-$daystokeep)}



# skip question and exit if no snapshots needs to be deleted or if no snapshots have been found
if($null -ne $snapshotlistolderthanxdays -or $snapshotlistolderthanxdays.count -gt 0 -and 0 -ne $snapshotlistall.count) {

    Write-Host "`nCurrent number of Snapshots in `"$vCenter`" before cleanup, older than $daystokeep day(s):"$snapshotlistolderthanxdays.count". (total number of snapshots:"$snapshotlistall.count")." -ForegroundColor Red
    foreach ($snapshot in $snapshotlistolderthanxdays)
    {
    # Get the snapshot name
    $snapshotname = $snapshot.Name
        if ($snapshotname -notlike "$excludekeyword") { 
            # Output the Name, Description and Age
            Write-Host "VM: $($snapshot.VM)"-ForegroundColor Green ", Name: $($snapshot.Name)" ", Description: $($snapshot.Description)" ", Created: $($snapshot.created)" ", Age in days: $(((Get-Date)-$snapshot.Created).Days)"
        }
    }


    # List all to be excluded Snapshots
    Write-Host "`nListing to be excluded snapshots..." -ForegroundColor Red
    # Loop through the snapshots
    #foreach ($snapshot in $snapshotlistolderthanxdays)
    foreach ($snapshot in $snapshotlistall) {
    # Get the snapshot name
    $snapshotname = $snapshot.Name
        if ($snapshotname -like "$excludekeyword") { 
            #Write-host $Snapshot
            Write-Host "Excluded snapshot: $($snapshot.VM)"-ForegroundColor Green " ,Name: $($snapshot.Name)" " ,Description: $($snapshot.Description)" " ,Created: $($snapshot.created)" ",Age in days: $($snapshot.'Age in days')"
        }
    }

    # write all snapshots from VMs from allowed cluster and resourcepool to csv
    #Write-Output "Snapshots existing before cleanup" | Export-Csv -Path $LogPath\"$date"_Snapshots_1beforecleanup_"$vCenter".txt -Append

    Write-Output $snapshotlistall | Export-Csv -Path $LogPath\"$Date"_Snapshots_1beforecleanup_"$vCenter".csv -Append -NoClobber -NoTypeInformation

    # skip question if script is used in an automated way
    if($automation -eq "manual") {
        # ask user if snapshots can be deleted
        Write-Host "`nContinue with snapshot cleanup?" -ForegroundColor Magenta
        $answer = Read-Host -Prompt "Do you accept (Y or N)"
        if($answer -ne "Y" -or $answer -ne "y") {
            Write-Host "`nNot continuing with snapshot cleanup." -ForegroundColor Green
            Write-Host "Exiting....." -ForegroundColor Green
            DisconnectVIServer
            exit
        }
    }
}
Else{
    Write-Host "`nNo Snapshots found older than $daystokeep day(s). (total number of snapshots:"$snapshotlistall.count")." -ForegroundColor Green
    # no worky --> fix output to file
    #Write-Output "`nNo Snapshots found older than $daystokeep day(s). (total number of snapshots:"$snapshotlistall.count")." | Export-Csv $LogPath\"$date"_Snapshots_1beforecleanup_"$vCenter".csv -Append
    Write-Output "`nNo Snapshots found older than $daystokeep day(s). (total number of snapshots:"$snapshotlistall.count")." | Add-Content -Path $LogPath\"$date"_Snapshots_1beforecleanup_"$vCenter".csv
    # no worky --> fix output to file
    Write-Host "`nExiting....." -ForegroundColor Green
    DisconnectVIServer
    exit
}



# ----------- deletion part -----------

Write-Host "`nStarting snapshot cleanup part." -ForegroundColor Red
# Loop through the snapshots
foreach ($snapshot in $snapshotlistolderthanxdays)
{
# Get the description
$snapshotname = $snapshot.Name
    # Check if the name does not contain excludekeyword name
    if ($snapshotname -notlike "$excludekeyword") { 
        #Write-host $Snapshot
        Write-Host "`nDeleting snapshot: $($snapshot.VM)"-ForegroundColor Green " ,Name: $($snapshot.Name)" " ,Description: $($snapshot.Description)" " ,Created: $($snapshot.created)"
        Remove-Snapshot -Snapshot $snapshot -Confirm:$false -runasync:$false #-WhatIf
    }
}

    # generate list of all snapshots
    $snapshotlistall = get-snapshot -vm $AllowedVMs | Select-Object VM, SizeMB,Created, @{Name="Age in days";Expression={((Get-Date)-$_.Created).Days}}, Name, Description
    # recalculate snapshotlistolderthanxdays to print all vms older than x days (should be 0)
    $snapshotlistolderthanxdays = get-snapshot -vm $AllowedVMs | Where-Object {$_.Created -lt (Get-Date).AddDays(-$daystokeep)}

    if ($null -eq $snapshotlistall) {
        Write-Output "`nNo Snapshots found older than $daystokeep day(s). (total number of snapshots:"$snapshotlistall.count")." | Add-Content -Path $LogPath\"$Date"_Snapshots_2aftercleanup_"$vCenter".csv
    }else {
        Write-Output $snapshotlistall | Export-Csv -Path $LogPath\"$Date"_Snapshots_2aftercleanup_"$vCenter".csv -Append -NoClobber -NoTypeInformation
    }
    Write-Host "`nCurrent number of Snapshots in `"$vCenter`" after cleanup, older than $daystokeep day(s):"$snapshotlistolderthanxdays.count". (total number of snapshots:"$snapshotlistall.count")." -ForegroundColor Red







DisconnectVIServer
LogCleanup

#End of Script
Write-Host "`nAll actions finished. Ending script." -ForegroundColor Green
# End of script
# #####################################################################################################################

