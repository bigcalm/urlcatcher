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
$VERSION = '0.2';
%IRSSI = (
	name		=> 'URL catcher',
	authors		=> 'Iain Cuthbertson',
	contact		=> 'iain@urlcatcher.org',
	url 		=> 'http://urlcatcher.org/',
	license		=> 'GPL',
	description	=> 'Watches configured channel(s) for URLS and stores them in a MySQL database.',
);
use Irssi qw(signal_add);
#use Irssi;
#use Irssi::Irc;

our %storage_cache;



sub handle_self 
{
	my $network = $_[1]->{tag};
	my $channel = $_[2]->{name};
	my $nick = $_[1]->{nick};
	my $msg = $_[0];

	if (check_msg($network, $channel, $nick, $msg)) {
		record_url($network, $channel, $nick, $msg);
	}
}

sub handle_remote 
{
	my $network = $_[0]->{tag};
	my $channel = $_[4];
	my $nick = $_[2];
	my $msg = $_[1];

	if (check_msg($network, $channel, $nick, $msg)) {
		record_url($network, $channel, $nick, $msg);
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

	my $lastMsg = cache_get("lastmsg-$network-$channel-$nick");
	if (defined($lastMsg) and ($lastMsg eq $msg)) { 
		Irssi::print("Ignoring duplicate message from $nick."); 
		return 1; 
	}

	return 0;
}

sub has_url 
{
	my $msg = shift;

	my $urls = '(http|https|ftp|spotify)';
	my $ltrs = '\w';
	my $gunk = '/#~:.?+=&;%@!\-';
	my $punc = '.:?\-';
	my $any  = "${ltrs}${gunk}${punc}";

	if ($msg !~ m/\b($urls:[$any]+?)(?=[$punc]*[^$any]|$)/igo) {
		return 0;
	}

	my $ignore_urls = Irssi::settings_get_str('ignore_urls');
	if ($msg =~ m/($ignore_urls)/i) { return 0; }

	return 1;
}

sub is_watched_channel
{
	my $needle_network = lc(shift);
	my $needle_channel = lc(shift);

	my $channel_list = Irssi::settings_get_str('channels');
	my @watched_channels = split(/;/, $channel_list);

	foreach my $watched_channel (@watched_channels) {
		my @pair = split(/\//, $watched_channel);

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

sub record_url 
{
	my ($network, $channel, $nick, $msg) = @_;
	
	my $table_prefix = Irssi::settings_get_str('storage_table_prefix');

	my $dbh = db_open();

	my $channel_id = db_get_channel_id($dbh, $table_prefix, $network, $channel);
	if (!$channel_id) { return 0; }

	my $nick_id = db_get_nick_id($dbh, $table_prefix, $nick);
	if (!$nick_id) { return 0; }

	$msg = sanitise($msg);

	my $sth = $dbh->prepare("INSERT INTO $table_prefix" . "urls (channel_id, created_when, nick_id, message_line) VALUES (?, NOW(), ?, ?)");
	my $rv = $sth->execute($channel_id, $nick_id, $msg);
	if (!defined($rv)) {
		Irssi::print("ERROR: Execute of INSERT query failed in record_url.");
		return 0;
	}
	Irssi::print("Added URL from $nick whilst watching $channel ($network)");

	cache_set("lastmsg-$network-$channel-$nick", $msg);

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

sub db_get_channel_id
{
	my $dbh = shift;
	my $table_prefix = shift;
	my $network = shift;
	my $channel = shift;

	$network = lc($network);
	$channel = lc($channel);

	my $channel_id = cache_get("channel-$network-$channel");
	if (defined($channel_id)) { return $channel_id; }

	my $sth = $dbh->prepare("SELECT id FROM $table_prefix" . "channels WHERE (name=?) AND (network=?)");
	my $rv = $sth->execute($channel, $network);
	if (!defined($rv)) {
		Irssi::print("ERROR: Execute of SELECT query failed in db_get_channel_id.");
		return 0;
	}

	if (!$sth->rows) {
		$sth = $dbh->prepare("INSERT INTO $table_prefix" . "channels (name, network) VALUES (?, ?)");
		$rv = $sth->execute($channel, $network);
		if (!defined($rv)) {
			Irssi::print("ERROR: Execute of INSERT query failed in db_get_channel_id.");
			return 0;
		}
		if ($rv) {
			Irssi::print("Added channel: $channel ($network)");
			$channel_id = $dbh->last_insert_id(undef, undef, undef, undef);
		}
	} else {
		my @row = $sth->fetchrow_array();
		$channel_id = $row[0];
	}

	cache_set("channel-$network-$channel", $channel_id);

	return $channel_id;
}

sub db_get_nick_id
{
	my $dbh = shift;
	my $table_prefix = shift;
	my $nick = shift;

	my $nick_id = cache_get("nick-$nick");
	if (defined($nick_id)) { return $nick_id; }

	my $sth = $dbh->prepare("SELECT id FROM $table_prefix" . "nicks WHERE (nick=?)");
	my $rv = $sth->execute($nick);
	if (!defined($rv)) {
		Irssi::print("ERROR: Execute of SELECT query failed for db_get_nick_id.");
		return 0;
	}

	if (!$sth->rows) {
		$sth = $dbh->prepare("INSERT INTO $table_prefix" . "nicks (nick, created_when) VALUES (?, NOW())");
		$rv = $sth->execute($nick);
		if (!defined($rv)) {
			Irssi::print("ERROR: Execute of INSERT query failed in db_get_nick_id.");
			return 0;
		}
		if ($rv) {
			Irssi::print("Added nick: $nick");
			$nick_id = $dbh->last_insert_id(undef, undef, undef, undef);
		}
	} else {
		my @row = $sth->fetchrow_array();
		$nick_id = $row[0];
	}

	cache_set("nick-$nick", $nick_id);

	return $nick_id;
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


Irssi::settings_add_str('urlcatcher', 'storage_method',   'mysql');
Irssi::settings_add_str('urlcatcher', 'storage_hostname', 'localhost');
Irssi::settings_add_int('urlcatcher', 'storage_port',     '3306');
Irssi::settings_add_str('urlcatcher', 'storage_database', 'urlcatcher');
Irssi::settings_add_str('urlcatcher', 'storage_username', 'uc_client');
Irssi::settings_add_str('urlcatcher', 'storage_password', 'mj5S53dSekO5');
Irssi::settings_add_str('urlcatcher', 'storage_table_prefix', '');

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

