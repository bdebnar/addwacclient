<# .SYNOPSIS
     Simple script to add new Windows Admin Center (WAC) client.
.DESCRIPTION
	The script try to connect to the CLIENT and enable a few things so you can add your CLIENT to the WAC later.

	--Target COMPUTERNAME
		COMPUTERNAME where the script try to connect and enable the required things.
	--SearchBase FULLDN
		FULLDN is where the script search for computers.
	--Autoprocess BOOLEAN
		$true or $false. If it's true the script won't ask for confirmation before the process.
	--AddFirewallException BOOLEAN
		If it's $true then itt will manually add a firewall exception for the port 5986/TCP from $firewallExceptionSource to the local Windows Defender Firewall\
	If no parameter was given it interprets the first argument as a --target parameter.

.NOTES
     Author: bdebnar
     Version 
        0.1: Initial release
.EXAMPLE
    .\addWacClient --target ketske
		Enable WAC requirements on ketske host.
	.\addWacClient --target ketske --AddFirewallException $true
		Enable WAC requirements on ketske host also open port 5986/TCP
	.\addWacClient --SearchBase "ou=computer,dc=example,dc=hu" --AutoProcess $true
		Enable WAC requirement on every computer in "ou=computer,dc=example,dc=hu", and don't ask for confirmation.
	
#>
Param(
    [Parameter(Mandatory = $False, Position = 0)][String]$Target,
    [Parameter(Mandatory = $False)][String]$SearchBase,
    [Parameter(Mandatory = $False)][Boolean]$AutoProcess,
    [Parameter(Mandatory = $False)][Boolean]$AddFirewallException
)

#----------------PLEASE MODIFY THIS FIRST-----------------------------
$firewallExceptionSource = "<IP of your computer where the WAC is running, it's optional>"
$wacComputerName = "<Name of the computer where the WAC is running>"
$domainSuffix = "<your internal domain name>"
#
#
# Don't modify anything after this, unless you know what are you doing.
#
#

if($wacComputerName -like "<*") {
	Write-Error "Please modify the init vars!"
	exit 1
}

if ($Target -and $SearchBase) {
    Write-Host -ForegroundColor Red "Target or SearchBase as a parameter. Not both."
    exit 1
}

if (!($Target -or $SearchBase)) {
    if (!$Target) {
        Write-Host -ForegroundColor RED "No computer was given as an argument."
        exit 1
    }
}

if ($Target) {
    try {
        $Servers = Get-ADComputer $Target
    }
    catch {
        Write-Host -ForegroundColor RED "Invalid computername..."
        exit 1
    }
}

If ($SearchBase) {
    try {
        $Servers = Get-ADComputer -SearchBase $SearchBase -Filter * | select-object name -expandproperty name
    }
    catch {
        Write-Host -ForegroundColor Red "Invalid searchbase"
        exit 1
    }
} 

foreach ($server in $servers ) {

    $computerinfo = get-adcomputer $server -Properties lastlogontimestamp
    $lastlogontimestamp = [datetime]::FromFileTime($computerinfo.lastlogontimestamp).ToString('g')
    if (!($AutoProcess)) {
        do {
            Write-Host -NoNewline "Process on computer named $($server.Name)? Last logon: $($lastlogontimestamp) [ESC-next computer, SPACE-OK]"
            $keyinput2 = $host.ui.rawui.readkey("IncludeKeyDown")

        } while (!(($keyinput2.VirtualKeyCode -ne 32) -xor ($keyinput2.VirtualKeyCode -ne 27)))
	
        if ($keyinput2.VirtualKeyCode -eq 27) {
            Write-Host "s"
            continue 
        }
    }
	
    Write-Host ""
    Write-Host -ForegroundColor Gray "Set-up winrm on $($server.name)..."

    $Result = Invoke-Command -ComputerName $Server.name -ScriptBlock { 
        $RCertificate = Get-Item Cert:\LocalMachine\My\* | ? { $_.Subject -like "CN=$($ENV:Computername).$($domainSuffix)*" }
        if ( $RCertificate ) {
            #Write-Host $RCertificate
            if ((winrm enumerate winrm/config/listener | findstr Transport) -like "*HTTPS*") {
                Return "OK HTTPS already enabled"
            }
            else {
                winrm quickconfig -transport:https -quiet
            }
        }
        else {
            Return "Can't find certificate"
        }
        Return "OK"
        Remove-Variable RCertificate
        
    }
    if ($Result -like "OK*") {
        if (Get-ADComputer $server -Properties PrincipalsAllowedToDelegateToAccount | ? { $_.PrincipalsAllowedToDelegateToAccount -like "*$($wacComputerName)*" }) {
            Write-Host "`t· SSO OK"
        }
        else {
            $ServerMod = Get-ADComputer -Identity $server
            $ServerWAC = Get-ADComputer -Identity admints
            Set-ADComputer -Identity "$ServerMod" -PrincipalsAllowedToDelegateToAccount "$ServerWAC"
            Write-Host "`t· SSO Enabled" -ForegroundColor DarkYellow
        }
        
        Write-Host "`t·"$Result -ForegroundColor Green

        if ($AddFirewallException) {                
            $FwResult = Invoke-Command -ComputerName $Server.name -ScriptBlock { 

                param($firewallExceptionSourceRemote)
                
                try {
                    $fwruleExists = Get-NetFirewallRule -DisplayName "WinRM Port - CUSTOM" -ErrorAction Stop
                }
                catch {
                    $fwruleExists = $null
                }
                if ($fwruleexists) {
                    Return "OK - Firewall exception already exists"
                }
                else {
                    $res = New-NetFirewallRule -DisplayName "WinRM Port - CUSTOM" -Direction Inbound -Action Allow -EdgeTraversalPolicy Allow -Protocol TCP -Localport 5986 -Remoteaddress $firewallExceptionSourceRemote
                    Return $res
                }
            

            
            } -ArgumentList $firewallExceptionSource
            if ($FwResult) {
                Write-Host "`t·Firewall was configured" -ForegroundColor Green
            }
            else {
                Write-Host "`t·Cant add exception to the firewall" -ForegroundColor Red
            }

        } 

        $processedServers += $server.DNSHostName + ".$($domainSuffix)`n"
        Remove-Variable Result
    
    }

}
