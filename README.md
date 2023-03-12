# pg_tagged_unions

This is an experimental Postgres extension to add [tagged unions](https://en.wikipedia.org/wiki/Tagged_union) (also known as sum types, discriminated unions, disjoint unions, variants, etc.)

## Install

Copy the files in `src/` to the Postgres extension directory (somewhere like `/usr/share/postgresql/extension` or `/usr/local/share/postgresql/extension`), then run:

```sql
create extension pg_tagged_unions;
```

## Usage

This operates on existing user-defined composite types, for instance:

```sql
create type credential_password as (
  password_hash       text,
  last_updated        timestamp
);

create type credential_email as (
  email_address       text,
  verified            boolean
);
```

These are passed to `create_tagged_union`:

```sql
select create_tagged_union('credential',
  row('password', 'credential_password'),
  row('email', 'credential_email')
);
```

This will create a domain called `credential` which is an alias to another composite type (`credential_union`) with a `check` constraint which allows one non-null column which matches the given tag.

```sql
create table example_table(credential credential);
insert into example_table (credential) values (
  row('password', row('my hash', now()), null)
);
insert into example_table (credential) values (
  row('email', null, row('me@example.com', true))
);
```
