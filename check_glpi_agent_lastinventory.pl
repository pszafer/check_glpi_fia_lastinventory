#!/usr/bin/perl -w
############################## check_glpi_fia_lastinventory ##############
# Short description : Check last inventory of GLPI Agent via GLPI for Icinga2/Nagios
# Version : 0.0.1
# Date :  March 2023
# Author  : Pawel Szafer ( pszafer@gmail.com )
# Help : http://github.com/pszafer/
# Licence : GPL
#################################################################
#
# help : ./check_glpi_agent_lastinventory -h


use Getopt::Long;
use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Headers;
use JSON;
use URI;
use URI::Split qw(uri_join);
use Data::Dumper;
my $json  = JSON->new->utf8;
use Time::Local;
my $mon_dir = "/usr/lib/monitoring-plugins";
if (-d $mon_dir){
	use lib "/usr/lib/monitoring-plugins";
}
else {
	use lib "/usr/lib/nagios/plugins";
}
use utils qw(%ERRORS $TIMEOUT);


my $name = "check_glpi_agent_lastinventory";
my $version = "0.0.1";

sub print_version {
	print "$name version : $version\n";
}

sub print_usage {
	print "Usage: $name [-v] [-h] -H <host_target> -G <glpi_api_httpserver> -A <authorization user_token> -T <app-token> [-w <warn_level>] [-c <crit_level>] [-U <units_level>] [-t <timeout>]\n";
}

sub help {
	print_usage();
	print <<EOT;
	This plugin is intended to use with NRPE - Nagios/Icinga and GLPI Agent.
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
		-N - computer name
		-E - entity name
		-G - glpi api server with https and slash in the end - you can find out your GLPI api server on your glpi config site in API section
		-A - authorization user_token - you can create it in your profile preference in GLPI site.
		-T - app-token -  you can create in from your glpi config site, in API section
EOT
}

my %OPTION = (
	'help' => undef,
	'verbose' => -1,
	'apiurl' => undef,
	'unit' => 'M',
	'critical' => 3,
	'warning' => 2,
);

sub change_to_seconds {
	my ($value, $unit) = @_;
	for ($unit) {
		if (/M/) {
			return time - ($value * 30 * 24 *  60 * 60); #months * days * hours * minutes * seconds
		}
		elsif (/W/) {
			return time - ($value * 7 * 24 * 60 * 60);
		}
		elsif (/D/) {
			return time - ($value * 24 * 60 * 60);
		}
		elsif (/H/) {
			return time - ($value * 60 * 60);
		}
	}

}
sub check_options {
	Getopt::Long::Configure("bundling");
	GetOptions(
		'v' => \$OPTION{verbose},	'verbose'	=> \$OPTION{verbose},
		'h' => \$OPTION{help},		'help'		=> \$OPTION{help},
		'V' => \$OPTION{version},	'version'	=> \$OPTION{version},
		'N:s' => \$OPTION{host},	'host:s'	=> \$OPTION{host},
		'E:s' => \$OPTION{entity},	'entity:s'	=> \$OPTION{entity},
		'c:i'	=> \$OPTION{critical},	'critical:i'	=> \$OPTION{critical},
		'w:i'	=> \$OPTION{warning},	'warning:i'	=> \$OPTION{warning},
		'G:s' => \$OPTION{apiurl}, 	'url:s'		=> \$OPTION{apiurl},
		'A:s' => \$OPTION{user_token},	'usertoken:s'	=> \$OPTION{user_token},
		'T:s' => \$OPTION{app_token},	'apptoken:s'	=> \$OPTION{app_token},
		'U:s' => \$OPTION{unit},	'units:s'	=> \$OPTION{unit}
	);

	if (defined($OPTION{help})){ print "help";
	      print $OPTION{help};	
		help();
		exit $ERRORS{"UNKNOWN"};
	}
	if (defined($OPTION{version})) {
		print_version();
		exit $ERRORS{"UNKNOWN"};
	}
	my $print_usage = 0;
	if (
		(!defined($OPTION{critical})) || (!defined($OPTION{warning})) ||
		(!defined($OPTION{apiurl})) || (!defined($OPTION{host})) ||
		(!defined($OPTION{user_token})) || (!defined($OPTION{app_token}))
		
	   )
	{
		$print_usage = 1;
	}
	if ($print_usage) {
		print "Not all options are defined\n";
		print_usage();
		exit $ERRORS{"UNKNOWN"};
	}
	$OPTION{critical} = change_to_seconds($OPTION{critical}, $OPTION{unit});
	$OPTION{warning} = change_to_seconds($OPTION{warning}, $OPTION{unit});
	
}

check_options();

my $initSessionURL = $OPTION{apiurl}."/initSession";
my $app_token = HTTP::Headers->new();
$app_token->header("Authorization" => "user_token $OPTION{user_token}");
$app_token->header("App-Token" => $OPTION{app_token});
my $request = HTTP::Request->new('GET', $initSessionURL, $app_token);
my $ua = LWP::UserAgent->new;
my $response = $ua->request($request);
$response->is_success or die($response->status_line);


my $json_session = $json->decode($response->decoded_content);
my $session_token = $json_session->{session_token};
my $searchComputerURL = $OPTION{apiurl}."/search/Computer";


$app_token->header(
	"Session-Token" => $session_token	
);
my $hostname = "";
if ($OPTION{host}=~/(.*?)\.(.*)/){
	$hostname = $1;
}
else {
	$hostname = $OPTION{host};
}

my @criteria = (
	{
		link => "AND",
		field => 1,  
		searchtype => "contains",
		value => "$hostname",
	},
	{
		link => "AND",
		field => 80,
		searchtype => "contains",
		value => "$OPTION{entity}", 
	},
	{
		link => "AND",
		field => 9,
		searchtype => "contains",
		value => "", 
	},
);


my $criteria_query = "";
my $index = 0;
for my $element (@criteria){
	for my $key (keys %$element){
		$criteria_query .= "criteria[$index][$key]=$element->{$key}&";
	}
	++$index;
}
my $query_url = "$searchComputerURL?$criteria_query";
substr($criteria_query, -1)= '';
my $request_search = HTTP::Request->new('GET', $query_url, $app_token);
$response = $ua->request($request_search);
if (! $response->is_success) {
	print "CRITICAL - FIA doesn't exist for this host! ".$response->status_line;
	exit $ERRORS{"CRITICAL"};
	}
my $computer_status = decode_json($response->decoded_content);
my $totalcount = $computer_status->{totalcount};
my $lastinventory; 
if ($totalcount == 0){
	print "UNKNOWN - no response for such host";
     	exit $ERRORS{"UNKNOWN"};
}
for my $item( @{$computer_status->{data}} ) {
	if (lc $item->{1} eq lc $OPTION{host}){
		$lastinventory = $item->{9};
	}
}
if (!(defined($lastinventory))){
	print "WARNING no date of last inventory";
     	exit $ERRORS{"WARNING"};
} 
my ($yyyy, $mm, $dd, $hh, $min, $ss) = $lastinventory =~ /(\d+)-(\d+)-(\d+) (\d+):(\d+):(\d+)/;
my $timelocal = timelocal($ss, $min, $hh, $dd, $mm-1, $yyyy);
my $secondsfromlast = time - $timelocal;
my $perfwarn = time - $OPTION{warning};
my $perfcrit = time - $OPTION{critical};
my $perfdata = "lastseen=$secondsfromlast"."s;$perfwarn;$perfcrit";
		if ($timelocal < $OPTION{critical}) {
			print "FusionInventory Agent Last Inventory - CRITICAL - $lastinventory of $OPTION{host} | $perfdata\n";
			exit $ERRORS{"CRITICAL"};
		}
		elsif ($timelocal < $OPTION{warning}) {
			print "FusionInventory Agent Last Inventory - WARNING - $lastinventory of $OPTION{host} | $perfdata\n";
			exit $ERRORS{"WARNING"};
		}
		else {
			print "FusionInventory Agent Last Inventory - OK - $lastinventory of $OPTION{host} | $perfdata\n";
			exit $ERRORS{"OK"};
		}
