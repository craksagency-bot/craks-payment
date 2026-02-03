-- CRAKS Payment Management System - Row Level Security Policies
-- Run this AFTER schema.sql

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_installments ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_fund ENABLE ROW LEVEL SECURITY;
ALTER TABLE payout_calculations ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;

-- Helper: Check if current user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp;

-- Helper: Check if current user is advisor
CREATE OR REPLACE FUNCTION is_advisor()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'advisor'
  );
$$ LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp;

-- ============ USERS TABLE ============
CREATE POLICY "users_select_own" ON users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "users_admin_all" ON users
  FOR ALL USING (is_admin());

CREATE POLICY "users_advisor_select" ON users
  FOR SELECT USING (is_advisor());

-- ============ PROJECTS TABLE ============
CREATE POLICY "projects_admin_all" ON projects
  FOR ALL USING (is_admin());

CREATE POLICY "projects_advisor_select" ON projects
  FOR SELECT USING (is_advisor());

-- ============ PROJECT_INSTALLMENTS TABLE ============
CREATE POLICY "installments_admin_all" ON project_installments
  FOR ALL USING (is_admin());

CREATE POLICY "installments_advisor_select" ON project_installments
  FOR SELECT USING (is_advisor());

-- ============ EXPENSES TABLE ============
CREATE POLICY "expenses_admin_all" ON expenses
  FOR ALL USING (is_admin());

CREATE POLICY "expenses_advisor_select" ON expenses
  FOR SELECT USING (is_advisor());

-- ============ PAYOUTS TABLE ============
CREATE POLICY "payouts_select_own" ON payouts
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "payouts_admin_all" ON payouts
  FOR ALL USING (is_admin());

CREATE POLICY "payouts_advisor_select" ON payouts
  FOR SELECT USING (is_advisor());

-- ============ COMPANY_FUND TABLE ============
CREATE POLICY "fund_admin_all" ON company_fund
  FOR ALL USING (is_admin());

CREATE POLICY "fund_advisor_select" ON company_fund
  FOR SELECT USING (is_advisor());

-- ============ PAYOUT_CALCULATIONS TABLE ============
CREATE POLICY "calc_admin_all" ON payout_calculations
  FOR ALL USING (is_admin());

CREATE POLICY "calc_advisor_select" ON payout_calculations
  FOR SELECT USING (is_advisor());

-- ============ SYSTEM_SETTINGS TABLE ============
CREATE POLICY "settings_admin_all" ON system_settings
  FOR ALL USING (is_admin());
