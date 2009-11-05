-- urlcatcher.mysql_schema.sql

--
-- Table structure for table `channels`
--

DROP TABLE IF EXISTS `channels`;
CREATE TABLE `channels` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(255) NOT NULL,
  `server` varchar(255) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `searches`
--

DROP TABLE IF EXISTS `searches`;
CREATE TABLE `searches` (
  `id` int(11) NOT NULL auto_increment,
  `created_when` datetime NOT NULL,
  `search` varchar(255) NOT NULL,
  `ip_addr` varchar(255) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `tags`
--

DROP TABLE IF EXISTS `tags`;
CREATE TABLE `tags` (
  `url_id` int(11) NOT NULL,
  `created_when` datetime NOT NULL,
  `nick_id` int(11) NOT NULL,
  `tag` varchar(255) NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `urls`
--

DROP TABLE IF EXISTS `urls`;
CREATE TABLE `urls` (
  `id` int(11) NOT NULL auto_increment,
  `channel_id` int(11) NOT NULL,
  `created_when` datetime NOT NULL,
  `user_id` int(11) NOT NULL,
  `message_line` varchar(255) NOT NULL,
  PRIMARY KEY  (`id`),
  FULLTEXT KEY `FULLTEXT` (`message_line`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `id` int(11) NOT NULL auto_increment,
  `nick` varchar(50) NOT NULL,
  `email` varchar(100) default NULL,
  `password` varchar(100) default NULL,
  `created_when` datetime NOT NULL,
  `last_when` datetime default NULL,
  `last_from` varchar(255) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

