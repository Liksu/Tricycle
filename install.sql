SET NAMES UTF8;

DELIMITER $$
--
-- Процедуры
--
DROP PROCEDURE IF EXISTS `tricycle_rearrange_children`$$
CREATE PROCEDURE `tricycle_rearrange_children`(pid int)
    DETERMINISTIC
BEGIN
    declare _cid int unsigned;
    declare p_xpath varchar(128);
    declare p_level, _count smallint unsigned;
    
    declare done int default 0;
    declare cur cursor for select category_id from prefix_category where parent_id = pid;
    declare continue handler for not found set done = 1;
    
    SET @@SESSION.max_sp_recursion_depth=42;
    
    select xpath, level into p_xpath, p_level from prefix_category where category_id = pid;
    select count(category_id) into _count from prefix_category where parent_id = pid;

    if _count > 0 then
        update prefix_category set xpath = concat(if(p_xpath = '/', '', p_xpath), '/', pid), level = p_level + 1 where parent_id = pid;
    
        open cur;
        while done = 0 do
            fetch cur into _cid;
            if done = 0 then
                call tricycle_rearrange_children(_cid);
            end if;
        end while;
    end if;
END$$

--
-- Функции
--
DROP FUNCTION IF EXISTS `tricycle_get_id_by_uri`$$
CREATE FUNCTION `tricycle_get_id_by_uri`(uri varchar(256)) RETURNS int(10) unsigned
    DETERMINISTIC
BEGIN
    declare part varchar(32);
    declare id, pid int unsigned;
    declare n, position, xpos tinyint unsigned;
    
    set n = 0;
    set pid = NULL;
    set position = 0;
    set part = '';
    
    if locate('/', uri, 1) = 1 then
        select category_id into pid from prefix_category where uri_name is null limit 1;
        set position = 1;
    end if;
    
    repeat
        set xpos = position + 1;
        set position = locate('/', uri, position + 1);

        if (position > 0) then
            set part = substring(uri, xpos, position - xpos);
        else
            set part = substring(uri, xpos);
        end if;
        
        select category_id, category_id into id, pid from prefix_category where uri_name = part and if(pid is NULL, parent_id is NULL, parent_id = pid);
    until position = 0 OR n >= 42 end repeat;
    
    return id;
END$$

DROP FUNCTION IF EXISTS `tricycle_get_uri_by_id`$$
CREATE FUNCTION `tricycle_get_uri_by_id`(id int) RETURNS varchar(256) CHARSET utf8
    DETERMINISTIC
BEGIN
    declare uri varchar(256);
    declare uri_part varchar(32);
    declare n int;
    set n = 0;
    
    repeat
        select parent_id, uri_name into id, uri_part from prefix_category where category_id = id;
        set uri = if(uri is not null, concat(ifnull(uri_part,''), '/', uri), uri_part);
        set n = n + 1;
        until id is null OR n >= 42 END REPEAT;
    return uri;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Структура таблицы `annaflex_category`
--

DROP TABLE IF EXISTS `prefix_category`;
CREATE TABLE IF NOT EXISTS `prefix_category` (
  `category_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `parent_id` int(10) unsigned DEFAULT NULL,
  `xpath` varchar(128) NOT NULL DEFAULT '/' COMMENT 'path from / to this item on category_id, excluding self id (used only parent''s id)',
  `level` smallint(5) unsigned NOT NULL DEFAULT '0',
  `title` varchar(128) NOT NULL,
  `visible` char(0) DEFAULT '' COMMENT 'visible in menu; NULL if false, NOT NULL if true',
  `uri_name` varchar(32) DEFAULT NULL,
  `pagetype` varchar(32) DEFAULT NULL,
  `sort_order` tinyint(3) DEFAULT NULL COMMENT 'Order like: 1, 2, 3, null, null, null, -3, -2, -1; Null-items has no order',
  `access_level` enum('guest','user','admin','su') NOT NULL DEFAULT 'guest',
  `system` char(0) DEFAULT NULL,
  `enabled` char(0) DEFAULT '' COMMENT 'visible in everywhere; NULL if false, NOT NULL if true; when disabled, node is visible in category tree only',
  PRIMARY KEY (`category_id`),
  UNIQUE KEY `parent_uri` (`parent_id`,`uri_name`),
  KEY `xpath` (`xpath`),
  KEY `parent` (`parent_id`),
  KEY `uri_name` (`uri_name`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 AUTO_INCREMENT=42 ;

--
-- Дамп данных таблицы `prefix_category`
--

INSERT INTO `prefix_category` (`category_id`, `parent_id`, `xpath`, `level`, `title`, `visible`, `uri_name`, `pagetype`, `sort_order`, `access_level`, `system`, `enabled`) VALUES
(1, NULL, '/', 0, 'main', NULL, NULL, 'main', NULL, 'guest', '', ''),
(2, NULL, '/', 0, 'Admin', '', 'admin', 'admin-mainpage', -5, 'admin', '', ''),
(3, 2, '/2', 1, 'Login', NULL, 'login', 'admin-login', NULL, 'guest', '', ''),
(4, 2, '/2', 1, 'Logout', NULL, 'logout', 'admin-login', NULL, 'guest', '', ''),
(5, 2, '/2', 1, 'Edit site tree', '', 'tree', 'admin-tree', NULL, 'admin', '', ''),
(6, NULL, '/', 0, 'Docs', '', 'docs', 'products', NULL, 'guest', NULL, ''),
(7, 6, '/6', 1, 'Install', '', 'install', 'products', NULL, 'guest', NULL, '');


-- --------------------------------------------------------

--
-- Структура таблицы `prefix_files`
--

DROP TABLE IF EXISTS `prefix_files`;
CREATE TABLE IF NOT EXISTS `prefix_files` (
  `file_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `category_id` int(10) unsigned NOT NULL,
  `filename` varchar(64) NOT NULL,
  `type` varchar(5) NOT NULL COMMENT 'filetype',
  `size` int(11) NOT NULL COMMENT 'in bytes',
  `description` varchar(255) DEFAULT NULL,
  `access_level` enum('guest','user','admin','su') NOT NULL DEFAULT 'guest',
  PRIMARY KEY (`file_id`),
  KEY `category_id` (`category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;

-- --------------------------------------------------------

--
-- Структура таблицы `prefix_logs`
--

DROP TABLE IF EXISTS `prefix_logs`;
CREATE TABLE IF NOT EXISTS `prefix_logs` (
  `log_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `datetime` datetime NOT NULL,
  `ip` varchar(36) NOT NULL,
  `user` varchar(64) NOT NULL,
  `access_level` enum('guest','user','admin','su') NOT NULL,
  `method` varchar(8) NOT NULL,
  `page` varchar(512) NOT NULL,
  `action` varchar(512) NOT NULL,
  PRIMARY KEY (`log_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='User actions log' AUTO_INCREMENT=1 ;

-- --------------------------------------------------------

--
-- Структура таблицы `prefix_photos`
--

DROP TABLE IF EXISTS `prefix_photos`;
CREATE TABLE IF NOT EXISTS `prefix_photos` (
  `photo_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `category_id` int(10) unsigned DEFAULT NULL,
  `filename` varchar(64) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `pride` char(0) DEFAULT NULL COMMENT 'NULL if false, NOT NULL if true; If true, can be shown on main page',
  PRIMARY KEY (`photo_id`),
  KEY `category` (`category_id`),
  KEY `filename` (`filename`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;

-- --------------------------------------------------------

--
-- Структура таблицы `prefix_texts`
--

DROP TABLE IF EXISTS `prefix_texts`;
CREATE TABLE IF NOT EXISTS `prefix_texts` (
  `text_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `category_id` int(10) unsigned DEFAULT NULL,
  `text` text NOT NULL,
  `type` varchar(32) DEFAULT 'maintext' COMMENT 'Mark to separate types of text on the page',
  PRIMARY KEY (`text_id`),
  KEY `category_id` (`category_id`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;

--
-- Дамп данных таблицы `prefix_texts`
--

INSERT INTO `test_texts` (`text_id`, `category_id`, `text`, `type`) VALUES
(1, NULL, '<p>Contact us&nbsp;<a href="mailto:tricycle@Liksu.kiev.ua"><span style="color: #fac08f;">by e-mail</span></a></p>\n', 'headertext'),
(2, 1, '<p>This is an example site for the&nbsp;«<a href="https://github.com/Liksu/Tricycle">Tricycle</a>» project.</p><p><br></p>', 'maintext'),
(3, 7, '<p>A little later we will add in this section of information on how to install this CMS.<br></p>', 'maintext');

-- --------------------------------------------------------

--
-- Структура таблицы `prefix_users`
--

DROP TABLE IF EXISTS `prefix_users`;
CREATE TABLE IF NOT EXISTS `prefix_users` (
  `user_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `login` varchar(64) NOT NULL,
  `pass` varchar(42) DEFAULT NULL,
  `access_level` enum('user','admin','su') NOT NULL DEFAULT 'user',
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `login_UNIQUE` (`login`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;

--
-- Дамп данных таблицы `prefix_users`
--

INSERT INTO `prefix_users` (`user_id`, `login`, `pass`, `access_level`) VALUES
(32425, 'su', '', 'su');

--
-- Ограничения внешнего ключа сохраненных таблиц
--

--
-- Ограничения внешнего ключа таблицы `prefix_category`
--
ALTER TABLE `prefix_category`
  ADD CONSTRAINT `parent` FOREIGN KEY (`parent_id`) REFERENCES `prefix_category` (`category_id`) ON DELETE CASCADE ON UPDATE NO ACTION;

--
-- Ограничения внешнего ключа таблицы `prefix_files`
--
ALTER TABLE `prefix_files`
  ADD CONSTRAINT `prefix_files_ibfk_1` FOREIGN KEY (`category_id`) REFERENCES `prefix_category` (`category_id`) ON DELETE CASCADE ON UPDATE NO ACTION;

--
-- Ограничения внешнего ключа таблицы `prefix_photos`
--
ALTER TABLE `prefix_photos`
  ADD CONSTRAINT `category` FOREIGN KEY (`category_id`) REFERENCES `prefix_category` (`category_id`) ON DELETE CASCADE ON UPDATE NO ACTION;

--
-- Ограничения внешнего ключа таблицы `prefix_texts`
--
ALTER TABLE `prefix_texts`
  ADD CONSTRAINT `category_id` FOREIGN KEY (`category_id`) REFERENCES `prefix_category` (`category_id`) ON DELETE CASCADE ON UPDATE NO ACTION;
