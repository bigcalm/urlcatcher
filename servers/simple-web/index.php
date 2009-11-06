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

$result = mysqli_query($dbh, 'select CONCAT(channel.network_id, channel.id, channel.name) as `channel_code`, channel.name as `channel_name`, CONCAT(nick.network_id, nick.id, nick.nick) as `nick_code`, nick.nick as `nick_name`, message.message_line as `message_line` from message left join nick on (message.nick_id = nick.id) left join channel on (message.channel_id = channel.id) order by message.id desc limit 0,50');

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
    $channel_code = $row['channel_code'];
    $nick_code    = $row['nick_code'];

    $message_line = htmlspecialchars($message_line);
    $message_line = urlify($message_line);

    $channel_colour    = text_to_dark_colour($channel_code);
    $channel_colour_bg = text_to_light_colour($channel_code);
    $nick_colour       = text_to_dark_colour($nick_code);

    printf(
        "<div class='channel' style='background-color:#%s'><span class='channel' style='color:#%s'>%s</span> <span class='nick' style='color:#%s'>&lt;%s&gt;</span> <span class='message'>%s</span></div>\n", 
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

