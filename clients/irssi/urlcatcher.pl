#!/usr/bin/perl -w

use strict;
use DBI;
use XML::Simple;
# use Data::Dumper;

my $xml_settings =XMLin("/home/iain/.irssi/scripts/urlcatcher_settings.xml", forcearray => ['channel']);
my $table_prefix = ($xml_settings->{database}->{table_prefix} != "\@NULL\@") ? $xml_settings->{database}->{table_prefix} : "";
my $dbh;

use vars qw($VERSION %IRSSI);

use Irssi qw(command_bind signal_add);
$VERSION = '0.1';
%IRSSI = (
    name        => 'URL catcher',
    authors     => 'Iain Cuthbertson',
    contact     => 'iain@urlcatcher.org',
    url			=> 'http://urlcatcher.org/',
    license     => 'GPL',
    description => 'Watches set channel(s) for URLS and stores them in a MySQL database.',
);

sub db_open {
    my $db;
	$db->{host} = $xml_settings->{database}->{db_host};
	$db->{database} = $xml_settings->{database}->{db_name};
	$db->{username} = $xml_settings->{database}->{db_user};
	$db->{password} = $xml_settings->{database}->{db_pass};

    $dbh = DBI->connect("dbi:mysql:database=$db->{database};host=$db->{host}",$db->{username},$db->{password});
    $dbh->do("SET NAMES 'utf8'");
}

sub db_close {
    $dbh->disconnect;
}

sub handle_self {
    my ($var1, $var2, $var3) = @_;

    my $server = $_[1]->{tag};
    my $msg = $_[0];
    my $nick = $_[1]->{nick};
    my $target = $_[2]->{name};

    check_line($server, $msg, $nick, $target);    
}

sub handle_remote {
	my ($server, $msg, $nick, $address, $target) = @_;
	
	check_line($server->{tag}, $msg, $nick, $target);
}

sub check_line {
	my ($server, $msg, $nick, $target) = @_;
	
	my $urls = '(http|https|telnet|gopher|file|wais|ftp)';
	my $ltrs = '\w';
	my $gunk = '/#~:.?+=&;%@!\-';
	my $punc = '.:?\-';
	my $any  = "${ltrs}${gunk}${punc}";

    my $ignore_list = "(http://urlcatcher.org|http://www.urlcatcher.org)"; # eg: "(http://goatse.cx/|http://www.google.com/)";

	if (($msg !~ /$ignore_list/) && ($msg =~ /\b($urls:[$any]+?)(?=[$punc]*[^$any]|$)/igo)) {
		# The current line contains a URL.  Record it for 
		record_url($server, $msg, $nick, lc($target));
	}
}

sub record_url {
	my ($server, $msg, $nick, $target) = @_;
	# Check if $server and $target are a network/channel pair to watch
	
	my $continue = 0;
	if (defined($xml_settings->{server}->{$server})) {
	    for (my $i = 0; $i < @{$xml_settings->{server}->{$server}->{channel}}; $i++) {
	        if (lc($xml_settings->{server}->{$server}->{channel}->[$i]) eq $target) {
                $continue = 1;
                last;
	        }
        }
	}
	
	if ($continue == 0) {
	    return;
	} else {
	    db_open();
	    my $sql;
	    my $result;
	    my $channel_id = "";
	    my $user_id = "";

	    # Check if $target is in the database
	    $sql = "SELECT id FROM " . $table_prefix . "channels WHERE name = '" . $target . "' AND server = '" . $server . "';";
	    my $channel_data  =  $dbh->selectrow_hashref($sql);
	    
	    if (!defined($channel_data)) {
	        $sql = "INSERT INTO " . $table_prefix . "channels (name, server) VALUES ('" . $target . "', '" . $server . "');";
	        $result = $dbh->do($sql);
	        if ($result) {
                Irssi::print("Added channel: " . $target . " / " . $server);
                $channel_id = $dbh->last_insert_id(undef, undef, undef, undef);
	        }
	    } else {
	        $channel_id = $channel_data->{id};
	    }

	    # Check if $nick is in the database
	    $sql = "SELECT id FROM " . $table_prefix . "users WHERE nick = '" . $nick . "';";
	    my $user_data = $dbh->selectrow_hashref($sql);
	    
	    if(!defined($user_data)) {
	        $sql = "INSERT INTO " . $table_prefix . "users (nick, created_when) VALUES ('" . $nick . "', NOW());";
	        $result = $dbh->do($sql);
	        if ($result) {
                Irssi::print("Added user: " . $nick . " whilst watching " . $target . " / " . $server);
                $user_id = $dbh->last_insert_id(undef, undef, undef, undef);
	        }
	    } else {
	        $user_id = $user_data->{id};
	    }

        # Last of all, enter the whole message line into the urls table
        if (($channel_id ne "") && ($user_id ne "")) {
            $sql = "INSERT INTO " . $table_prefix . "urls (channel_id, created_when, user_id, message_line) VALUES (" . $channel_id . ", NOW(), " . $user_id . ", '" . sanitise($msg) . "');";
	        $result = $dbh->do($sql) or Irssi::print("SQL Error: " . $sql);
	        if ($result) {
                Irssi::print("Added URL from " . $nick . " whilst watching " . $target . " / " . $server);
	        }
        }
	    
	    db_close();
	}
	
    sub sanitise {
        my $text = $_[0];

        $text =~ s/\'/\\\'/g;
        $text =~ s/\"/\\\"/g;

        my $colourCode = chr(3);
        $text =~ s/$colourCode\d{1,2}(,\d{1,2})*//g;

        my $boldCode = chr(2);
        $text =~ s/$boldCode//g;

        return $text;
    }
}

# Check what we've been saying
Irssi::signal_add('send text', 'handle_self');
#Irssi::signal_add('message irc own_action', 'handle_self_action');

# Check what other people are saying
Irssi::signal_add('message public', 'handle_remote');
Irssi::signal_add('message irc action', 'handle_remote');
