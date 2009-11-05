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

our %storageCache;



sub handleSelf 
{
	my $network = $_[1]->{tag};
	my $channel = $_[2]->{name};
	my $nick = $_[1]->{nick};
	my $msg = $_[0];

	if (checkMsg($network, $channel, $nick, $msg)) {
		recordURL($network, $channel, $nick, $msg);
	}
}

sub handleRemote 
{
	my $network = $_[0]->{tag};
	my $channel = $_[4];
	my $nick = $_[2];
	my $msg = $_[1];

	if (checkMsg($network, $channel, $nick, $msg)) {
		recordURL($network, $channel, $nick, $msg);
	}
}

sub checkMsg
{
	my $network = shift;
	my $channel = shift;
	my $nick = shift;
	my $msg = shift;

	if (!msgHasURL($msg)) { return 0; }
	if (!isWatchedNetworkAndChannel($network, $channel)) { return 0; }
	if (isIgnoredNick($nick)) { return 0; }
	if (isMsgDupe($network, $channel, $nick, $msg)) { return 0; }

	return 1;
}

sub isMsgDupe
{
	my $network = shift;
	my $channel = shift;
	my $nick = shift;
	my $msg = shift;

	my $lastMsg = cacheGet("lastmsg-$network-$channel-$nick");
	if (defined($lastMsg) and ($lastMsg eq $msg)) { 
		Irssi::print("Ignoring duplicate message from $nick."); 
		return 1; 
	}

	return 0;
}

sub msgHasURL 
{
	my $msg = shift;

	my $urls = '(http|https|telnet|gopher|file|wais|ftp)';
	my $ltrs = '\w';
	my $gunk = '/#~:.?+=&;%@!\-';
	my $punc = '.:?\-';
	my $any  = "${ltrs}${gunk}${punc}";

	if ($msg !~ m/\b($urls:[$any]+?)(?=[$punc]*[^$any]|$)/igo) {
		return 0;
	}

	my $ignoreURLs = Irssi::settings_get_str('ignore_urls');
	if ($msg =~ m/($ignoreURLs)/i) { return 0; }

	return 1;
}

sub isWatchedNetworkAndChannel
{
	my $needleNetwork = lc(shift);
	my $needleChannel = lc(shift);

	my $channelList = Irssi::settings_get_str('channels');
	my @watchedChannels = split(/;/, $channelList);

	foreach my $watchedChannel (@watchedChannels) {
		my @pair = split(/\//, $watchedChannel);

		my $network  = lc($pair[0]);
		my $channel = lc($pair[1]);
		$network  =~ s/\s*//g;
		$channel =~ s/\s*//g;

		if (($needleNetwork eq $network) and ($needleChannel eq $channel)) {
			return 1;
		}
	}

	return 0;
}

sub isIgnoredNick
{
	my $needleNick = lc(shift);

	my @nicks = split(/,/, Irssi::settings_get_str('ignore_nicks'));

	foreach my $nick (@nicks) {
		$nick = lc($nick);
		$nick  =~ s/\s*//g;

		if ($needleNick eq $nick) {
			return 1;
		}
	}

	return 0;
}

sub recordURL 
{
	my ($network, $channel, $nick, $msg) = @_;
	
	my $tablePrefix = Irssi::settings_get_str('storage_table_prefix');

	my $dbh = dbOpen();

	my $channelId = dbGetChannelId($dbh, $tablePrefix, $network, $channel);
	if (!$channelId) { return 0; }

	my $nickId = dbGetNickId($dbh, $tablePrefix, $nick);
	if (!$nickId) { return 0; }

	$msg = sanitise($msg);

	my $sth = $dbh->prepare("INSERT INTO $tablePrefix" . "urls (channel_id, created_when, nick_id, message_line) VALUES (?, NOW(), ?, ?)");
	my $rv = $sth->execute($channelId, $nickId, $msg);
	if (!defined($rv)) {
		Irssi::print("ERROR: Execute of INSERT query failed in recordURL.");
		return 0;
	}
	Irssi::print("Added URL from $nick whilst watching $channel ($network)");

	cacheSet("lastmsg-$network-$channel-$nick", $msg);

	dbClose($dbh);

	return 1;
}

sub dbOpen 
{
	my $dataSource = sprintf('dbi:%s:database=%s;host=%s;port=%u', 
		Irssi::settings_get_str('storage_method'), 
		Irssi::settings_get_str('storage_database'), 
		Irssi::settings_get_str('storage_hostname'), 
		Irssi::settings_get_int('storage_port'));

	my $dbh = DBI->connect($dataSource, Irssi::settings_get_str('storage_username'), Irssi::settings_get_str('storage_password'));

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

sub dbClose { my $dbh = shift; $dbh->disconnect; }

sub dbGetChannelId
{
	my $dbh = shift;
	my $tablePrefix = shift;
	my $network = shift;
	my $channel = shift;

	$network = lc($network);
	$channel = lc($channel);

	my $channelId = cacheGet("channel-$network-$channel");
	if (defined($channelId)) { return $channelId; }

	my $sth = $dbh->prepare("SELECT id FROM $tablePrefix" . "channels WHERE (name=?) AND (network=?)");
	my $rv = $sth->execute($channel, $network);
	if (!defined($rv)) {
		Irssi::print("ERROR: Execute of SELECT query failed in dbGetChannelId.");
		return 0;
	}

	if (!$sth->rows) {
		$sth = $dbh->prepare("INSERT INTO $tablePrefix" . "channels (name, network) VALUES (?, ?)");
		$rv = $sth->execute($channel, $network);
		if (!defined($rv)) {
			Irssi::print("ERROR: Execute of INSERT query failed in dbGetChannelId.");
			return 0;
		}
		if ($rv) {
			Irssi::print("Added channel: $channel ($network)");
			$channelId = $dbh->last_insert_id(undef, undef, undef, undef);
		}
	} else {
		my @row = $sth->fetchrow_array();
		$channelId = $row[0];
	}

	cacheSet("channel-$network-$channel", $channelId);

	return $channelId;
}

sub dbGetNickId
{
	my $dbh = shift;
	my $tablePrefix = shift;
	my $nick = shift;

	my $nickId = cacheGet("nick-$nick");
	if (defined($nickId)) { return $nickId; }

	my $sth = $dbh->prepare("SELECT id FROM $tablePrefix" . "nicks WHERE (nick=?)");
	my $rv = $sth->execute($nick);
	if (!defined($rv)) {
		Irssi::print("ERROR: Execute of SELECT query failed for dbGetNickId.");
		return 0;
	}

	if (!$sth->rows) {
		$sth = $dbh->prepare("INSERT INTO $tablePrefix" . "nicks (nick, created_when) VALUES (?, NOW())");
		$rv = $sth->execute($nick);
		if (!defined($rv)) {
			Irssi::print("ERROR: Execute of INSERT query failed in dbGetNickId.");
			return 0;
		}
		if ($rv) {
			Irssi::print("Added nick: $nick");
			$nickId = $dbh->last_insert_id(undef, undef, undef, undef);
		}
	} else {
		my @row = $sth->fetchrow_array();
		$nickId = $row[0];
	}

	cacheSet("nick-$nick", $nickId);

	return $nickId;
}

sub cacheGet
{
	my $key = shift;

	if (exists($storageCache{$key})) {
		return $storageCache{$key};
	} else {
        return undef;
    }
}

sub cacheSet
{
	my $key = shift;
	my $value = shift;

	$storageCache{$key} = $value;
}

sub sanitise 
{
	my $text = shift;

	my $colourCode = chr(3);
	$text =~ s/$colourCode\d{1,2}(,\d{1,2})*//g;

	my $boldCode = chr(2);
	$text =~ s/$boldCode//g;

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
Irssi::signal_add('send text', 'handleSelf');

# Check what other people are saying
Irssi::signal_add('message public', 'handleRemote');
Irssi::signal_add('message irc action', 'handleRemote');

