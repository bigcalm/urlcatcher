-- urlcatcher.mysql_schema.sql

--
-- Table structure for table `network`
--

DROP TABLE IF EXISTS `network`;
CREATE TABLE `network` (
  `id` int(11) NOT NULL auto_increment,
  `name` varchar(255) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `channel`
--

DROP TABLE IF EXISTS `channel`;
CREATE TABLE `channel` (
  `id` int(11) NOT NULL auto_increment,
  `network_id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `search`
--

DROP TABLE IF EXISTS `search`;
CREATE TABLE `search` (
  `id` int(11) NOT NULL auto_increment,
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
  `url_id` int(11) NOT NULL,
  `created_at` datetime NOT NULL,
  `nick_id` int(11) NOT NULL,
  `tag` varchar(255) NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `messages`
--

DROP TABLE IF EXISTS `message`;
CREATE TABLE `message` (
  `id` int(11) NOT NULL auto_increment,
  `channel_id` int(11) NOT NULL,
  `created_at` datetime NOT NULL,
  `nick_id` int(11) NOT NULL,
  `message_line` varchar(255) NOT NULL,
  PRIMARY KEY  (`id`),
  FULLTEXT KEY `FULLTEXT` (`message_line`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `url`
--

DROP TABLE IF EXISTS `url`;
CREATE TABLE `url` (
  `id` int(11) NOT NULL auto_increment,
  `url` varchar(255) NOT NULL,
  `state_id` tinyint(2) NOT NULL,
  `last_checked` datetime NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `url_to_message`
--

DROP TABLE IF EXISTS `url_to_message`;
CREATE TABLE `url_to_message` (
  `url_id` int(11) NOT NULL,
  `message_id` int(11) NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


--
-- Table structure for table `nick`
--

DROP TABLE IF EXISTS `nick`;
CREATE TABLE `nick` (
  `id` int(11) NOT NULL auto_increment,
  `network_id` int(11) NOT NULL,
  `nick` varchar(50) NOT NULL,
  `email` varchar(100) default NULL,
  `password` varchar(100) default NULL,
  `created_at` datetime NOT NULL,
  `last_when` datetime default NULL,
  `last_from` varchar(255) default NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

