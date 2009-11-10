ALTER TABLE `message` CHANGE `created_when` `created_at` DATETIME;
ALTER TABLE `nick` CHANGE `created_when` `created_at` DATETIME;
ALTER TABLE `tag` CHANGE `created_when` `created_at` DATETIME;
RENAME TABLE `url_message_join` TO `url_to_message`;
