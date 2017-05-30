# check_glpi_fia_lastinventory
Check last inventory of FusionInventory Agent via GLPI for Icinga2/Nagios

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

Based on GPL license.
