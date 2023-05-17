<#
####################################################################################################################
Author:           Merckx Thomas
Changelog:
    20230124: initial version



Summary:          This script will take snapshots of all VM's listed in an input file.
####################################################################################################################
#>

# #####################################################################################################################
# Variables



$vCenter = "vCenter FQDN"



#$Credential = Get-Credential
#$Credential | Export-Clixml "Credentials-USER.xml"
$Credential = import-clixml "Credentials-USER.xml"


$logpath = "C:\Temp\Script_Logs"

$date = get-date -f yyyyMMdd_HHmm

$inputfile = "Snapshot-takesnapshots-input.csv"

$snapshotname = "Automated snapshot"
$snapsdescription = "Automated snapshot taken by script before intervention on VM."


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
    Write-Host "`nConnecting to vCenter `"$vCenter`"..." -ForegroundColor Green
    # Check if vCenter is already connected
    if (($global:DefaultVIServer).Name -ne $vCenter) {
        $VCConnection = Connect-VIServer -Server $vCenter -Credential $Credential -ErrorAction 'Stop' | Out-Null
        Write-Host ("`nSuccessfully Connected to vCenter Server `"$vCenter`"") -ForegroundColor Green
    }else {
        Write-Host ("`nAlready connected to `"$vCenter`"") -ForegroundColor Red
    }
    # Check the Connectivity of vCenter Server and terminate if not pingable
    if ( -not (Test-Connection -ComputerName $vCenter -Count 1 -Quiet) )
    {
        Write-Host "'nProvided vCenter Server # $vCenter # is Not Reachable, please enter a valid FQDN or IP Address"
        exit
    }
    # Reject participation in CEIP and ignore invalid certs
    #Import-Module vmware.powercli
    Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -confirm:$false -ErrorAction SilentlyContinue | Out-Null
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false  | Out-Null
}
function LogCleanup
{
    # Cleanup Snapshot logs older than 100 days.
    Get-ChildItem -path $logpath -Recurse -Force | Where-Object {!$_.PSIsContainer -and $_.LastWriteTime -lt (Get-Date).AddDays(-100)} | Remove-Item -Force
}

# End of function definition
# #####################################################################################################################

# #####################################################################################################################
# start of script


Clear-Host
Write-Host " "
Write-Host "######################## Snapshot-take snapshots.ps1 ##########################"
Write-Host " "
Write-Host "      This script will take snapshots of all VM's listed in an input file."
Write-Host " "
Write-Host "######################################################################"
Write-Host " "

# Verify if the log folder exists.
If(!(Test-Path $logpath)){
    Write-Host "Log path not found, creating folder."
    New-Item $logpath -Type Directory
}
Write-Host "Writing logs to: $logpath "

ConnectVIServer
# ---------------------------------------------------------------------------------------------------------------------







$VMinput = Get-Content $inputfile

Foreach ($VM in $VMinput)
{
    Write-Host "`nTaking snapshot of VM: $VM"
    New-Snapshot -VM $VM -Name $snapshotname"-"$date -Description $snapsdescription -confirm:$false -runasync:$false #-WhatIf

}






# ---------------------------------------------------------------------------------------------------------------------
DisconnectVIServer
LogCleanup


#End of Script
Write-Host "`nAll actions finished. Ending script." -ForegroundColor Green
# End of script
# #####################################################################################################################
