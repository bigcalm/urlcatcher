-- urlcatcher.mysql_schema.sql
-- version 0.2
--
-- Table structure for table `network`
--

DROP TABLE IF EXISTS `network`;
CREATE TABLE `network` (
  `id` int(11) UNSIGNED NOT NULL auto_increment,
  `name` varchar(255) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `channel`
--

DROP TABLE IF EXISTS `channel`;
CREATE TABLE `channel` (
  `id` int(11) UNSIGNED NOT NULL auto_increment,
  `network_id` int(11) UNSIGNED NOT NULL,
  `name` varchar(255) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `search`
--

DROP TABLE IF EXISTS `search`;
CREATE TABLE `search` (
  `id` int(11) UNSIGNED NOT NULL auto_increment,
  `created_at` datetime NOT NULL,
  `search` varchar(255) NOT NULL,
  `ip_addr` varchar(255) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `tags`
--

DROP TABLE IF EXISTS `tag`;
CREATE TABLE `tag` (
  `url_id` int(11) UNSIGNED NOT NULL,
  `created_at` datetime NOT NULL,
  `nick_id` int(11) UNSIGNED NOT NULL,
  `tag` varchar(255) NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `messages`
--

DROP TABLE IF EXISTS `message`;
CREATE TABLE `message` (
  `id` int(11) UNSIGNED NOT NULL auto_increment,
  `channel_id` int(11) UNSIGNED NOT NULL,
  `created_at` datetime NOT NULL,
  `nick_id` int(11) UNSIGNED NOT NULL,
  `message_line` varchar(255) NOT NULL,
  PRIMARY KEY  (`id`),
  FULLTEXT KEY `FULLTEXT` (`message_line`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `url`
--

DROP TABLE IF EXISTS `url`;
CREATE TABLE `url` (
  `id` int(11) UNSIGNED NOT NULL auto_increment,
  `url` varchar(255) NOT NULL,
  `state_id` tinyint(2) UNSIGNED NOT NULL,
  `content_length` int(11) UNSIGNED NOT NULL,
  `content_type` varchar(50) NOT NULL,
  `redirects_to_id` int(11) UNSIGNED NOT NULL,
  `html_title` varchar(255) NOT NULL,
  `last_checked` datetime NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `url_to_message`
--

DROP TABLE IF EXISTS `url_to_message`;
CREATE TABLE `url_to_message` (
  `url_id` int(11) UNSIGNED NOT NULL,
  `message_id` int(11) UNSIGNED NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `nick`
--

DROP TABLE IF EXISTS `nick`;
CREATE TABLE `nick` (
  `id` int(11) UNSIGNED NOT NULL auto_increment,
  `network_id` int(11) UNSIGNED NOT NULL,
  `nick` varchar(50) NOT NULL,
  `email` varchar(100) default NULL,
  `password` varchar(100) default NULL,
  `created_at` datetime NOT NULL,
  `last_when` datetime default NULL,
  `last_from` varchar(255) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `pool`
--

DROP TABLE IF EXISTS `pool`;
CREATE TABLE `pool` (
  `id` int(11) UNSIGNED NOT NULL auto_increment,
  `client_id` varchar(32) NOT NULL,
  `network` varchar(255) NOT NULL,
  `channel` varchar(255) NOT NULL,
  `nick` varchar(50) NOT NULL,
  `message` varchar(255) NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `client`
--

DROP TABLE IF EXISTS `client`;
CREATE TABLE `client` (
  `id` varchar(32) NOT NULL,
  `contact_name` varchar(50) NOT NULL,
  `contact_email` varchar(255) NOT NULL,
  `ref` varchar(50) NOT NULL,
  `enabled` tinyint(1) UNSIGNED NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `state`
--

DROP TABLE IF EXISTS `state`;
CREATE TABLE `state` (
  `id` tinyint(2) UNSIGNED NOT NULL,
  `state` varchar(50) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
INSERT INTO `state` (id, state) VALUES (0, 'Unknown');
INSERT INTO `state` (id, state) VALUES (1, 'OK');
INSERT INTO `state` (id, state) VALUES (2, 'Name resolution failure');
INSERT INTO `state` (id, state) VALUES (3, 'Connection error');
INSERT INTO `state` (id, state) VALUES (4, 'Read timeout');
INSERT INTO `state` (id, state) VALUES (5, 'Socket early EOF');
INSERT INTO `state` (id, state) VALUES (6, 'HTTP 404');
INSERT INTO `state` (id, state) VALUES (7, 'HTTP Other 40x');
INSERT INTO `state` (id, state) VALUES (8, 'HTTP Other 50x');

