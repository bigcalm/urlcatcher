<?php
require_once('functions_backend.php');

/*
 *
 * URL catcher - pool updater
 * Take entries from the pool and insert them proper
 *
 */

#if ($_GET['toby'] != '1') { echo "No pool cleaner for you!"; exit; }

// todo: 
//      the whole inserting of network/channel/nick/message/url records should probably be a transaction as there are many places for an error to leave us in a bad state
//      this link didn't get urlified or its id wasn't merged (id:145) "http://www.scanwith.com/download_soft.php?d=2224&s=491 try that link Nautilus"
//      & in <title>: (What once was &quot;the most secure&quot; is now the most vulnerable browser : reddit.com)
//      redirects to an https are not handled correctly, we try to connect to them on port 80 for a start

//echo "<br><br><pre>Pool Cleaner(tm)\n\n";

@flush();

// create a seperate pool manager user as such:
// mysql> grant insert,select,delete on urlcatcher.* to `uc_poolman`@`localhost` identified by 'rmiIgUmpkTeC';
//
// or for greater security, give them only the access they need:
// mysql> grant select,delete on urlcatcher.pool    to `uc_poolman`@`localhost` identified by 'rmiIgUmpkTeC';
// mysql> grant select,insert on urlcatcher.url     to `uc_poolman`@`localhost` identified by 'rmiIgUmpkTeC';
// mysql> grant select,insert on urlcatcher.message to `uc_poolman`@`localhost` identified by 'rmiIgUmpkTeC';
// mysql> grant select,insert on urlcatcher.channel to `uc_poolman`@`localhost` identified by 'rmiIgUmpkTeC';
// mysql> grant select,insert on urlcatcher.network to `uc_poolman`@`localhost` identified by 'rmiIgUmpkTeC';
// mysql> grant select,insert on urlcatcher.nick    to `uc_poolman`@`localhost` identified by 'rmiIgUmpkTeC';
// mysql> grant select        on urlcatcher.client  to `uc_poolman`@`localhost` identified by 'rmiIgUmpkTeC';
// mysql> grant insert        on urlcatcher.url_to_message to `uc_poolman`@`localhost` identified by 'rmiIgUmpkTeC';
// mysql> flush privileges;
$db_hostname = 'localhost';
$db_database = 'urlcatcher';
$db_username = 'uc_poolman';
$db_password = 'rmiIgUmpkTeC';

$dbh = mysqli_connect($db_hostname, $db_username, $db_password, $db_database);
if (!$dbh) {
    echo "<h1>Connection to database failed.</h1>";
    exit;
}

// get new pool items
// - we ignore items created in the last 30 seconds to avoid us updating more often than necessary
// - by joining with the `client` table we can immediatley discard any pool items that came from invalid/disabled clients
// todo: clear out pool of items that came from invalid/disabled clients... a pool caretaker script
$sth = $dbh->query('
    SELECT 
    pool.id AS `pool_id`,
    pool.network AS `network_name`,
    pool.channel AS `channel_name`,
    pool.nick AS `nick_name`,
    pool.message AS `message`
    FROM pool 
    LEFT JOIN client ON (pool.client_id = client.id) 
    WHERE 
    client.enabled = 1 AND
    DATE_SUB(NOW(), INTERVAL 30 SECOND) > pool.created_at
    LIMIT 8');

if (!$sth) {
    echo "<h1>Query of pool failed.</h1>";
    echo $dbh->error;
    exit;
}

if ($sth->num_rows == 0) { 
    //echo "The pool is empty.\n\n";
    exit; 
} else {
    echo "The pool has " . $sth->num_rows . " occupants (or I reached the maximum to read in this update).\n\n";
}

$rows = array();
while ($row = $sth->fetch_assoc()) { array_push($rows, $row); }

$sth->close();

$cache = array();

// find the relevant ids based on the string names we have been given, create records if needed
// insert the pool items into the real tables
foreach ($rows as $row) {
    $pool_id       = $row['pool_id'];
    $network_name  = $row['network_name'];
    $channel_name  = $row['channel_name'];
    $nick_name     = $row['nick_name'];
    $message       = $row['message'];
    
    // remove this item from the pool now
    // if anything goes wrong trying to merge it we won't keep trying every pool update
    clean_pool($dbh, $pool_id);

    $urls = get_urls($message);
    if (count($urls) == 0) { exit; }

    echo "pool_id=$pool_id; ";
    echo 'urls=' . count($urls) . ' ';

    $network_id = get_network_id($dbh, $cache, $network_name);
    if (!$network_id) { exit; }
    echo "$network_name($network_id) ";

    $channel_id = get_channel_id($dbh, $cache, $network_id, $channel_name);
    if (!$channel_id) { exit; }
    echo "$channel_name($channel_id) ";

    $nick_id = get_nick_id($dbh, $cache, $network_id, $nick_name);
    if (!$nick_id) { exit; }
    echo "$nick_name($nick_id) ";
    echo "\n";

    $message_id = insert_urls_from_pool($dbh, $network_id, $channel_id, $nick_id, $message, $urls);
    if (!$message_id) { exit; }

    echo "message_id=$message_id ";

    echo "\n\n";

    @flush();
}

$dbh->close();

