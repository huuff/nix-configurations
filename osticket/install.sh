#!/usr/bin/env bash
curl localhost:8989/setup/install.php \
  -F "s=install" \
  -F "name=Site Name" \
  -F "email=sitemail@example.org" \
  -F "fname=AdminFirstname" \
  -F "lname=AdnminLastname" \
  -F "admin_email=adminemail@example.org" \
  -F "username=adminuser" \
  -F "passwd=adminpass" \
  -F "passwd2=adminpass" \
  -F "prefix=ost_" \
  -F "dbhost=localhost" \
  -F "dbname=osticket" \
  -F "dbuser=osticket" \
  -F "dbpass=password"
