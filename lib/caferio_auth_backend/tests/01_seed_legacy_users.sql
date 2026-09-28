-- Simulates users created by the OLD flow (predictable @myapp.app aliases,
-- old handle_new_user trigger) plus pre-existing abuse, so the migration can be
-- tested against a realistic dirty database.
do $$
declare
  u record;
  uid uuid;
begin
  for u in select * from (values
    -- email                 password              app_meta role   username meta
    ('alice@myapp.app',      'alicepass1',         null,           'alice'),
    ('bob_1@myapp.app',      'bobpass123',         null,           'bob_1'),
    ('mallory@myapp.app',    'mallorypass1',       null,           'mallory'),
    ('kitchen1@myapp.app',   'Str0ng-Kitchen-pw!', 'kitchen',      'kitchen1'),
    ('dave@myapp.app',       'davepass123',        null,           'Dave'),
    ('dave2@myapp.app',      'davepass456',        null,           'dave'),
    ('weird@myapp.app',      'weirdpass12',        null,           'a b!')
  ) as t(email, pw, app_role, uname)
  loop
    uid := gen_random_uuid();
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                            raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values ('00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', u.email,
            extensions.crypt(u.pw, extensions.gen_salt('bf')), now(),
            jsonb_build_object('provider','email','providers',array['email'])
              || case when u.app_role is null then '{}'::jsonb else jsonb_build_object('role', u.app_role) end,
            jsonb_build_object('username', u.uname),
            now() + (random() * interval '1 second'), now());
  end loop;
end $$;

-- mallory self-escalated via the old "Users can update own profile" policy
update public.profiles set role = 'admin' where username = 'mallory';
-- a couple of sessions for the seeded weak accounts
insert into auth.sessions (user_id)
select id from auth.users where email in ('admin@myapp.app','chef@myapp.app');
