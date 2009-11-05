<?php

/*
 *
 * URL catcher - simple-web
 * Simple web interface to caught urls
 *
 */

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

    $hash = md5($text);

    return substr($hash, 0, 6);
}

function text_to_light_colour($text)
{
    // this hash should be the same as for text_to_color for best colour matching results
    if (strlen($text) < 20) { $text .= "$text$text$text.kittens_kittens_kittens"; }

    $hash = md5($text);

    return 'e' . substr($hash, 1, 1) . 'e' . substr($hash, 3, 1) . 'e' . substr($hash, 5, 1);
}

?><!doctype html>
<html>
<head>
<title>URL catcher - Simple</title>
<meta http-equiv="refresh" content="60">
<style type="text/css">
body {
    margin: 0;
    padding: 0;
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
<?php

// create a list of channel classes and produce a colour for them
$result = mysqli_query($dbh, 'select id, name from channels order by id');
if (!$result) { echo "</style><body><h1>Query of channels failed.</h1>"; exit; }

while ($row = mysqli_fetch_assoc($result)) {
    $channel_colour     = text_to_colour($row['name'] . $row['id']);
    $channel_colour_bg  = text_to_light_colour($row['name'] . $row['id']);
    printf("div.ch%s  { background-color: #%s; }\n", $channel_colour, $channel_colour_bg);
    printf("div.ch%s span.channel { color: #%s; }\n", $channel_colour, $channel_colour);
}

// and the same for nicks
$result = mysqli_query($dbh, 'select id, nick from nicks order by id');
if (!$result) { echo "</style><body><h1>Query of nicks failed.</h1>"; exit; }

while ($row = mysqli_fetch_assoc($result)) {
    $colour = text_to_colour($row['nick'] . $row['id']);
    printf("span.nick%s { color: #%s; }\n", $colour, $colour);
}
?>

</style>
</head>
<body>
<?php

$result = mysqli_query($dbh, 'select channels.id as `channel_id`, channels.name as `channel_name`, nicks.id as `nick_id`, nicks.nick as `nick_name`, urls.message_line as `message_line` from urls left join nicks on (urls.nick_id = nicks.id) left join channels on (urls.channel_id = channels.id) order by urls.id desc limit 0,50');

if (!$result) {
    echo "<h1>Query of urls failed.</h1>";
    exit;
}

while ($row = mysqli_fetch_assoc($result)) {
    $channel_id = $row['channel_id'];
    $channel_name = $row['channel_name'];
    $nick_id = $row['nick_id'];
    $nick_name = $row['nick_name'];
    $message_line = $row['message_line'];

    $message_line = htmlspecialchars($message_line);
    $message_line = urlify($message_line);

    $channel_colour = text_to_colour($channel_name . $channel_id);
    $nick_colour = text_to_colour($nick_name . $nick_id);

    printf("<div class='channel ch%s'><span class='channel'>%s</span> <span class='nick nick%s'>&lt;%s&gt;</span> <span class='message'>%s</span></div>\n", $channel_colour, $channel_name, $nick_colour, $nick_name, $message_line);
}

?>
</body>
</html>

