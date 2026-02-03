-- CRAKS Payment Management System - Seed Data (Optional Demo Data)
-- Run AFTER schema.sql and rls-policies.sql
-- NOTE: You must first create auth users in Supabase Auth dashboard,
-- then use their UUIDs below.

-- Replace these UUIDs with actual auth user IDs from Supabase Auth
-- After creating users in Auth, insert matching records here:

-- INSERT INTO users (id, email, full_name, phone, role) VALUES
--   ('FOUNDER_AUTH_UUID', 'ishaq@craks.com', 'Ishaq', '+94XXXXXXXXX', 'admin'),
--   ('ADVISOR_AUTH_UUID', 'advisor@craks.com', 'Chief Advisor', '+94XXXXXXXXX', 'advisor'),
--   ('MEMBER1_AUTH_UUID', 'member1@craks.com', 'Team Member 1', '+94XXXXXXXXX', 'team'),
--   ('MEMBER2_AUTH_UUID', 'member2@craks.com', 'Team Member 2', '+94XXXXXXXXX', 'team');

-- Sample system settings
INSERT INTO system_settings (setting_key, setting_value) VALUES
  ('currency', 'LKR'),
  ('retention_months', '6'),
  ('payout_day', '15');
