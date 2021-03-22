# check_glpi_fia_lastinventory

Check last inventory of FusionInventory Agent via GLPI for Icinga2/Nagios
It helps integrate Icinga2/Nagios with GLPI / FIA software.

This plugin is intended to use with NRPE - Nagios/Icinga and GLPI/FusionInventory Agent.
You can check when computer was last time connected to GLPI and set up proper alarm in Icinga/Nagios.

Warning and critical can be in S - seconds, H - hours, D- days, W - weeks, M - months

To set S, etc. set Unit option to S, H, D, W or M.  
Default values are:

           - Units - M,
           - Critical - 3,
           - Warning - 2

It means that plugin will return Critical if computer was last inventored more than 3 months ago and will return Warning if it was 2 months.
Warning have to be smaller than critical!

        Required parameters:
                -H target host/computer FQDN to check. I will split hostname and domain name and search through glpi with those 2 parameters so only one result will be returned,
                -G - glpi api server with https and slash in the end - you can find out your GLPI api server on your glpi config site in API section
                -A - authorization user_token - you can create it in your profile preference in GLPI site.
                -T - app-token -  you can create in from your glpi config site, in API section

# Installation

Simply put check_glpi_fia_lastinventory.pl file in your nrpe/monitoring-plugins plugins DIR.
Newest commit on master: GLPI >= 9.5
Check older commit for GLPI 9.4 support.

# Sample config for Icinga

##### CheckCommand

```
object CheckCommand "check_lastinventory" {
  import "plugin-check-command"
  import "ipv4-or-ipv6"
  command = [ PluginDir + "/check_glpi_fia_lastinventory.pl" ]
  arguments = {
    "-H" = "$host_address$"
    "-G" = "$glpi_apiurl$"
    "-A" = "$glpi_usertoken$"
    "-T" = "$glpi_apptoken$"
  }
  vars.host_address = "$check_address$"
  vars.glpi_apiurl = "https://glpi/apirest.php/"
  vars.glpi_usertoken = "usertoken"
  vars.glpi_apptoken = "apptoken"
}
```

##### Service definition

```
apply Service "Check_LastInvFIA"{
  import "generic-service"
  check_command = "check_lastinventory"
  vars.host = host.address
  assign where host.vars.fia
}
```

### Host definition

```
object Host hostname {
 address = "fqdn"
 vars.fia = true
}
```

## Based on GPL license.
