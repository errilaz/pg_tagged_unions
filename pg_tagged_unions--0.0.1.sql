\echo Use "CREATE EXTENSION pg_tagged_unions" to load this file. \quit
create type union_tag as (
  tag_name    text,
  tag_type    regtype
);

create function create_tagged_union(union_name text, variadic union_tags union_tag[])
returns text as $$
declare
  ddl text := '';
  result text := '';
  build text[];
  check_case text;
  ut union_tag;
  ct union_tag;
begin
  -- NAME_tag enum
  ddl := ddl || format(E'create type %s_tag as enum (\n', union_name);
  build := '{}';
  foreach ut in array union_tags
  loop
    build := build || format(E'  \'%s\'', ut.tag_name);
  end loop;
  ddl := ddl || array_to_string(build, E',\n') || E'\n';
  ddl := ddl || E');\n';
  ddl := ddl || format(E'create domain %s_tag_required as %s_tag not null;\n', union_name, union_name);
  result := result || format(E'created enum %s_tag\n', union_name);
  result := result || format(E'created domain %s_tag_required\n', union_name);

  -- NAME_union composite
  ddl := ddl || format(E'create type %s_union as(\n', union_name);
  ddl := ddl || format(E'  tag %s_tag_required,\n', union_name);
  build := '{}';
  foreach ut in array union_tags
  loop
    build := build || format(E'  %s %I', ut.tag_name, ut.tag_type);  	
  end loop;
  ddl := ddl || array_to_string(build, E',\n');
  ddl := ddl || E'\n);\n';
  result := result || format(E'created composite type %s_union\n', union_name);

  -- NAME domain
  ddl := ddl || format(E'create domain %s\nas %s_union check (\n  (\n', union_name, union_name);
  build := '{}';
  foreach ut in array union_tags
  loop
    check_case := '';
    check_case := check_case || format(E'    (value).tag::text = \'%s\'\n', ut.tag_name);
    foreach ct in array union_tags
    loop
      if ut.tag_name = ct.tag_name then
        check_case := check_case || format(E'    and (value).%s is not null\n', ct.tag_name);
      else
        check_case := check_case || format(E'    and (value).%s is null\n', ct.tag_name);
      end if;
    end loop;
    build := build || check_case;
  end loop;
  ddl := ddl || array_to_string(build, E'  ) or (\n');
  ddl := ddl || E'  )\n)\n';
  result := result || format(E'created domain %s\n', union_name);

  -- Execute
  execute(ddl);
  return result;
end
$$ language plpgsql;

create function drop_tagged_union(union_type regtype, if_exists boolean default false, cascading boolean default false)
returns text as $$
declare
  ddl text := '';
begin
  -- Drop domain
	ddl := ddl || 'drop domain ';
	if if_exists then
	  ddl := ddl || 'if exists ';
	end if;
	ddl := ddl || union_type;
	if cascading then
	  ddl := ddl || ' cascade';
	end if;
	ddl := ddl || E';\n';

	-- Drop composite
	ddl := ddl || 'drop type ';
	if if_exists then
	  ddl := ddl || 'if exists ';
	end if;
	ddl := ddl || format('%s_union', union_type);
	if cascading then
	  ddl := ddl || ' cascade';
	end if;
	ddl := ddl || E';\n';
	
	-- Drop enum domain
  ddl := ddl || 'drop domain ';
  if if_exists then
    ddl := ddl || 'if exists ';
  end if;
  ddl := ddl || format('%s_tag_required', union_type);
  if cascading then
    ddl := ddl || ' cascade';
  end if;
  ddl := ddl || E';\n';

  -- Drop enum
  ddl := ddl || 'drop type ';
  if if_exists then
    ddl := ddl || 'if exists ';
  end if;
  ddl := ddl || format('%s_tag', union_type);
  if cascading then
    ddl := ddl || ' cascade';
  end if;
  ddl := ddl || E';\n';
	
	-- Execute
	execute ddl;
	return ddl;
end
$$ language plpgsql;
