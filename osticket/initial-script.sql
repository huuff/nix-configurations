-- osTicket can't login through UNIX socket so it needs an user with a password
CREATE DATABASE osticket;
CREATE USER 'osticket'@'localhost';
GRANT ALL PRIVILEGES ON osticket.* TO 'osticket'@'localhost' IDENTIFIED BY 'password';
