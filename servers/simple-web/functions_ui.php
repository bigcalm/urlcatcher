<?php

/*
 *
 * UI Functions
 *
 */

function urlify($text)
{
	$urls = '(http|https|telnet|gopher|file|wais|ftp|spotify)';
	$ltrs = '\w';
	$gunk = '\\/#~:,.?+=&;%@!\-';
	$punc = ',.:?\-';
	$any  = "$ltrs$gunk$punc";

    // php does not handle /(?=[$punc]*[^$any]|$)/ the same as perl, so use the below instead
	$text = preg_replace("/\b($urls:[$any]+?)(?=[$punc]*(?:[^$any]|$))/", "<a title=\"\" href=\"$1\">$1</a>", $text);

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

