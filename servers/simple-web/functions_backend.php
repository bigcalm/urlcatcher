<?php

/*
 *
 * Backend Functions
 *
 */


function get_urls($text)
{
    if (!$text) { return array(); }

	$urls = '(http|https|telnet|gopher|file|wais|ftp|spotify)';
	$ltrs = '\w';
	$gunk = '\\/#~:,.?+=&;%@!\-';
	$punc = ',.:?\-';
	$any  = "$ltrs$gunk$punc";

    $u = preg_match_all("/\b($urls:[$any]+?)(?=[$punc]*(?:[^$any]|$))/", $text, $matches);
    if ($u == 0) { return array(); }

    // warning: hacky hack hack
    array_shift($matches);
    $matches = array_shift($matches);

    // check we have a full url
    // todo: this could be cleaner
    $u = count($matches);
    for ($c = 0; $c < $u; $c++) {
        if (preg_match("/^$urls:[^$ltrs]+$/", $matches[$c])) {
            unset($matches[$c]);
            $u = count($matches);
            $c = 0;
        }
    }

    return $matches;
}

function cache_get($cache, $key)
{
    if (!is_array($cache)) { return 0; }
    if (array_key_exists($key, $cache)) {
        return $cache[$key];
    }
    return 0;
}

function cache_set($cache, $key, $value) 
{
    $cache[$key] = $value;
}

function get_network_id($dbh, $cache, $network_name)
{
    if (!$network_name) { return FALSE; }

    $network_id = cache_get($cache, "network:$network_name");
    if ($network_id) { return $network_id; }

    $sth = $dbh->prepare('SELECT id FROM network WHERE (name = ?) LIMIT 1');
    if (!$sth) {
        echo "ERROR: Prepare of SELECT query on network table failed in get_network_id.";
        echo $dbh->error;
        return FALSE;
    }
    $sth->bind_param('s', $network_name);
    $rv = $sth->execute();
    if (!$rv) {
        echo "ERROR: Execute of SELECT query on network table failed in get_network_id.";
        echo $dbh->error;
        return FALSE;
    }
    $sth->bind_result($network_id);
    $sth->fetch();
    if (!$network_id) {
        $sth = $dbh->prepare('INSERT INTO network (name) VALUES (?)');
        $sth->bind_param('s', $network_name);
        $rv = $sth->execute();
        if (!$rv) {
            echo "ERROR: Execute of INSERT query on network table failed in get_network_id.";
            echo $dbh->error;
            return FALSE;
        }
        $network_id = $dbh->insert_id;
        if (!$network_id) {
            echo "ERROR: Failed to get Last Insert ID from network table in get_network_id.";
            return FALSE;
        }
    }
    $sth->close();

    cache_set($cache, "network:$network_name", $network_id);

    return $network_id;
}

function get_channel_id($dbh, $cache, $network_id, $channel_name)
{
    if (!$network_id) { return FALSE; }
    if (!$channel_name) { return FALSE; }
    if (!is_numeric($network_id)) { return FALSE; }

    $channel_id = cache_get($cache, "channel:$network_id/$channel_name");
    if ($channel_id) { return $channel_id; }

    $channel_id = 0;
    $sth = $dbh->prepare('SELECT id FROM channel WHERE (name = ?) LIMIT 1');
    if (!$sth) {
        echo "ERROR: Prepare of SELECT query on channel table failed in get_channel_id.";
        echo $dbh->error;
        return FALSE;
    }
    $sth->bind_param('s', $channel_name);
    $rv = $sth->execute();
    if (!$rv) {
        echo "ERROR: Execute of SELECT query on channel table failed in get_channel_id.";
        echo $dbh->error;
        return FALSE;
    }
    $sth->bind_result($channel_id);
    $sth->fetch();
    if (!$channel_id) {
        $sth = $dbh->prepare('INSERT INTO channel (network_id, name) VALUES (?, ?)');
        $sth->bind_param('ds', $network_id, $channel_name);
        $rv = $sth->execute();
        if (!$rv) {
            echo "ERROR: Execute of INSERT query on channel table failed in get_channel_id.";
            echo $dbh->error;
            return FALSE;
        }
        $channel_id = $dbh->insert_id;
        if (!$channel_id) {
            echo "ERROR: Failed to get Last Insert ID from channel table in get_channel_id.";
            return FALSE;
        }
    }
    $sth->close();

    cache_set($cache, "channel:$network_id/$channel_name", $channel_id);

    return $channel_id;
}

function get_nick_id($dbh, $cache, $network_id, $nick_name)
{
    if (!$network_id) { return FALSE; }
    if (!$nick_name) { return FALSE; }
    if (!is_numeric($network_id)) { return FALSE; }

    $nick_id = cache_get($cache, "nick:$network_id/$nick_name");
    if ($nick_id) { return $nick_id; }

    $nick_id = 0;
    $sth = $dbh->prepare('SELECT id FROM nick WHERE (nick = ?) LIMIT 1');
    if (!$sth) {
        echo "ERROR: Prepare of SELECT query on nick table failed in get_nick_id.";
        echo $dbh->error;
        return FALSE;
    }
    $sth->bind_param('s', $nick_name);
    $rv = $sth->execute();
    if (!$rv) {
        echo "ERROR: Execute of SELECT query on nick table failed in get_nick_id.";
        echo $dbh->error;
        return FALSE;
    }
    $sth->bind_result($nick_id);
    $sth->fetch();
    if (!$nick_id) {
        $sth = $dbh->prepare('INSERT INTO nick (network_id, nick, created_at) VALUES (?, ?, NOW())');
        $sth->bind_param('ds', $network_id, $nick_name);
        $rv = $sth->execute();
        if (!$rv) {
            echo "ERROR: Execute of INSERT query on nick table failed in get_nick_id.";
            echo $dbh->error;
            return FALSE;
        }
        $nick_id = $dbh->insert_id;
        if (!$nick_id) {
            echo "ERROR: Failed to get Last Insert ID from nick table in get_nick_id.";
            return FALSE;
        }
    }
    $sth->close();

    cache_set($cache, "nick:$network_id/$nick_name", $nick_id);

    return $nick_id;
}

function get_url_id($dbh, $url)
{
    if (!$url) { return FALSE; }

    $sth = $dbh->prepare('SELECT id FROM url WHERE (url = ?)');
    if (!$sth) {
        echo "ERROR: Prepare of SELECT query on url table failed in get_url_id.";
        return FALSE;
    }
    $sth->bind_param('s', $url);
    $rv = $sth->execute();
    if (!$rv) {
        echo "ERROR: Execute of SELECT query on url table failed in get_url_id.";
        return FALSE;
    }
    $sth->bind_result($url_id);
    $sth->fetch();
    $sth->close();

    return $url_id;
}

function insert_url($dbh, $url, $state_id = 0, $content_length = 0, $content_type = '', $redirects_to_id = 0, $html_title = '')
{
    if (!$url) { return FALSE; }
    if (!is_numeric($state_id)) { return FALSE; }
    if (!is_numeric($content_length)) { return FALSE; }
    if (!is_numeric($redirects_to_id)) { return FALSE; }

    $sth = $dbh->prepare('INSERT INTO url (url, state_id, content_length, content_type, redirects_to_id, html_title) VALUES (?, ?, ?, ?, ?, ?)');
    if (!$sth) {
        echo "ERROR: Prepare of INSERT query on url table failed in insert_url.";
        echo $dbh->error;
        return FALSE;
    }
    $sth->bind_param('sdddss', $url, $state_id, $content_length, $content_type, $redirects_to_id, $html_title);
    $rv = $sth->execute();
    if (!$rv) {
        echo "ERROR: Execute of INSERT query on url table failed in insert_url.";
        echo $dbh->error;
        return FALSE;
    }

    $url_id = $dbh->insert_id;

    $sth->close();

    return $url_id;
}

function insert_message($dbh, $channel_id, $nick_id, $message)
{
    if (!$channel_id) { return FALSE; }
    if (!$nick_id) { return FALSE; }
    if (!$message) { return FALSE; }
    if (!is_numeric($channel_id)) { return FALSE; }
    if (!is_numeric($nick_id)) { return FALSE; }

    $sth = $dbh->prepare('
        INSERT INTO message 
        (channel_id, nick_id, message_line, created_at)
        VALUES (?, ?, ?, NOW())');
    if (!$sth) {
        echo "ERROR: Prepare of INSERT query on message table failed in insert_message.";
        echo $dbh->error;
        return FALSE;
    }
    $rv = $sth->bind_param('dds', $channel_id, $nick_id, $message);
    if (!$rv) {
        echo "ERROR: Bind of INSERT query on message table failed in insert_message.";
        echo $dbh->error;
        return FALSE;
    }
    $rv = $sth->execute();
    if (!$rv) {
        echo "ERROR: Execute of INSERT query on message table failed in insert_message.";
        echo $dbh->error;
        return FALSE;
    }

    $message_id = $dbh->insert_id;
    if (!$message_id) {
        echo "ERROR: Failed to get Last Insert ID from message table in insert_message.";
        return FALSE;
    }

    $sth->close();

    return $message_id;
}

function insert_url_to_message($dbh, $url_id, $message_id)
{
    if (!$url_id) { return FALSE; }
    if (!$message_id) { return FALSE; }
    if (!is_numeric($url_id)) { return FALSE; }
    if (!is_numeric($message_id)) { return FALSE; }

    $sth = $dbh->prepare('INSERT INTO url_to_message (url_id, message_id) VALUES (?, ?)');
    if (!$sth) {
        echo "ERROR: Prepare of INSERT query on url_to_message table failed in insert_url_to_message.";
        echo $dbh->error;
        return FALSE;
    }
    $sth->bind_param('dd', $url_id, $message_id);
    $rv = $sth->execute();
    if (!$rv) {
        echo "ERROR: Execute of INSERT query on url_to_message table failed in insert_url_to_message.";
        echo $dbh->error;
        return FALSE;
    }

    $sth->close();

    return TRUE;
}

function insert_urls_from_pool($dbh, $network_id, $channel_id, $nick_id, $message, $urls)
{
    if (!$network_id) { return FALSE; }
    if (!$channel_id) { return FALSE; }
    if (!$nick_id) { return FALSE; }
    if (!$message) { return FALSE; }
    if (!$urls) { return FALSE; }
    if (!is_numeric($network_id)) { return FALSE; }
    if (!is_numeric($channel_id)) { return FALSE; }
    if (!is_numeric($nick_id)) { return FALSE; }

    $complete_urls = array();

    foreach ($urls as $url) {
        $url_id = get_url_id($dbh, $url);
        if ($url_id === FALSE) { continue; }

        // get information about the new url
        if (!$url_id) {
            echo "url=$url\n";
            // information gathering...
            $http_meta = get_empty_http_meta();
            if (substr($url, 0, 5) == 'http:') {
                $http_meta = get_http_meta($url, 0);
                // todo: we could choose to skip the url and the message if the state is not 1 here
                //       or we record it (as we do now) and handle it someway later
            }

            // handle redirects
            // we store the original url but with the details of the destination
            // we will also keep a copy of the destination as a seperate record
            // we could probably handle this cleaner (e.g. redirecting url doesn't have text of destination), but maybe not much need
            $redirects_to_id = 0;
            if (array_key_exists('redirect', $http_meta) and array_key_exists('location', $http_meta)) {
                $redirects_to_url = $http_meta['location'];

                $redirects_to_id = get_url_id($dbh, $redirects_to_url);
                if ($redirects_to_id === FALSE) { continue; }

                if (!$redirects_to_id) {
                    echo "Saving redirects_to record ";
                    $redirects_to_id = insert_url($dbh, $redirects_to_url, $http_meta['state'], $http_meta['content_length'], $http_meta['content_type'], 0, $http_meta['html_title']);
                    if ($redirects_to_id === FALSE) { continue; }

                    // todo: do we need to do this as well for redirects?
                    //$rv = insert_url_to_message($dbh, $dst_url_id, $message_id);
                    //if (!$rv) { continue; }
                }
            }

            // store the new url
            print_r($http_meta);
            $url_id = insert_url($dbh, $url, $http_meta['state'], $http_meta['content_length'], $http_meta['content_type'], $redirects_to_id, $http_meta['html_title']);
            if ($url_id === FALSE) { continue; }

        }

        $complete_urls[$url] = $url_id;

    }

    if (count($complete_urls) != count($urls)) {
        // one or more of the urls failed to insert
        // abandon this message
        echo "\n\n<strong>complete_urls != urls - this message will be ignored but some urls may already have been inserted</strong>\n\n";
        return 0;
    }

    $message = merge_url_ids_to_message($message, $complete_urls);

    // finally record the message 
    $message_id = insert_message($dbh, $channel_id, $nick_id, $message);
    if (!$message_id) { return 0; }

    foreach ($complete_urls as $url_id) {
        #print "urlid=$url_id\n";
        $rv = insert_url_to_message($dbh, $url_id, $message_id);
        if (!$rv) { continue; }
    }

    if (count($complete_urls)) {
        return $message_id;
    } else {
        return 0;
    }

}

function merge_url_ids_to_message($message, $urls)
{
    #print "1message = $message\n";
    foreach ($urls as $url => $url_id) {
        $url = preg_quote($url, '/');
        $message = preg_replace("/$url/", "[urlcatcher:$url_id]", $message);
    }
    #print "2message = $message\n";

    return $message;
}

function clean_pool($dbh, $pool_id)
{
    if (!$pool_id) { return FALSE; }
    if (!is_numeric($pool_id)) { return FALSE; }

    $sth = $dbh->prepare('DELETE FROM pool WHERE (id = ?)');
    if (!$sth) {
        echo "ERROR: Prepare of DELETE query on pool table failed in clean_pool.";
        echo $dbh->error;
        return FALSE;
    }
    $rv = $sth->bind_param('d', $pool_id);
    if (!$rv) {
        echo "ERROR: Bind of DELETE query on pool table failed in clean_pool.";
        echo $dbh->error;
        return FALSE;
    }
    $rv = $sth->execute();
    if (!$rv) {
        echo "ERROR: Execute of DELETE query on pool table failed in clean_pool.";
        echo $dbh->error;
        return FALSE;
    }

    return 1;
}

function get_empty_http_meta()
{
    $http_meta = array();
    $http_meta['state'] = 0;
    $http_meta['http_status'] = 0;
    $http_meta['content_length'] = 0;
    $http_meta['content_type'] = '';
    $http_meta['html_title'] = '';
    return $http_meta;
}

function get_http_meta($url, $depth = 0, $status_chain = '', $url_chain = '')
{
    //echo "get_http_meta('$url', $depth)\n";
    // how deep to follow http redirects
    if ($depth > 3) { return; }
    $depth++;

    $connect_timeout = 3;
    $read_timeout = 6;
    ini_set('default_socket_timeout', $connect_timeout);

    $http_meta = get_empty_http_meta();

    $purl = parse_url($url);

    // note: this seems to fail for all addresses
    // if a domain name, is it valid?
    /*
    if (!preg_match("/^[0-9]{3}\.[0-9]{3}\.[0-9]{3}\.[0-9]{3}$/", $purl['host'])) {
        $ip = gethostbyname($purl['host']);
        if ($ip == $purl['host']) {
            echo "(name resolution failed) "; 
            $http_meta['state'] = 2;
            return $http_meta;
        }
    }
     */

    // connect and get http return code
    if (array_key_exists('port', $purl)) { 
        $port = $purl['port'];
    } else {
        $port = 80; 
    }
    $sock = fsockopen($purl['host'], $port, $errno, $errstr, $connect_timeout);
    if (!$sock) {
        echo "(connection error - $errstr ($errno)) "; 
        $http_meta['state'] = 3;
        return $http_meta;
    }

    stream_set_blocking($sock, FALSE);
    stream_set_timeout($sock, $read_timeout);

    $url_path = '/';
    if (array_key_exists('path', $purl)) { 
        $url_path = $purl['path'];
        if (array_key_exists('query', $purl)) { 
            $url_path .= '?' . $purl['query'];
        }
    }

    // we set 'accept-language' as some sites will have different <title> depending on your geoip
    // e.g. flickr
    // some sites seem to ignore you if you don't send a user-agent
    // e.g. digg (but maybe that's for the better)
    fputs($sock, "GET $url_path HTTP/1.1\r\n");
    fputs($sock, "Host: " . $purl['host'] . "\r\n");
    fputs($sock, "Connection: close\r\n");
    fputs($sock, "Accept-Language: en-gb, en;q=0.8\r\n");
    fputs($sock, "User-Agent: URL catcher\r\n");
    fputs($sock, "\r\n");

    $status = socket_get_status($sock);
    if ($status['timed_out']) { 
        echo "(status timed_out) "; 
        $http_meta['state'] = 4;
        return $http_meta; 
    }
    if (feof($sock)) { 
        echo "(socket early EOF) "; 
        $http_meta['state'] = 5;
        return $http_meta; 
    }

    $contents = stream_get_contents($sock, 1024 * 8);
    if ($contents === FALSE) {
        echo "stream_get_contents returned FALSE ";
        return $http_meta;
    }
    fclose($sock);

    $http_status = get_http_status($contents);
    //echo "http_status=$http_status\n";
    if (!is_numeric($http_status)) { return $http_meta; }
    $http_meta['http_status'] = $http_status;
    $http_meta['location'] = $url;

    // handle different status codes

    if ($http_status == "404") {
        echo "(http 404) "; 
        $http_meta['state'] = 6;
    } elseif (substr($http_status, 0, 1) == 4) {
        echo "(http other 40x) "; 
        $http_meta['state'] = 7;
    } elseif (substr($http_status, 0, 1) == 5) {
        echo "(http other 50x) "; 
        $http_meta['state'] = 8;
    } elseif (($http_status == "301") or ($http_status == "302")) {
        // 301 - Moved Permanently
        // 302 - Found / Moved
        $new_url = get_http_location($contents); 
        if (!$new_url) {
            $http_meta['state'] = 0;
            return $http_meta;
        }

        // recurse recurse recurse
        // discard our meta in favour of the deepest url
        $http_meta = get_http_meta($new_url, $depth);

        // set any meta we want to persist here
        $http_meta['redirect'] = 1;
    } elseif ($http_status == "200") {
        $http_meta['state'] = 1;
        $http_meta['content_length'] = get_http_content_length($contents);
        $http_meta['content_type'] = get_http_content_type($contents);

        $check_html = 0;
        if ($http_meta['content_type']) {
            $check_html = preg_match("/^text\/html/", $http_meta['content_type']);
        } else {
            $check_html = ! preg_match("/(jpg|jpeg|gif|png|wav|mp3|avi|wmv|mpg)$/", $url);
        }

        if ($check_html) {
            $http_meta['html_title'] = get_html_title($contents);
            if (!$http_meta['html_title']) {
                $http_meta['html_title'] = get_html_h1($contents);
            }
        } else {
            //echo "(non text/html type) ";
        }

        // html meta redirect?
        // this could be placed better to avoid doing all the work above
        $html_meta_redirect = get_html_meta_redirect($contents);
        if ($html_meta_redirect) {
            $http_meta = get_http_meta($html_meta_redirect, $depth);
            $http_meta['redirect'] = 1;
        }
    }

    return $http_meta;
}

// we don't handle relative urls
function get_html_meta_redirect($text)
{
    //echo "get_html_meta_redirect() ";
    if (!$text) { return ''; }

    preg_match('/<meta\s+http-equiv="refresh"\s+content="0;\s*url=\s*(http:\/\/[^"\s]+)">/i', $text, $matches);
    if (count($matches) == 0) { 
        //echo '(no meta redirect or failed regex) '; 
        return ''; 
    }

    $html_meta_redirect = $matches[1];

    return $html_meta_redirect;
}

function get_html_title($text)
{
    //echo "get_html_title() ";
    if (!$text) { return ''; }

    preg_match('/<title[^>]*>([^<]+)<\/title>/i', $text, $matches);
    if (count($matches) == 0) { 
        //echo '(no &lt;title&gt; or failed regex) '; 
        return ''; 
    }

    $html_title = $matches[1];

    // tidy up
    // <title> should not have inner tags, but crazy people are allowed to make websites too
    $html_title = preg_replace('/\s+/', ' ', $html_title);
    $html_title = preg_replace('/^\s*|\s*$/', '', $html_title);
    $html_title = strip_tags($html_title);

    return $html_title;
}

function get_html_h1($text)
{
    //echo "get_html_h1() ";
    if (!$text) { return ''; }

    preg_match('/<h1[^>]*>(.*?)<\/h1>/i', $text, $matches);
    if (count($matches) == 0) { 
        //echo '(no &lt;h1&gt; or failed regex) '; 
        return ''; 
    }

    $html_h1 = $matches[1];

    // tidy up
    // <h1> may potentially have html inside of it, we'll have none of that!
    $html_h1 = preg_replace('/\s+/', ' ', $html_h1);
    $html_h1 = preg_replace('/^\s*|\s*$/', '', $html_h1);
    $html_h1 = strip_tags($html_h1);

    return $html_h1;
}

function get_http_status($text)
{
    $c = preg_match("/HTTP\/[01]\.[0-9] ([0-9]{3})/", $text, $matches);
    if (!$c) { 
        return '';
    } else {
        return $matches[1];
    }
}

function get_http_location($text)
{
    $c = preg_match("/Location: ([^\n\r]+)/", $text, $matches);
    if (!$c) { 
        return '';
    } else {
        return $matches[1];
    }
}

function get_http_content_type($text)
{
    $c = preg_match("/Content-Type: ([^\n\r]+)/", $text, $matches);
    if (!$c) { 
        return '';
    } else {
        return $matches[1];
    }
}

function get_http_content_length($text)
{
    $c = preg_match("/Content-Length: ([0-9]+)/", $text, $matches);
    if (!$c) { 
        return 0;
    } else {
        return $matches[1];
    }
}

