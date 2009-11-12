#
# URL catcher
# This is an irssi script that watches configured channel(s) for URLS and stores them in a MySQL database.
#
# Usage: 
#	1) Save this script in ~/.irssi/scripts
#	2) Start irssi
#	3) /script load urlcatcher
#   4) Change config with /set commands
#

use strict;
use warnings;

use DBI;

use vars qw($VERSION %IRSSI);
$VERSION = '0.3';
%IRSSI = (
	name		=> 'URL catcher',
	authors		=> 'Iain Cuthbertson',
	contact		=> 'iain@urlcatcher.org',
	url 		=> 'http://urlcatcher.org/',
	license		=> 'GPL',
	description	=> 'Watches configured channel(s) for URLS and stores them in a MySQL database.',
);
use Irssi qw(signal_add);

our %storage_cache;



sub handle_self 
{
	my $network = $_[1]->{tag};
	my $channel = $_[2]->{name};
	my $nick = $_[1]->{nick};
	my $msg = $_[0];

	if (check_msg($network, $channel, $nick, $msg)) {
		submit_url($network, $channel, $nick, $msg);
	}
}

sub handle_remote 
{
	my $network = $_[0]->{tag};
	my $channel = $_[4];
	my $nick = $_[2];
	my $msg = $_[1];

	if (check_msg($network, $channel, $nick, $msg)) {
		submit_url($network, $channel, $nick, $msg);
	}
}

sub check_msg
{
	my $network = shift;
	my $channel = shift;
	my $nick = shift;
	my $msg = shift;

	if (!has_url($msg)) { return 0; }
	if (!is_watched_channel($network, $channel)) { return 0; }
	if (is_ignored_nick($nick)) { return 0; }
	if (is_msg_dupe($network, $channel, $nick, $msg)) { return 0; }

	return 1;
}

sub is_msg_dupe
{
	my $network = shift;
	my $channel = shift;
	my $nick = shift;
	my $msg = shift;

	my $last_msg = cache_get("lastmsg:$network/$channel/$nick");
	if (defined($last_msg) and ($last_msg eq $msg)) { 
		Irssi::print("Ignoring duplicate message from $nick."); 
		return 1; 
	}

	return 0;
}

#sub get_urls 
#{
#	my $text = shift;
#
#	my $urls = '(http|https|ftp|spotify)';
#	my $ltrs = '\w';
#	my $gunk = '/#~:.?+=&;%@!\-';
#	my $punc = '.:?\-';
#	my $any  = "${ltrs}${gunk}${punc}";
#
#    $_ = $text;
#	my @matches = m/\b($urls:[$any]+?)(?=[$punc]*[^$any]|$)/igo;
#
#	my $ignore_urls_list = Irssi::settings_get_str('ignore_urls');
#
#    @matches = grep(!/($ignore_urls_list)/, @matches);
#
#    # hack hack hack
#    # @matches contains an element that is just the url protocol, e.g. ^http$
#    # better to fix the above regex so it doesn't match than weed it out here
#    @matches = grep(!/^$urls$/, @matches);
#
#	return @matches;
#}

sub has_url 
{
	my $text = shift;

	my $urls = '(http|https|ftp|spotify)';
	my $ltrs = '\w';
	my $gunk = '/#~:.?+=&;%@!\-';
	my $punc = '.:?\-';
	my $any  = "${ltrs}${gunk}${punc}";

	if ($text !~ m/\b($urls:[$any]+?)(?=[$punc]*[^$any]|$)/igo) {
		return 0;
	}

	my $ignore_urls = Irssi::settings_get_str('ignore_urls');
	if ($text =~ m/($ignore_urls)/i) { return 0; }

	return 1;
}

sub is_watched_channel
{
	my $needle_network = lc(shift);
	my $needle_channel = lc(shift);

	my $channel_list = Irssi::settings_get_str('channels');
    $channel_list =~ s/^\s*|\s*$//g;

    if (($channel_list eq '') or ($channel_list eq '*')) { return 1; }

	my @watched_channels = split(/;/, $channel_list);

	foreach my $watched_channel (@watched_channels) {
		my @pair = split(/\//, $watched_channel);
        if (scalar(@pair) != 2) { next; }

		my $network  = lc($pair[0]);
		my $channel = lc($pair[1]);
		$network  =~ s/\s*//g;
		$channel =~ s/\s*//g;

		if (($needle_network eq $network) and ($needle_channel eq $channel)) {
			return 1;
		}
	}

	return 0;
}

sub is_ignored_nick
{
	my $needle_nick = lc(shift);

	my @nicks = split(/,/, Irssi::settings_get_str('ignore_nicks'));

	foreach my $nick (@nicks) {
		$nick = lc($nick);
		$nick  =~ s/\s*//g;

		if ($needle_nick eq $nick) {
			return 1;
		}
	}

	return 0;
}

sub submit_url 
{
	my ($network, $channel, $nick, $msg) = @_;

	my $dbh = db_open();

	$msg = sanitise($msg);

    my $rv = db_insert_url($dbh, $network, $channel, $nick, $msg);
    if (!$rv) { return 0; }
	Irssi::print("Submitted URL from $nick on $network/$channel");

	cache_set("lastmsg:$network/$channel/$nick", $msg);

	db_close($dbh);

	return 1;
}

sub db_open 
{
	my $data_source = sprintf('dbi:%s:database=%s;host=%s;port=%u', 
		Irssi::settings_get_str('storage_method'), 
		Irssi::settings_get_str('storage_database'), 
		Irssi::settings_get_str('storage_hostname'), 
		Irssi::settings_get_int('storage_port'));

	my $dbh = DBI->connect($data_source, Irssi::settings_get_str('storage_username'), Irssi::settings_get_str('storage_password'));

	if (!defined($dbh) or !$dbh) { 
		die(sprintf("ERROR: Could not connect to database '%s' on '%s' as user '%s'. Message: %s\n", 
				Irssi::settings_get_str('storage_database'), 
				Irssi::settings_get_str('storage_hostname'), 
				Irssi::settings_get_str('storage_username'), 
				$DBI::errstr));
	}

	$dbh->do("SET NAMES 'utf8'");

	return $dbh;
}

sub db_close { my $dbh = shift; $dbh->disconnect; }

sub db_insert_url
{
    my $dbh = shift;
    my $network = shift;
    my $channel = shift;
    my $nick = shift;
    my $msg = shift;

    my $pool_table_name = Irssi::settings_get_str('storage_table_prefix') . 'pool';
    my $client_id = Irssi::settings_get_str('storage_client_id');
    if (!$client_id) { 
		Irssi::print("ERROR: Tried to submit without a client id. \"/set client_id <value>\" first.");
        return 0; 
    } 
    
	my $sth = $dbh->prepare("
        INSERT INTO $pool_table_name 
        (client_id, network, channel, nick, message, created_at) 
        VALUES (?, ?, ?, ?, ?, NOW())");
	my $rv = $sth->execute($client_id, $network, $channel, $nick, $msg);

	if (!defined($rv)) {
		Irssi::print("ERROR: Execute of INSERT query to pool table failed in db_insert_url.");
		return 0;
	}

    return 1;
}

sub cache_get
{
	my $key = shift;

	if (exists($storage_cache{$key})) {
		return $storage_cache{$key};
	} else {
        return undef;
    }
}

sub cache_set
{
	my $key = shift;
	my $value = shift;

	$storage_cache{$key} = $value;
}

sub sanitise 
{
	my $text = shift;

	my $colour_code = chr(3);
	$text =~ s/$colour_code\d{1,2}(,\d{1,2})*//g;

	my $bold_code = chr(2);
	$text =~ s/$bold_code//g;

	return $text;
}


Irssi::settings_add_str('urlcatcher', 'storage_method',    'mysql');
Irssi::settings_add_str('urlcatcher', 'storage_hostname',  'localhost');
Irssi::settings_add_int('urlcatcher', 'storage_port',      '3306');
Irssi::settings_add_str('urlcatcher', 'storage_database',  'urlcatcher');
Irssi::settings_add_str('urlcatcher', 'storage_username',  'uc_client');
Irssi::settings_add_str('urlcatcher', 'storage_password',  'mj5S53dSekO5');
Irssi::settings_add_str('urlcatcher', 'storage_table_prefix', '');
Irssi::settings_add_str('urlcatcher', 'storage_client_id', 'hiKUJEoLj-l2[grR');

# channels format     = NETWORK_1/CHANNEL_1; NETWORK_2/CHANNEL_2; NETWORK_N/CHANNEL_N; ...
Irssi::settings_add_str('urlcatcher', 'channels', 'dhbit/#humour; dhbit/#urlcatcher; freenode/#vim');
# ignore_nicks format = NICK_1,NICK_2,NICK_N,...
Irssi::settings_add_str('urlcatcher', 'ignore_nicks', 'nicks1,nick2,nick3');
# ignore_urls format  = URL_1|URL_2|URL_N|...
Irssi::settings_add_str('urlcatcher', 'ignore_urls', 'http://urlcatcher.org|http://www.urlcatcher.org|http://goatse.cx/');


# Check what we've been saying
Irssi::signal_add('send text', 'handle_self');

# Check what other people are saying
Irssi::signal_add('message public', 'handle_remote');
Irssi::signal_add('message irc action', 'handle_remote');

