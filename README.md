# What's this
Simple script to add new Windows Admin Center (WAC) client.
# Install
Just copy somewhere and set the variables inside the scripts:

  - $firewallExceptionSource = IP of your computer where the WAC is running, it's optional
  - $wacComputerName = Name of the computer where the WAC is running
  - $domainSuffix = your internal domain name
# Usage:
  ```powershell
  .\addWacClient --Source [OPTION]... [CLIENT]...
  ```
# Description:
  Try to connect to the CLIENT and enable a few things so you can add your CLIENT to the WAC later.
  - `--Target COMPUTERNAME`
    - COMPUTERNAME where the script try to connect and enable the required things.
  - `--SearchBase FULLDN`
    - FULLDN is where the script search for computers.
  - `--Autoprocess BOOLEAN`
    - $true or $false. If it's true the script won't ask for confirmation before the process.
  - `--AddFirewallException BOOLEAN`
    - If it's $true then itt will manually add a firewall exception for the port 5986/TCP from $firewallExceptionSource to the local Windows Defender Firewall\
 
 If no parameter was given it interprets the first argument as a --target parameter.
 
 # Examples
  - `.\addWacClient --target ketske`
    - Enable WAC requirements on ketske host.
  - ` .\addWacClient --target ketske --AddFirewallException $true `
    - Enable WAC requirements on ketske host also open port 5986/TCP
  - `.\addWacClient --SearchBase "ou=computer,dc=example,dc=hu" --AutoProcess $true`
    - Enable WAC requirement on every computer in "ou=computer,dc=example,dc=hu", and don't ask for confirmation.
