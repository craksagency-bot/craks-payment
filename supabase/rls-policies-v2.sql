-- =====================================================
-- CRAKS PAYMENT MANAGEMENT SYSTEM - RLS POLICIES V2
-- Complete Row Level Security for All Tables
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_bank_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE monthly_calculations ENABLE ROW LEVEL SECURITY;
ALTER TABLE profit_distribution ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_fund ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 1️⃣ USERS TABLE POLICIES
-- =====================================================
-- Admin: Full access
CREATE POLICY "admin_users_all" ON users FOR ALL TO authenticated
    USING (is_admin()) WITH CHECK (is_admin());

-- Advisor: Read only
CREATE POLICY "advisor_users_read" ON users FOR SELECT TO authenticated
    USING (is_advisor());

-- Member: Read own data only
CREATE POLICY "member_users_own" ON users FOR SELECT TO authenticated
    USING (id = auth.uid());

-- =====================================================
-- 2️⃣ USER BANK DETAILS POLICIES
-- =====================================================
-- Admin: Full access
CREATE POLICY "admin_bank_all" ON user_bank_details FOR ALL TO authenticated
    USING (is_admin()) WITH CHECK (is_admin());

-- Advisor: Read only
CREATE POLICY "advisor_bank_read" ON user_bank_details FOR SELECT TO authenticated
    USING (is_advisor());

-- Member: NO ACCESS (handled by not having a policy)

-- =====================================================
-- 3️⃣ PROJECTS TABLE POLICIES
-- =====================================================
-- Admin: Full access
CREATE POLICY "admin_projects_all" ON projects FOR ALL TO authenticated
    USING (is_admin()) WITH CHECK (is_admin());

-- Advisor: Read only
CREATE POLICY "advisor_projects_read" ON projects FOR SELECT TO authenticated
    USING (is_advisor());

-- =====================================================
-- 4️⃣ PROJECT PAYMENTS POLICIES
-- =====================================================
-- Admin: Full access
CREATE POLICY "admin_payments_all" ON project_payments FOR ALL TO authenticated
    USING (is_admin()) WITH CHECK (is_admin());

-- Advisor: Read only
CREATE POLICY "advisor_payments_read" ON project_payments FOR SELECT TO authenticated
    USING (is_advisor());

-- =====================================================
-- 5️⃣ PROJECT EXPENSES POLICIES
-- =====================================================
-- Admin: Full access
CREATE POLICY "admin_expenses_all" ON project_expenses FOR ALL TO authenticated
    USING (is_admin()) WITH CHECK (is_admin());

-- Advisor: Read only
CREATE POLICY "advisor_expenses_read" ON project_expenses FOR SELECT TO authenticated
    USING (is_advisor());

-- =====================================================
-- 6️⃣ MONTHLY CALCULATIONS POLICIES
-- =====================================================
-- Admin: Full access
CREATE POLICY "admin_monthly_all" ON monthly_calculations FOR ALL TO authenticated
    USING (is_admin()) WITH CHECK (is_admin());

-- Advisor: Read only
CREATE POLICY "advisor_monthly_read" ON monthly_calculations FOR SELECT TO authenticated
    USING (is_advisor());

-- =====================================================
-- 7️⃣ PROFIT DISTRIBUTION POLICIES
-- =====================================================
-- Admin: Full access
CREATE POLICY "admin_distribution_all" ON profit_distribution FOR ALL TO authenticated
    USING (is_admin()) WITH CHECK (is_admin());

-- Advisor: Read only
CREATE POLICY "advisor_distribution_read" ON profit_distribution FOR SELECT TO authenticated
    USING (is_advisor());

-- =====================================================
-- 8️⃣ MEMBER PAYOUTS POLICIES
-- =====================================================
-- Admin: Full access
CREATE POLICY "admin_payouts_all" ON member_payouts FOR ALL TO authenticated
    USING (is_admin()) WITH CHECK (is_admin());

-- Advisor: Read only
CREATE POLICY "advisor_payouts_read" ON member_payouts FOR SELECT TO authenticated
    USING (is_advisor());

-- Member: Read own payouts only
CREATE POLICY "member_payouts_own" ON member_payouts FOR SELECT TO authenticated
    USING (user_id = auth.uid());

-- =====================================================
-- 9️⃣ COMPANY FUND POLICIES
-- =====================================================
-- Admin: Full access
CREATE POLICY "admin_fund_all" ON company_fund FOR ALL TO authenticated
    USING (is_admin()) WITH CHECK (is_admin());

-- Advisor: Read only
CREATE POLICY "advisor_fund_read" ON company_fund FOR SELECT TO authenticated
    USING (is_advisor());

-- =====================================================
-- 🔟 AUDIT LOGS POLICIES
-- =====================================================
-- Admin: Full read access
CREATE POLICY "admin_audit_read" ON audit_logs FOR SELECT TO authenticated
    USING (is_admin());

-- Admin: Insert only (no update/delete)
CREATE POLICY "admin_audit_insert" ON audit_logs FOR INSERT TO authenticated
    WITH CHECK (is_admin_or_advisor() OR auth.uid() IS NOT NULL);

-- Advisor: Read only
CREATE POLICY "advisor_audit_read" ON audit_logs FOR SELECT TO authenticated
    USING (is_advisor());

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grant execute on functions
GRANT EXECUTE ON FUNCTION is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION is_advisor() TO authenticated;
GRANT EXECUTE ON FUNCTION is_admin_or_advisor() TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_role() TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_old_data() TO authenticated;
GRANT EXECUTE ON FUNCTION log_audit() TO authenticated;
