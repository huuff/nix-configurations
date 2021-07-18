#!/usr/bin/env bash
curl localhost:8989/setup/install.php -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "s=install&name=Sitename&email=admin@email.com&fname=Adminfname&lname=Adminlname&admin2@email.com&username=adminuser&passwd=password&passwd2=password&prefix=ost_&dbhost=localhost&dbname=osticket&dbuser=osticket&dbpass=password&admin_email=adminemail@email.com"
