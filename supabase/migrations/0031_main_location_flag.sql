-- HydroTrack — 0031: mark each organization's main location explicitly
-- (picking the oldest is ambiguous when two are created at once).
alter table locations add column is_main boolean not null default false;
update locations l set is_main = true
where l.id = (select l2.id from locations l2 where l2.tenant_id = l.tenant_id
              and l2.name = 'Main factory' order by l2.created_at, l2.id limit 1);
create unique index locations_one_main on locations (tenant_id) where is_main;

create or replace function create_main_location()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into locations (tenant_id, name, is_main) values (new.id, 'Main factory', true);
  return new;
end;
$$;

create or replace function main_location(p_tenant_id uuid)
returns uuid
language sql stable
security definer set search_path = public
as $$
  select id from locations where tenant_id = p_tenant_id
  order by is_main desc, is_active desc, created_at, id limit 1;
$$;
