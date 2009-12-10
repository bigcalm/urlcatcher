<?php
error_reporting(E_ALL);
require_once('functions_ui.php');

/*
 *
 * URL catcher - simple-web
 * Simple web interface to caught urls
 *
 */

// todo: ignore urls we've already shown
$NAME        = 'URL catcher - Simple Web UI';
$VERSION     = '0.3-pool';
$DESCRIPTION = 'Watches configured channel(s) for URLS and stores them in a MySQL database.';
$AUTHORS     = 'Toby Oxborrow';
$CONTACT     = 'toby@oxborrow.net';
$URL         = 'http://urlcatcher.org/';
$LICENSE     = 'GPL';

$db_hostname = 'localhost';
$db_database = 'urlcatcher';
$db_username = 'uc_simpleweb';
$db_password = 'kFyTEWyne8aR';

$dbh = mysqli_connect($db_hostname, $db_username, $db_password, $db_database);
if (!$dbh) {
    echo "<h1>Connection to database failed.</h1>";
    exit;
}

?><!doctype html>
<html>
<head>
<title><?=$NAME?> v<?=$VERSION?></title>
<meta name="name" content="<?=$NAME?>">
<meta name="description" content="<?=$DESCRIPTION?>">
<meta name="version" content="v<?=$VERSION?>">
<meta name="authors" content="<?=$AUTHORS?>">
<meta name="contact" content="<?=$CONTACT?>">
<meta name="url" content="<?=$URL?>">
<meta name="license" content="<?=$LICENSE?>">
<meta http-equiv="refresh" content="60">
<style type="text/css">
body {
    margin: 0;
    padding: 0;
    font-family: monospace;
}
div.channel {
    background-color: #EEE;
    padding: 10px;
}
span.channel {
    color: #F33;
    font-weight: bold;
}
span.nick {
    color: #3F3;
}
small.title {
    color: #666;
}
</style>
</head>
<body>
<?php

$sth = mysqli_query($dbh, 'SELECT 

    message.id AS `message_id`,
    channel.name AS `channel_name`, 
    nick.nick AS `nick_name`, 
    message.message_line AS `message_line`,
    message.created_at AS `message_date`,
    CONCAT(channel.network_id, channel.id, channel.name) AS `channel_code`, 
    CONCAT(nick.network_id, nick.id, nick.nick) as `nick_code`

    FROM message 
    LEFT JOIN nick ON (message.nick_id = nick.id) 
    LEFT JOIN channel ON (message.channel_id = channel.id) 

    ORDER BY message.id DESC 
    LIMIT 90');

if (!$sth) {
    echo "<h1>Query of urls failed.</h1>";
    exit;
}

if ($sth->num_rows == 0) {
    echo "<p>No urls have been caught yet. Check back later.</p>";
} else {

    while ($row = mysqli_fetch_assoc($sth)) {
        $message_id   = $row['message_id'];
        $channel_name = $row['channel_name'];
        $nick_name    = $row['nick_name'];
        $message_line = $row['message_line'];
        $message_date = $row['message_date'];
        $channel_code = $row['channel_code'];
        $nick_code    = $row['nick_code'];

        //$message_line = htmlspecialchars($message_line);
        //$message_line = urlify($message_line);

        $channel_colour    = text_to_dark_colour($channel_code);
        $channel_colour_bg = text_to_light_colour($channel_code);
        $nick_colour       = text_to_dark_colour($nick_code);

        # e.g.: Friday, 6th November 2009 @ 3:07 pm HKT
        $message_date      = date('l, jS F Y @ g:i a T', 
            mktime(
                substr($message_date, 11, 2),
                substr($message_date, 14, 2),
                substr($message_date, 17, 2),
                substr($message_date, 5, 2),
                substr($message_date, 8, 2),
                substr($message_date, 0, 4)
            )
        );

        // warning: quite hacky
        $errors = 0;
        $sth2 = mysqli_query($dbh, "SELECT id,url,html_title,redirects_to_id FROM url LEFT JOIN url_to_message ON (url.id = url_to_message.url_id) WHERE (url_to_message.message_id = $message_id)");
        if (($sth2) and ($sth2->num_rows)) {
            while ($row2 = mysqli_fetch_assoc($sth2)) {
                $url_id          = $row2['id'];
                $url             = $row2['url'];
                $html_title      = $row2['html_title'];
                $redirects_to_id = $row2['redirects_to_id'];

                $alink_title = '';
                if ($redirects_to_id) {
                    // todo: can this be done as part of the above query?
                    $sth3 = mysqli_query($dbh, "SELECT url FROM url WHERE (id = $redirects_to_id)");
                    if (!$sth3) {
                        echo $dbh->error;
                        continue;
                    }
                    $row3 = mysqli_fetch_assoc($sth3);
                    $redirect_url = $row3['url'];
                    $alink_title = $redirect_url;
                }

                $display_url = $url;
                if (substr($display_url, 0, 7) == 'http://') {
                    $display_url = substr($display_url, 7);
                    $display_url = preg_replace('/\/$/', '', $display_url);
                }
                $alink = "<a href=\"$url\" title=\"$alink_title\">$display_url</a>";

                if ($html_title) {
                    //$html_title = htmlspecialchars($html_title, ENT_QUOTES);
                    $alink .= " <small class=\"title\">($html_title)</small>";
                }

                $url_tag = preg_quote("[urlcatcher:$url_id]");

                if (preg_match("/$url_tag/", $message_line)) {
                    $message_line = preg_replace("/$url_tag/", $alink, $message_line);
                } else { 
                    // this shouldn't happen!
                    // merge_url_ids_to_message() must have failed
                    // abandon this message
                    $errors++;
                    break;
                }

            }
        } else {
            // this shouldn't happen!
            // no matching record in url_to_message
            // abandon this message
            $errors++;
        }

        if ($errors) { continue; }

        printf("
            <div class='channel' style='background-color:#%s' id='msgid%u'>
            <span class='channel' style='color:#%s' title='$message_date'>%s</span>
            <span class='nick' style='color:#%s'>&lt;%s&gt;</span> 
            <span class='message'>%s</span>
            </div>\n", 
            $channel_colour_bg, 
            $message_id,
            $channel_colour, 
            $channel_name, 
            $nick_colour, 
            $nick_name, 
            $message_line);
    }

}

mysqli_close($dbh);

?>
</body>
</html>
<?php

// trigger pool update
//include('pool-update.php');

