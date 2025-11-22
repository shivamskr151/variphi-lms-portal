-- Create database user and database for Frappe site
-- Run this with: mysql -u root -p < create_db_user.sql
-- OR: sudo mysql < create_db_user.sql

CREATE USER IF NOT EXISTS '_2ca05118bd4124f3'@'localhost' IDENTIFIED BY 'vAhQPAHJpRcIsQmi';
CREATE DATABASE IF NOT EXISTS `_2ca05118bd4124f3` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON `_2ca05118bd4124f3`.* TO '_2ca05118bd4124f3'@'localhost';
FLUSH PRIVILEGES;

