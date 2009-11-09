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

	my $last_msg = cache_get("lastmsg:$network/$channel/$nick");
	if (defined($last_msg) and ($last_msg eq $msg)) { 
		Irssi::print("Ignoring duplicate message from $nick."); 
		return 1; 
	}

	return 0;
}

sub get_urls 
{
	my $text = shift;

	my $urls = '(http|https|ftp|spotify)';
	my $ltrs = '\w';
	my $gunk = '/#~:.?+=&;%@!\-';
	my $punc = '.:?\-';
	my $any  = "${ltrs}${gunk}${punc}";

    $_ = $text;
	my @matches = m/\b($urls:[$any]+?)(?=[$punc]*[^$any]|$)/igo;

	my $ignore_urls_list = Irssi::settings_get_str('ignore_urls');

    @matches = grep(!/($ignore_urls_list)/, @matches);

    # hack hack hack
    # @matches contains an element that is just the url protocol, e.g. ^http$
    # better to fix the above regex so it doesn't match than weed it out here
    @matches = grep(!/^$urls$/, @matches);

	return @matches;
}

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

sub record_url 
{
	my ($network, $channel, $nick, $msg) = @_;

	my $dbh = db_open();

	my $network_id = db_get_network_id($dbh, $network);
	if (!$network_id) { return 0; }

	my $channel_id = db_get_channel_id($dbh, $network_id, $channel);
	if (!$channel_id) { return 0; }

	my $nick_id = db_get_nick_id($dbh, $channel_id, $nick);
	if (!$nick_id) { return 0; }

	$msg = sanitise($msg);

    my $message_id = db_insert_url($dbh, $channel_id, $nick_id, $msg);
    if (!$message_id) { return 0; }
	Irssi::print("Added URL from $nick on $network/$channel");

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

sub db_get_network_id
{
	my $dbh = shift;
	my $network = shift;

	$network = lc($network);

	my $network_id = cache_get("network:$network");
	if (defined($network_id)) { return $network_id; }

    my $network_table_name = Irssi::settings_get_str('storage_table_prefix') . 'network';

	my $sth = $dbh->prepare("SELECT id FROM $network_table_name WHERE (name=?) LIMIT 1");
	my $rv = $sth->execute($network);
	if (!defined($rv)) {
		Irssi::print("ERROR: Execute of SELECT query failed in db_get_network_id.");
		return 0;
	}

	if (!$sth->rows) {
		$sth = $dbh->prepare("INSERT INTO $network_table_name (name) VALUES (?)");
		$rv = $sth->execute($network);
		if (!defined($rv)) {
			Irssi::print("ERROR: Execute of INSERT query failed in db_get_network_id.");
			return 0;
		}
		if ($rv) {
			$network_id = $dbh->last_insert_id(undef, undef, undef, undef);
            Irssi::print("Added network: $network");
		}
	} else {
		my @row = $sth->fetchrow_array();
		$network_id = $row[0];
	}

	cache_set("network:$network", $network_id);

	return $network_id;
}

sub db_get_channel_id
{
	my $dbh = shift;
	my $network_id = shift;
	my $channel = shift;

	$channel = lc($channel);

	my $channel_id = cache_get("channel:$network_id/$channel");
	if (defined($channel_id)) { return $channel_id; }

    my $channel_table_name = Irssi::settings_get_str('storage_table_prefix') . 'channel';

	my $sth = $dbh->prepare("SELECT id FROM $channel_table_name WHERE (network_id=?) AND (name=?)");
	my $rv = $sth->execute($network_id, $channel);
	if (!defined($rv)) {
		Irssi::print("ERROR: Execute of SELECT query failed in db_get_channel_id.");
		return 0;
	}

	if (!$sth->rows) {
		$sth = $dbh->prepare("INSERT INTO $channel_table_name (network_id, name) VALUES (?, ?)");
		$rv = $sth->execute($network_id, $channel);
		if (!defined($rv)) {
			Irssi::print("ERROR: Execute of INSERT query failed in db_get_channel_id.");
			return 0;
		}
		if ($rv) {
			$channel_id = $dbh->last_insert_id(undef, undef, undef, undef);
            Irssi::print("Added channel: $channel");
		}
	} else {
		my @row = $sth->fetchrow_array();
		$channel_id = $row[0];
	}

	cache_set("channel:$network_id/$channel", $channel_id);

	return $channel_id;
}

sub db_get_nick_id
{
	my $dbh = shift;
	my $network_id = shift;
	my $nick = shift;

	my $nick_id = cache_get("nick:$network_id/$nick");
	if (defined($nick_id)) { return $nick_id; }

    my $nick_table_name = Irssi::settings_get_str('storage_table_prefix') . 'nick';

	my $sth = $dbh->prepare("SELECT id FROM $nick_table_name WHERE (network_id=?) AND (nick=?)");
	my $rv = $sth->execute($network_id, $nick);
	if (!defined($rv)) {
		Irssi::print("ERROR: Execute of SELECT query failed for db_get_nick_id.");
		return 0;
	}

	if (!$sth->rows) {
		$sth = $dbh->prepare("INSERT INTO $nick_table_name (network_id, nick, created_at) VALUES (?, ?, NOW())");
		$rv = $sth->execute($network_id, $nick);
		if (!defined($rv)) {
			Irssi::print("ERROR: Execute of INSERT query failed in db_get_nick_id.");
			return 0;
		}
		if ($rv) {
			$nick_id = $dbh->last_insert_id(undef, undef, undef, undef);
            Irssi::print("Added nick: $nick");
		}
	} else {
		my @row = $sth->fetchrow_array();
		$nick_id = $row[0];
	}

	cache_set("nick:$network_id/$nick", $nick_id);

	return $nick_id;
}

sub db_insert_url
{
    my $dbh = shift;
    my $channel_id = shift;
    my $nick_id = shift;
    my $msg = shift;

    my $message_table_name = Irssi::settings_get_str('storage_table_prefix') . 'message';
    my $url_table_name = Irssi::settings_get_str('storage_table_prefix') . 'url';
    my $url_message_join_table_name = Irssi::settings_get_str('storage_table_prefix') . 'url_message_join';

	my $sth = $dbh->prepare("INSERT INTO $message_table_name (channel_id, created_at, nick_id, message_line) VALUES (?, NOW(), ?, ?)");
	my $rv = $sth->execute($channel_id, $nick_id, $msg);
	if (!defined($rv)) {
		Irssi::print("ERROR: Execute of INSERT query on message table failed in db_insert_url.");
		return 0;
	}

    my $message_id = $dbh->last_insert_id(undef, undef, undef, undef);
    if (!$message_id) {
        Irssi::print("ERROR: Failed to get last_insert_id in db_insert_url.");
        return 0;
    }

    my @urls = get_urls($msg);
    my $urls_inserted = 0;

    foreach my $url (@urls) {
#Irssi::print("DEBUG: url = $url");
        # get (or create if doesn't exist) the url_id 
        my $url_id = undef;
        $sth = $dbh->prepare("SELECT id FROM $url_table_name WHERE (url = ?)");
        $rv = $sth->execute($url);
        if (!defined($rv)) {
            Irssi::print("ERROR: Execute of SELECT query on url table failed in db_insert_url.");
            next;
        }
        if (!$sth->rows) {
#Irssi::print("DEBUG: url was NOT found in url table");
            $sth = $dbh->prepare("INSERT INTO $url_table_name (url, state_id) VALUES (?, 0)");
            $rv = $sth->execute($url);
            if (!defined($rv)) {
                Irssi::print("ERROR: Execute of INSERT query on url table failed in db_insert_url.");
                next;
            }
            if ($rv) {
                $url_id = $dbh->last_insert_id(undef, undef, undef, undef);
            }
        } else {
            my @row = $sth->fetchrow_array();
            $url_id = $row[0];
#Irssi::print("DEBUG: url was found in url table");
        }
#Irssi::print("DEBUG: url_id = $url_id");
        if (!defined($url_id) or !$url_id) {
            Irssi::print("ERROR: Invalid url_id in db_insert_url.");
            next;
        }

#Irssi::print("DEBUG: joining...");
        # join this url to the message
        $sth = $dbh->prepare("INSERT INTO $url_message_join_table_name (url_id, message_id) VALUES (?, ?)");
        $rv = $sth->execute($url_id, $message_id);
        if (!defined($rv)) {
            Irssi::print("ERROR: Execute of INSERT query on url_message_join table failed in db_insert_url.");
            next;
        }

        $urls_inserted++;
#Irssi::print("DEBUG: url complete");
    }

    if (!$urls_inserted) {
        return 0;
    } else {
        return $message_id;
    }
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

