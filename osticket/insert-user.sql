start transaction;
insert into ost_user (org_id, default_email_id, name, created, updated) values (0, 0, "Testman", now(), now());
select last_insert_id() into @user_id;
insert into ost_user_email (user_id, address) values (last_insert_id(), "test@example.org");
select last_insert_id() into @email_id;
update ost_user set default_email_id=@email_id where id=@user_id;
insert into ost_user_account (user_id, status, passwd) values (@user_id, 1, <htpasswd hash>);
commit;
