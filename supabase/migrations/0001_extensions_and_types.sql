-- HydroTrack — 0001: extensions and enum types.
--
-- Fresh, consolidated schema for the multi-tenant hydrotrack project.
-- Folds in the final behaviour of the 30 single-tenant migrations it
-- replaces; nothing here assumes any data already exists.

create extension if not exists pgcrypto with schema extensions;

-- Roles are per tenant (tenant_members.role). `owner` is new for
-- multi-tenancy: it can do everything an admin can, plus manage other
-- owners. The other four keep their original meanings.
create type staff_role as enum ('owner', 'admin', 'manager', 'cashier', 'store_keeper');

-- Fixed product sizes, shared by every tenant for now (per-tenant product
-- catalogs are deliberately deferred).
create type product_type as enum ('sachet50cl', 'bottle75cl', 'bottle1_5l', 'bottle5l');

create type production_shift as enum ('morning', 'afternoon');
create type stock_category as enum ('raw_material', 'finished_goods');
create type movement_type as enum ('stock_in', 'stock_out', 'adjustment', 'production_use');
create type sales_customer_type as enum ('walk_in', 'distributor');
create type sales_payment_method as enum ('cash', 'transfer', 'part', 'credit');
create type ledger_entry_type as enum ('sale', 'payment', 'voided', 'opening_balance', 'write_off');
create type payment_channel as enum ('cash', 'transfer');
create type cash_direction as enum ('money_in', 'money_out');
create type cash_source as enum
  ('sales', 'debt_payment', 'expense', 'wages', 'owner_drawing', 'other');
create type load_out_status as enum ('on_road', 'settled');
create type expense_category as enum
  ('electricity', 'fuel_diesel', 'maintenance', 'wages', 'materials_purchase', 'transport', 'other');
