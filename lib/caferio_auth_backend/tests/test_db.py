#!/usr/bin/env python3
"""
Database-level tests for the Caferio auth backend.

Runs against a PostgreSQL database that already has BOTH migrations applied.
Each test runs in its own transaction and is rolled back.

  local Supabase:   CAFERIO_TEST_DSN="postgresql://postgres:postgres@127.0.0.1:54322/postgres" python3 tests/test_db.py
  plain Postgres:   see tests/README (mock schema)  -> dbname=caferio_test user=postgres

The suite impersonates roles the same way PostgREST does (SET LOCAL ROLE +
request.jwt.claims), so RLS, column grants and function privileges are exercised
exactly as a client would hit them.
"""
import json
import os
import sys
import threading
import time
import traceback

import psycopg2
import psycopg2.errors as pgerr
from psycopg2 import sql

DSN = os.environ.get("CAFERIO_TEST_DSN", "dbname=caferio_test user=postgres")

RESULTS = []


# ----------------------------------------------------------------------------- helpers
class Ctx:
    def __init__(self, conn):
        self.conn = conn
        self.cur = conn.cursor()

    def q(self, query, params=None):
        self.cur.execute(query, params)
        try:
            return self.cur.fetchall()
        except psycopg2.ProgrammingError:
            return None

    def one(self, query, params=None):
        rows = self.q(query, params)
        return rows[0][0] if rows else None

    def as_role(self, role, uid=None):
        self.q("reset role")
        claims = {"role": role}
        if uid:
            claims["sub"] = str(uid)
        self.q("select set_config('request.jwt.claims', %s, true)", (json.dumps(claims),))
        self.q(sql.SQL("set local role {}").format(sql.Identifier(role)))

    def su(self):
        self.q("reset role")

    def uid(self, username):
        self.su()
        return self.one("select id from public.profiles where username_normalized = %s", (username.lower(),))

    def expect_error(self, query, params=None, contains=None, sqlstate=None):
        """Run a statement inside a savepoint; it MUST fail."""
        self.q("savepoint sp")
        try:
            self.q(query, params)
        except psycopg2.Error as e:
            self.q("rollback to savepoint sp")
            msg = (e.pgerror or str(e))
            if contains and contains.lower() not in msg.lower():
                raise AssertionError(f"failed, but with unexpected error: {msg.strip()}  (wanted '{contains}')")
            if sqlstate and e.pgcode != sqlstate:
                raise AssertionError(f"failed with sqlstate {e.pgcode}, wanted {sqlstate}: {msg.strip()}")
            return
        self.q("release savepoint sp")
        raise AssertionError(f"statement unexpectedly SUCCEEDED: {query if isinstance(query, str) else query.as_string(self.conn)}")


def test(name):
    def deco(fn):
        fn._name = name
        RESULTS.append([name, fn, None, None])
        return fn
    return deco


def new_user(c, email, username, extra_app=None, provisioned=True, meta=None):
    """Emulates GoTrue's INSERT INTO auth.users for admin.createUser()."""
    app = {"provider": "email", "providers": ["email"]}
    if provisioned:
        app["caferio_provisioned"] = "true"
    if username is not None:
        app["username"] = username
    if extra_app:
        app.update(extra_app)
    c.su()
    return c.one(
        """insert into auth.users (instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
                                  raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
           values ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated','authenticated',
                   %s, extensions.crypt('Correct-Horse-9', extensions.gen_salt('bf')), now(),
                   %s::jsonb, %s::jsonb, now(), now()) returning id""",
        (email, json.dumps(app), json.dumps(meta or {})),
    )


# ----------------------------------------------------------------------------- 1. registration / provisioning
@test("provision: valid user gets profile, role=customer, normalized username")
def _(c):
    uid = new_user(c, "u_a1@x.test", "NewUser", meta={"name": "ignored"})
    row = c.q("select username, username_normalized, role::text, name from public.profiles where id=%s", (uid,))[0]
    assert row[:3] == ("NewUser", "newuser", "customer"), row
    assert c.one("select raw_app_meta_data->>'role' from auth.users where id=%s", (uid,)) == "customer"


@test("provision: display_name lands in profiles.name (server-set)")
def _(c):
    uid = new_user(c, "u_a2@x.test", "Named", extra_app={"display_name": "  Ananya K  "})
    assert c.one("select name from public.profiles where id=%s", (uid,)) == "Ananya K"


@test("provision: duplicate username with different case is rejected (unique) and leaves NO orphan auth user")
def _(c):
    new_user(c, "u_b1@x.test", "Ananya")
    before = c.one("select count(*) from auth.users")
    c.expect_error(
        """insert into auth.users (id,email,raw_app_meta_data) values (gen_random_uuid(),'u_b2@x.test',
           '{"caferio_provisioned":"true","username":"ananya"}')""",
        contains="profiles_username_normalized_key",
    )
    assert c.one("select count(*) from auth.users") == before, "orphan auth.users row left behind"
    assert c.one("select count(*) from auth.users where email='u_b2@x.test'") == 0


@test("provision: GoTrue self-signup (no server flag) is blocked at the DB")
def _(c):
    c.expect_error(
        """insert into auth.users (id,email,raw_app_meta_data,raw_user_meta_data)
           values (gen_random_uuid(),'attacker@x.test','{"provider":"email"}',
                   '{"username":"evil","role":"admin"}')""",
        contains="signup_not_allowed",
    )


@test("provision: anonymous sign-in user is blocked")
def _(c):
    c.expect_error(
        "insert into auth.users (id,is_anonymous,raw_app_meta_data) values (gen_random_uuid(), true, '{}')",
        contains="signup_not_allowed",
    )


@test("provision: client cannot smuggle role=admin through app_metadata at creation")
def _(c):
    uid = new_user(c, "u_c1@x.test", "sneaky1", extra_app={"role": "admin"})
    assert c.one("select role::text from public.profiles where id=%s", (uid,)) == "customer"
    assert c.one("select raw_app_meta_data->>'role' from auth.users where id=%s", (uid,)) == "customer"


BAD_NAMES = ["", "  ", "ab", "a" * 31, "a b", "a;b", "a'b--", "drop table", "é_user", "-abc", "abc-", "_abc", "abc_",
             "abc\n", "ａｄｍｉｎ１", "a@b", "a.b", "<script>", "\u212Aenny", "\u0130stanbul", "caf\u00e9", None]


@test("provision: malformed usernames are all rejected (empty, short, long, spaces, unicode, sql chars, newline)")
def _(c):
    for i, bad in enumerate(BAD_NAMES):
        c.expect_error(
            """insert into auth.users (id,email,raw_app_meta_data)
               values (gen_random_uuid(), %s, %s::jsonb)""",
            (f"bad{i}@x.test", json.dumps({"caferio_provisioned": "true", **({"username": bad} if bad is not None else {})})),
            contains="invalid_username",
        )


@test("provision: reserved usernames rejected in any case")
def _(c):
    for nm in ["Admin", "ROOT", "Support", "caferio", "Chef"]:
        c.expect_error(
            "insert into auth.users (id,email,raw_app_meta_data) values (gen_random_uuid(), %s, %s::jsonb)",
            (f"r_{nm}@x.test", json.dumps({"caferio_provisioned": "true", "username": nm})),
            contains="reserved_username",
        )


@test("provision: boundary usernames accepted (3 chars, 30 chars, hyphen/underscore inside)")
def _(c):
    for i, nm in enumerate(["abc", "a" * 30, "a-b_c", "9lives", "Z9"]):
        if len(nm) < 3:
            c.expect_error("insert into auth.users (id,email,raw_app_meta_data) values (gen_random_uuid(), %s, %s::jsonb)",
                           (f"bd{i}@x.test", json.dumps({"caferio_provisioned": "true", "username": nm})), contains="invalid_username")
        else:
            new_user(c, f"bd{i}@x.test", nm)


@test("table constraints: profile cannot hold mismatched / non-normalized username")
def _(c):
    uid = new_user(c, "u_d1@x.test", "Consistent")
    c.su()
    c.expect_error("update public.profiles set username_normalized='other' where id=%s", (uid,), contains="profiles_username")
    c.expect_error("update public.profiles set username='Consistent ' where id=%s", (uid,), contains="profiles_username")
    c.expect_error("update public.profiles set username='CONSISTENT', username_normalized='CONSISTENT' where id=%s", (uid,),
                   contains="profiles_username")   # format OR consistency check — both reject it


@test("provision: PROFILE FAILURE ROLLS BACK auth user (atomic) — simulated by breaking profiles")
def _(c):
    c.su()
    c.q("alter table public.profiles add constraint tmp_break check (false) not valid")
    before = c.one("select count(*) from auth.users")
    c.expect_error(
        "insert into auth.users (id,email,raw_app_meta_data) values (gen_random_uuid(),'brk@x.test','{\"caferio_provisioned\":\"true\",\"username\":\"brokenone\"}')",
        contains="tmp_break")
    assert c.one("select count(*) from auth.users") == before


# ----------------------------------------------------------------------------- 2. RLS on profiles
@test("RLS: user sees only their own profile")
def _(c):
    a = c.uid("alice")
    c.as_role("authenticated", a)
    rows = c.q("select id from public.profiles")
    assert len(rows) == 1 and rows[0][0] == a, rows


@test("RLS: anon has no access to profiles at all")
def _(c):
    c.as_role("anon")
    c.expect_error("select * from public.profiles", contains="permission denied")
    c.expect_error("insert into public.profiles(id,username,username_normalized) values (gen_random_uuid(),'zz9','zz9')",
                   contains="permission denied")


@test("RLS: user CAN update own name/phone")
def _(c):
    a = c.uid("alice")
    c.as_role("authenticated", a)
    c.q("update public.profiles set name='Alice A', phone='+91 99999 00000' where id=%s", (a,))
    assert c.q("select name, phone from public.profiles where id=%s", (a,)) == [("Alice A", "+91 99999 00000")]


@test("ESCALATION: user cannot set own role (legacy exploit) — column grant + trigger")
def _(c):
    a = c.uid("alice")
    c.as_role("authenticated", a)
    c.expect_error("update public.profiles set role='admin' where id=%s", (a,), contains="permission denied")
    c.expect_error("update public.profiles set role='admin', name='x' where id=%s", (a,), contains="permission denied")
    c.su()
    assert c.one("select role::text from public.profiles where id=%s", (a,)) == "customer"


@test("ESCALATION: guard trigger blocks role change even if column grant were widened")
def _(c):
    a = c.uid("alice")
    c.su()
    c.q("grant update on public.profiles to authenticated")   # simulate a future mistake
    c.as_role("authenticated", a)
    c.expect_error("update public.profiles set role='admin' where id=%s", (a,), contains="profile_privileged_column")
    c.expect_error("update public.profiles set restaurant_id=gen_random_uuid() where id=%s", (a,))
    c.expect_error("update public.profiles set username='hacker9' , username_normalized='hacker9' where id=%s", (a,),
                   contains="profile_identity_immutable")
    c.expect_error("update public.profiles set id=gen_random_uuid() where id=%s", (a,), contains="profile_identity_immutable")


@test("INTEGRITY: user cannot change username / id / restaurant_id / created_at")
def _(c):
    a = c.uid("alice")
    c.as_role("authenticated", a)
    for col, val in [("username", "'alice2'"), ("username_normalized", "'alice2'"), ("id", "gen_random_uuid()"),
                     ("restaurant_id", "gen_random_uuid()"), ("created_at", "now()")]:
        c.expect_error(f"update public.profiles set {col}={val} where id=%s", (a,), contains="permission denied")


@test("IDOR: user cannot read or modify another user's profile by UUID")
def _(c):
    a, b = c.uid("alice"), c.uid("bob_1")
    c.as_role("authenticated", a)
    assert c.q("select * from public.profiles where id=%s", (b,)) == []
    assert c.q("update public.profiles set name='pwned' where id=%s returning id", (b,)) == []
    c.su()
    assert c.one("select coalesce(name,'') from public.profiles where id=%s", (b,)) != "pwned"


@test("RLS: user cannot insert or delete profiles")
def _(c):
    a = c.uid("alice")
    c.as_role("authenticated", a)
    c.expect_error("insert into public.profiles(id,username,username_normalized) values (%s,'zz9','zz9')", (a,), contains="permission denied")
    c.expect_error("delete from public.profiles where id=%s", (a,), contains="permission denied")


@test("RLS: authenticated cannot touch auth.users (no metadata / e-mail tampering from SQL)")
def _(c):
    a = c.uid("alice")
    c.as_role("authenticated", a)
    c.expect_error("update auth.users set raw_app_meta_data = '{\"role\":\"admin\"}' where id=%s", (a,), contains="permission denied")
    c.expect_error("select email from auth.users", contains="permission denied")


@test("RLS: admin can read all profiles but cannot write role directly; manager sees own-restaurant non-admins only")
def _(c):
    c.su()
    rid = c.one("insert into public.restaurants(name) values ('R1') returning id")
    rid2 = c.one("insert into public.restaurants(name) values ('R2') returning id")
    adm = c.uid("mallory")   # customer after migration; promote for this test
    c.q("select private.bootstrap_set_role('mallory','admin')")
    mgr, k1, bob = c.uid("kitchen1"), c.uid("kitchen1"), c.uid("bob_1")
    c.q("select private.bootstrap_set_role('kitchen1','manager')")
    c.q("update public.profiles set restaurant_id=%s where id in (%s,%s)", (rid, mgr, bob))
    c.q("update public.profiles set restaurant_id=%s where username_normalized='alice'", (rid2,))
    c.q("update public.profiles set restaurant_id=%s where id=%s", (rid, adm))
    total = c.one("select count(*) from public.profiles")
    c.as_role("authenticated", adm)
    assert c.one("select count(*) from public.profiles") == total
    c.expect_error("update public.profiles set role='kitchen' where id=%s", (bob,), contains="permission denied")
    c.as_role("authenticated", mgr)
    names = {r[0] for r in c.q("select username_normalized from public.profiles")}
    assert names == {"kitchen1", "bob_1"}, names  # not alice (other restaurant), not the admin (same restaurant)


# ----------------------------------------------------------------------------- 3. role administration
@test("ROLES: customer cannot call admin_set_user_role; anon cannot")
def _(c):
    a, b = c.uid("alice"), c.uid("bob_1")
    c.as_role("authenticated", a)
    c.expect_error("select public.admin_set_user_role(%s,'admin')", (b,), contains="forbidden")
    c.expect_error("select public.admin_set_user_role(%s,'admin')", (a,), contains="forbidden")
    c.as_role("anon")
    c.expect_error("select public.admin_set_user_role(%s,'admin')", (b,), contains="permission denied")


@test("ROLES: admin can set role; JWT app_metadata mirrored; cannot change own role; unknown user errors")
def _(c):
    c.su()
    c.q("select private.bootstrap_set_role('mallory','admin')")
    adm, b = c.uid("mallory"), c.uid("bob_1")
    c.as_role("authenticated", adm)
    c.q("select public.admin_set_user_role(%s,'kitchen')", (b,))
    c.su()
    assert c.one("select role::text from public.profiles where id=%s", (b,)) == "kitchen"
    assert c.one("select raw_app_meta_data->>'role' from auth.users where id=%s", (b,)) == "kitchen"
    c.as_role("authenticated", adm)
    c.expect_error("select public.admin_set_user_role(%s,'customer')", (adm,), contains="cannot_change_own_role")
    c.expect_error("select public.admin_set_user_role(gen_random_uuid(),'kitchen')", contains="user_not_found")


@test("ROLES: role is read from profiles table — a forged JWT role claim grants nothing")
def _(c):
    a = c.uid("alice")
    c.su()
    c.q("select set_config('request.jwt.claims', %s, true)",
        (json.dumps({"sub": str(a), "role": "authenticated", "app_metadata": {"role": "admin"}, "user_metadata": {"role": "admin"}}),))
    c.q("set local role authenticated")
    assert c.one("select private.current_app_role()::text") == "customer"
    assert c.one("select private.is_staff()") is False


@test("ROLES: bootstrap_set_role is not callable by clients or service_role")
def _(c):
    for r in ("anon", "authenticated", "service_role"):
        c.as_role(r, c.uid("alice") if r == "authenticated" else None)
        c.expect_error("select private.bootstrap_set_role('alice','admin')")


# ----------------------------------------------------------------------------- 4. service-only RPCs
INTERNAL = [
    ("select public.internal_resolve_login_identity('alice')", None),
    ("select public.internal_username_available('zebra99')", None),
    ("select public.internal_username_of(gen_random_uuid())", None),
    ("select public.internal_rate_limit('k',5,60)", None),
    ("select public.internal_rate_limit_reset('k')", None),
    ("select public.internal_revoke_sessions(gen_random_uuid())", None),
]


@test("RPC: internal_* functions are NOT callable by anon or authenticated (no username enumeration / alias leak)")
def _(c):
    a = c.uid("alice")
    for role in ("anon", "authenticated"):
        for stmt, _ in INTERNAL:
            c.as_role(role, a if role == "authenticated" else None)
            c.expect_error(stmt, contains="permission denied")


@test("RPC: service_role can call internal_* ; resolve is case-insensitive and returns alias only")
def _(c):
    c.as_role("service_role")
    import re as _re
    a1 = c.one("select public.internal_resolve_login_identity('ALICE')")
    assert _re.fullmatch(r"u[0-9a-f]{32}@caferio-auth\.invalid", a1), a1     # rotated, random, unrelated to username
    assert c.one("select public.internal_resolve_login_identity('  alice ')") == a1
    assert c.one("select public.internal_resolve_login_identity('nobody-here')") is None
    assert c.one("select public.internal_resolve_login_identity(null)") is None
    assert c.one("select public.internal_resolve_login_identity($$'; drop table public.profiles;--$$)") is None
    assert c.one("select to_regclass('public.profiles') is not null") is True


@test("RPC: internal_username_available (taken, case, invalid, reserved, free)")
def _(c):
    c.as_role("service_role")
    f = lambda n: c.one("select public.internal_username_available(%s)", (n,))
    assert f("Alice") is False and f("alice") is False
    assert f("free_name") is True
    assert f("x") is False and f("a b") is False and f("admin") is False and f("") is False and f(None) is False


@test("RPC: rate limiter — allows N, blocks N+1, resets, window expires")
def _(c):
    c.as_role("service_role")
    rl = lambda k, n=3, w=60: c.one("select public.internal_rate_limit(%s,%s,%s)", (k, n, w))
    assert [rl("t:1"), rl("t:1"), rl("t:1"), rl("t:1"), rl("t:1")] == [True, True, True, False, False]
    assert rl("t:other") is True   # independent key
    c.q("select public.internal_rate_limit_reset('t:1')")
    assert rl("t:1") is True
    c.su()
    c.q("update private.auth_rate_limits set window_start = now() - interval '2 minutes' where key='t:1'")
    c.as_role("service_role")
    assert rl("t:1") is True and rl("t:1") is True and rl("t:1") is True and rl("t:1") is False
    c.expect_error("select public.internal_rate_limit(repeat('x',201),1,1)", contains="bad_rate_limit_args")
    c.expect_error("select public.internal_rate_limit('k',0,1)", contains="bad_rate_limit_args")


@test("RPC: rate limit table is not reachable by clients")
def _(c):
    for r in ("anon", "authenticated"):
        c.as_role(r, c.uid("alice") if r == "authenticated" else None)
        c.expect_error("select * from private.auth_rate_limits", contains="permission denied")


@test("RPC: revoke_sessions honours 'except current session'")
def _(c):
    a = c.uid("alice")
    c.su()
    keep = c.one("insert into auth.sessions(user_id) values (%s) returning id", (a,))
    c.q("insert into auth.sessions(user_id) values (%s),(%s)", (a, a))
    c.as_role("service_role")
    assert c.one("select public.internal_revoke_sessions(%s,%s)", (a, keep)) == 2
    c.su()
    assert c.q("select id from auth.sessions where user_id=%s", (a,)) == [(keep,)]


# ----------------------------------------------------------------------------- 5. legacy clean-up verification
@test("LEGACY: mallory's self-assigned admin role was reset; weak seeded admin/chef banned + sessions revoked")
def _(c):
    c.su()
    assert c.one("select role::text from public.profiles where username_normalized='mallory'") == "customer"
    for un in ("admin", "chef"):
        bu = c.one("select u.banned_until from auth.users u join public.profiles p on p.id=u.id where p.username_normalized=%s", (un,))
        assert bu is not None and bu.year >= 2999, (un, bu)
    assert c.one("select count(*) from auth.sessions s join public.profiles p on p.id=s.user_id where p.username_normalized in ('admin','chef')") == 0
    # the strong-password kitchen account is untouched
    assert c.one("select u.banned_until from auth.users u join public.profiles p on p.id=u.id where p.username_normalized='kitchen1'") is None
    assert c.one("select role::text from public.profiles where username_normalized='kitchen1'") == "kitchen"


@test("LEGACY: usernames backfilled uniquely (Dave vs dave), invalid names replaced, email column gone")
def _(c):
    c.su()
    assert c.one("select count(*) from public.profiles") == c.one("select count(distinct username_normalized) from public.profiles")
    assert c.one("select count(*) from public.profiles where username_normalized <> lower(username)") == 0
    assert c.one("select count(*) from information_schema.columns where table_schema='public' and table_name='profiles' and column_name='email'") == 0
    assert c.one("select count(*) from public.profiles where username_normalized in ('alice','bob_1','kitchen1')") == 3


@test("LEGACY: no account keeps a predictable alias; identities updated consistently; logins map still 1:1")
def _(c):
    c.su()
    assert c.one("select count(*) from auth.users where email like '%@myapp.app'") == 0
    assert c.one("select count(*) from auth.users where email !~ '^u[0-9a-f]{32}@'") == 0
    assert c.one("select count(*) from auth.identities i join auth.users u on u.id=i.user_id where i.identity_data->>'email' <> u.email") == 0
    assert c.one("select count(distinct email) from auth.users") == c.one("select count(*) from auth.users")


@test("LEGACY: forgeable helpers and old trigger are gone")
def _(c):
    c.su()
    assert c.one("select to_regprocedure('public.get_user_role(uuid)') is null") is True
    assert c.one("select to_regprocedure('public.handle_new_user()') is null") is True
    assert c.one("select to_regprocedure('auth.user_role()') is null") is True
    assert c.one("select count(*) from pg_trigger where tgname='on_auth_user_created'") == 0


# ----------------------------------------------------------------------------- 6. orders & friends
def mk_order(c, customer, status="received"):
    c.su()
    return c.one("insert into public.orders(customer_id,status,total_amount) values (%s,%s,10) returning id", (customer, status))


@test("DATA: anon cannot read or write orders / order_items / purchases / stats / sales")
def _(c):
    c.as_role("anon")
    for stmt in ["select * from public.orders", "insert into public.orders(status,total_amount) values ('received',1)",
                 "select * from public.order_items", "select * from public.customer_purchases",
                 "select * from public.customer_behaviour_stats", "select * from public.sales",
                 "select * from public.ingredients", "select * from public.users", "select * from public.menu_items"]:
        c.expect_error(stmt, contains="permission denied")


@test("DATA: customer places own order; cannot spoof another customer or pre-set status")
def _(c):
    a, b = c.uid("alice"), c.uid("bob_1")
    c.as_role("authenticated", a)
    c.q("insert into public.orders(customer_id,status,total_amount) values (%s,'received',12.5)", (a,))
    c.expect_error("insert into public.orders(customer_id,status,total_amount) values (%s,'received',1)", (b,), contains="row-level security")
    c.expect_error("insert into public.orders(customer_id,status,total_amount) values (%s,'served',1)", (a,), contains="row-level security")
    c.expect_error("insert into public.orders(status,total_amount) values ('received',1)", contains="row-level security")  # NULL owner
    c.expect_error("insert into public.orders(customer_id,status,total_amount,served_at) values (%s,'received',1,now())", (a,), contains="permission denied")


@test("DATA: customers see only own orders; staff see all; customer cannot change status; kitchen can")
def _(c):
    a, b, k = c.uid("alice"), c.uid("bob_1"), c.uid("kitchen1")
    oa, ob = mk_order(c, a), mk_order(c, b)
    c.as_role("authenticated", a)
    assert [r[0] for r in c.q("select id from public.orders")] == [oa]
    assert c.q("update public.orders set status='served' where id=%s returning id", (oa,)) == [], "customer changed an order status"
    c.expect_error("delete from public.orders where id=%s", (oa,), contains="permission denied")
    c.as_role("authenticated", k)
    assert {r[0] for r in c.q("select id from public.orders")} >= {oa, ob}
    assert len(c.q("update public.orders set status='preparing' where id=%s returning id", (ob,))) == 1
    c.expect_error("update public.orders set customer_id=%s where id=%s", (k, ob), contains="permission denied")


@test("DATA: order_items follow order ownership (own order yes, someone else's order no)")
def _(c):
    a, b = c.uid("alice"), c.uid("bob_1")
    oa, ob = mk_order(c, a), mk_order(c, b)
    c.as_role("authenticated", a)
    c.q("insert into public.order_items(order_id,menu_item_id,quantity) values (%s,'1',2)", (oa,))
    c.expect_error("insert into public.order_items(order_id,menu_item_id,quantity) values (%s,'1',2)", (ob,), contains="row-level security")
    c.expect_error("insert into public.order_items(order_id,menu_item_id,quantity) values (%s,'1',0)", (oa,), contains="row-level security")
    c.su()
    c.q("insert into public.order_items(order_id,menu_item_id,quantity) values (%s,'9',1)", (ob,))
    c.as_role("authenticated", a)
    assert {r[0] for r in c.q("select menu_item_id from public.order_items")} == {"1"}
    c.expect_error("delete from public.order_items", contains="permission denied")


@test("DATA: customer_purchases own-row only (read + write)")
def _(c):
    a, b = c.uid("alice"), c.uid("bob_1")
    c.as_role("authenticated", a)
    c.q("insert into public.customer_purchases(customer_id,item_id,item_name,category) values (%s,'1','Tea','Drinks')", (a,))
    c.expect_error("insert into public.customer_purchases(customer_id,item_id,item_name,category) values (%s,'1','Tea','Drinks')", (b,),
                   contains="row-level security")
    c.su()
    c.q("insert into public.customer_purchases(customer_id,item_id,item_name,category) values (%s,'2','Cake','Desserts')", (b,))
    c.as_role("authenticated", a)
    assert {r[0] for r in c.q("select item_name from public.customer_purchases")} == {"Tea"}
    c.expect_error("update public.customer_purchases set item_name='x'", contains="permission denied")


@test("IDOR: recommendation RPCs enforce p_customer_id = auth.uid()")
def _(c):
    a, b = c.uid("alice"), c.uid("bob_1")
    c.as_role("authenticated", a)
    items = json.dumps([{"item_id": "1", "item_name": "Tea", "category": "Drinks", "quantity": 1, "price": 3}])
    # own id must get PAST the guard. (The legacy impl body has an unrelated pre-existing bug —
    # missing FROM in freq_items CTE — so it may raise "item_id does not exist"; that is fine here.)
    c.q("savepoint own")
    try:
        c.q("select public.record_order_purchases(%s::uuid, %s::uuid, %s::jsonb, 3)", (None, a, items))
    except psycopg2.Error as e:
        assert "forbidden" not in (e.pgerror or ""), "own call was wrongly forbidden"
        c.q("rollback to savepoint own")
    c.expect_error("select public.record_order_purchases(%s::uuid, %s::uuid, %s::jsonb, 3)", (None, b, items), contains="forbidden")
    c.expect_error("select public.get_customer_behaviour_insights(%s::uuid)", (b,), contains="forbidden")
    c.q("select * from public.get_customer_behaviour_insights(%s::uuid)", (a,))
    c.expect_error("select * from public.get_personalized_recommendations(%s::uuid, '{}'::text[], 3)", (b,), contains="forbidden")
    c.q("select * from public.get_personalized_recommendations(%s::uuid, '{}'::text[], 3)", (a,))
    c.q("select * from public.get_personalized_recommendations(null::uuid, '{}'::text[], 3)")                  # generic recs ok
    # the raw implementations are not reachable
    c.expect_error("select public.record_order_purchases_impl(null::uuid, %s::uuid, %s::jsonb, 3)", (b, items), contains="permission denied")
    c.as_role("anon")
    c.expect_error("select public.record_order_purchases(null::uuid, %s::uuid, %s::jsonb, 3)", (a, items), contains="permission denied")
    c.expect_error("select public.get_customer_behaviour_insights(%s::uuid)", (a,), contains="permission denied")


# ----------------------------------------------------------------------------- 7. deletion / cascade
@test("CASCADE: deleting the auth user removes profile + purchases + stats, orphans nothing, keeps orders (customer_id NULL)")
def _(c):
    a = c.uid("alice")
    oa = mk_order(c, a)
    c.q("insert into public.customer_purchases(customer_id,item_id,item_name,category) values (%s,'1','Tea','x')", (a,))
    c.q("delete from auth.users where id=%s", (a,))
    assert c.one("select count(*) from public.profiles where id=%s", (a,)) == 0
    assert c.one("select count(*) from public.customer_purchases where customer_id=%s", (a,)) == 0
    assert c.one("select customer_id from public.orders where id=%s", (oa,)) is None
    assert c.one("select count(*) from public.profiles p left join auth.users u on u.id=p.id where u.id is null") == 0


# ----------------------------------------------------------------------------- 8. schema audit
@test("AUDIT: no policy uses USING(true)/CHECK(true) except the reviewed ones; anon owns no table privileges")
def _(c):
    c.su()
    rows = c.q("""select tablename, policyname from pg_policies
                  where schemaname='public' and (qual = 'true' or with_check = 'true')""")
    allowed = {("restaurants", "restaurants_select_authenticated"), ("item_co_occurrences", "item_co_occurrences_select"),
               ("menu_items", "menu_items_select")}
    assert set(rows) <= allowed, set(rows) - allowed
    anon = c.q("""select table_name, privilege_type from information_schema.role_table_grants
                  where grantee='anon' and table_schema in ('public','private')""")
    assert anon == [], anon


@test("AUDIT: every public table has RLS enabled")
def _(c):
    c.su()
    rows = c.q("select tablename from pg_tables where schemaname in ('public','private') and not rowsecurity")
    assert rows == [], rows


@test("AUDIT: every SECURITY DEFINER function pins search_path")
def _(c):
    c.su()
    rows = c.q("""select p.oid::regprocedure::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                  where n.nspname in ('public','private') and p.prosecdef
                    and not exists (select 1 from unnest(coalesce(p.proconfig,'{}')) cfg where cfg like 'search_path=%')""")
    assert rows == [], rows


@test("AUDIT: no password / hash column anywhere in application tables")
def _(c):
    c.su()
    rows = c.q("""select table_name, column_name from information_schema.columns
                  where table_schema in ('public','private') and column_name ~* '(pass|pwd|hash|secret|token)'""")
    assert rows == [], rows


@test("AUDIT: SECURITY DEFINER functions callable by anon = none")
def _(c):
    c.su()
    rows = c.q("""select p.oid::regprocedure::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                  where n.nspname='public' and p.prosecdef and has_function_privilege('anon', p.oid, 'execute')""")
    assert rows == [], rows


# ----------------------------------------------------------------------------- concurrency (separate connections)
def concurrency_test():
    """Two registrations of the same username race; exactly one must win."""
    name = "racer_" + str(int(time.time()))
    out = []
    barrier = threading.Barrier(2)

    def worker(i):
        conn = psycopg2.connect(DSN)
        conn.autocommit = False
        cur = conn.cursor()
        try:
            barrier.wait()
            cur.execute(
                """insert into auth.users (id,email,raw_app_meta_data) values (gen_random_uuid(), %s, %s::jsonb)""",
                (f"race{i}_{name}@x.test", json.dumps({"caferio_provisioned": "true", "username": name if i == 0 else name.upper()})))
            time.sleep(0.3)      # hold the transaction open so the other has to wait on the unique index
            conn.commit()
            out.append("ok")
        except psycopg2.errors.UniqueViolation:
            conn.rollback()
            out.append("unique_violation")
        except Exception as e:  # noqa
            conn.rollback()
            out.append(repr(e))
        finally:
            conn.close()

    ts = [threading.Thread(target=worker, args=(i,)) for i in range(2)]
    [t.start() for t in ts]
    [t.join() for t in ts]
    conn = psycopg2.connect(DSN)
    cur = conn.cursor()
    cur.execute("select count(*) from public.profiles where username_normalized=%s", (name,))
    n = cur.fetchone()[0]
    cur.execute("select count(*) from auth.users where email like %s", (f"race%_{name}@x.test",))
    users = cur.fetchone()[0]
    cur.execute("delete from auth.users where email like %s", (f"race%_{name}@x.test",))
    conn.commit()
    conn.close()
    assert sorted(out) == ["ok", "unique_violation"], out
    assert n == 1 and users == 1, (n, users)


# ----------------------------------------------------------------------------- runner
def main():
    conn = psycopg2.connect(DSN)
    conn.autocommit = False
    failed = 0
    for entry in RESULTS:
        name, fn = entry[0], entry[1]
        c = Ctx(conn)
        try:
            fn(c)
            entry[2] = True
        except Exception as e:  # noqa
            entry[2] = False
            entry[3] = "".join(traceback.format_exception_only(type(e), e)).strip()
            failed += 1
        finally:
            conn.rollback()
    conn.close()

    try:
        concurrency_test()
        RESULTS.append(["concurrency: 2 simultaneous registrations of the same username -> exactly one wins", None, True, None])
    except Exception as e:  # noqa
        RESULTS.append(["concurrency: 2 simultaneous registrations of the same username -> exactly one wins", None, False, repr(e)])
        failed += 1

    width = max(len(r[0]) for r in RESULTS)
    for name, _, ok, err in RESULTS:
        print(("PASS  " if ok else "FAIL  ") + name)
        if not ok:
            print("        -> " + str(err))
    print(f"\n{len(RESULTS) - failed}/{len(RESULTS)} passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
