-- Create database user and database for Frappe site
-- Run this with: mysql -u root -p < create_db_user.sql
-- OR: sudo mysql < create_db_user.sql

CREATE USER IF NOT EXISTS '_517a1fbab7ba0c04'@'localhost' IDENTIFIED BY 'yIawHBFVcaiAKaJw';
CREATE DATABASE IF NOT EXISTS `_517a1fbab7ba0c04` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON `_517a1fbab7ba0c04`.* TO '_517a1fbab7ba0c04'@'localhost';
FLUSH PRIVILEGES;

