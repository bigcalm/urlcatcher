<?php

/*
 *
 * URL catcher - simple-web
 * Simple web interface to caught urls
 *
 */
$NAME        = 'URL catcher - Simple Web UI';
$VERSION     = '0.2';
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

function urlify($text)
{
	$urls = '(http|https|telnet|gopher|file|wais|ftp)';
	$ltrs = '\w';
	$gunk = '\\/#~:.?+=&;%@!\-';
	$punc = '.:?\-';
	$any  = "$ltrs$gunk$punc";

	$text = preg_replace("/\b($urls:[$any]+?)(?=[$punc]*[^$any]|$)/", "<a href='$1'>$1</a>", $text);
    return $text;
}

function text_to_colour($text)
{
    // ensure enough characters to create a suitable hash
    if (strlen($text) < 20) { $text .= "$text$text$text.kittens_kittens_kittens"; }

    $rgb = substr( md5($text), 0, 6 );

    return $rgb;
}

function text_to_dark_colour($text)
{
    if (strlen($text) < 20) { $text .= "$text$text$text.kittens_kittens_kittens"; }

    $rgb = substr( md5($text), 0, 6 );

    $r = substr($rgb, 0, 2);
    $g = substr($rgb, 2, 2);
    $b = substr($rgb, 4, 2);

    if (hexdec($r) > 150) { $r = dechex(hexdec($r) - 100); }
    if (hexdec($g) > 150) { $g = dechex(hexdec($g) - 100); }
    if (hexdec($b) > 150) { $b = dechex(hexdec($b) - 100); }

    if (strlen($r) < 2) { $r = "0$r"; }
    if (strlen($g) < 2) { $g = "0$g"; }
    if (strlen($b) < 2) { $b = "0$b"; }

    return "$r$g$b";
}

function text_to_light_colour($text)
{
    // this hash should be the same as for text_to_color for best colour matching results
    if (strlen($text) < 20) { $text .= "$text$text$text.kittens_kittens_kittens"; }

    $rgb = substr( md5($text), 0, 6 );

    return 'e' . substr($rgb, 1, 1) . 'e' . substr($rgb, 3, 1) . 'e' . substr($rgb, 5, 1);
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
</style>
</head>
<body>
<?php

$result = mysqli_query($dbh, 'SELECT 

    channel.name AS `channel_name`, 
    nick.nick AS `nick_name`, 
    message.message_line AS `message_line`,
    message.created_when AS `message_date`,
    CONCAT(channel.network_id, channel.id, channel.name) AS `channel_code`, 
    CONCAT(nick.network_id, nick.id, nick.nick) as `nick_code`

    FROM message 
    LEFT JOIN nick ON (message.nick_id = nick.id) 
    LEFT JOIN channel ON (message.channel_id = channel.id) 

    ORDER BY message.id DESC 
    LIMIT 0,50');

if (!$result) {
    echo "<h1>Query of urls failed.</h1>";
    exit;
}

if ($result->num_rows == 0) {
    echo "<p>No urls have been caught yet. Check back later.</p>";
    exit;
}

while ($row = mysqli_fetch_assoc($result)) {
    $channel_name = $row['channel_name'];
    $nick_name    = $row['nick_name'];
    $message_line = $row['message_line'];
    $message_date = $row['message_date'];
    $channel_code = $row['channel_code'];
    $nick_code    = $row['nick_code'];

    $message_line = htmlspecialchars($message_line);
    $message_line = urlify($message_line);

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

    printf("
        <div class='channel' style='background-color:#%s' title='$message_date'>
        <span class='channel' style='color:#%s'>%s</span>
        <span class='nick' style='color:#%s'>&lt;%s&gt;</span> 
        <span class='message'>%s</span>
        </div>\n", 
        $channel_colour_bg, 
        $channel_colour, 
        $channel_name, 
        $nick_colour, 
        $nick_name, 
        $message_line);
}

?>
</body>
</html>

