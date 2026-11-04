-- HydroTrack — 0035: each organization's brand colors (white label).
-- Name and logo already live on tenants; these are the main and accent
-- colors (#RRGGBB). Null = HydroTrack's own navy and cyan. Owners and
-- admins change them (tenants update policy); offline devices get them
-- with the organization.
alter table tenants
  add column brand_primary text check (brand_primary ~ '^#[0-9A-Fa-f]{6}$'),
  add column brand_accent text check (brand_accent ~ '^#[0-9A-Fa-f]{6}$');
