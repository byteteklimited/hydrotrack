-- HydroTrack — 0024: pin subscription_ends_at's search_path (flagged by
-- `supabase db advisors`; it only reads its argument's columns).
alter function subscription_ends_at(tenant_subscriptions) set search_path = '';
