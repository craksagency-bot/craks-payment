-- =====================================================
-- PART 2: FUNCTIONS & RLS - Run this AFTER Part 1
-- =====================================================

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Check admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'ADMIN' AND status = 'ACTIVE');
END;
$$;

-- Check advisor
CREATE OR REPLACE FUNCTION is_advisor()
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'ADVISOR' AND status = 'ACTIVE');
END;
$$;

-- Check admin or advisor
CREATE OR REPLACE FUNCTION is_admin_or_advisor()
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('ADMIN', 'ADVISOR') AND status = 'ACTIVE');
END;
$$;

-- =====================================================
-- ENABLE RLS
-- =====================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_bank_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_member_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE monthly_calculations ENABLE ROW LEVEL SECURITY;
ALTER TABLE profit_distribution ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_fund ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- RLS POLICIES
-- =====================================================

-- Users
CREATE POLICY "users_select" ON users FOR SELECT TO authenticated USING (true);
CREATE POLICY "users_insert" ON users FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "users_update" ON users FOR UPDATE TO authenticated USING (is_admin() OR id = auth.uid());
CREATE POLICY "users_delete" ON users FOR DELETE TO authenticated USING (is_admin());

-- Bank details
CREATE POLICY "bank_select" ON user_bank_details FOR SELECT TO authenticated USING (is_admin() OR user_id = auth.uid());
CREATE POLICY "bank_insert" ON user_bank_details FOR INSERT TO authenticated WITH CHECK (is_admin());
CREATE POLICY "bank_update" ON user_bank_details FOR UPDATE TO authenticated USING (is_admin());
CREATE POLICY "bank_delete" ON user_bank_details FOR DELETE TO authenticated USING (is_admin());

-- Projects
CREATE POLICY "proj_select" ON projects FOR SELECT TO authenticated USING (true);
CREATE POLICY "proj_insert" ON projects FOR INSERT TO authenticated WITH CHECK (is_admin());
CREATE POLICY "proj_update" ON projects FOR UPDATE TO authenticated USING (is_admin());
CREATE POLICY "proj_delete" ON projects FOR DELETE TO authenticated USING (is_admin());

-- Project members
CREATE POLICY "pmem_select" ON project_members FOR SELECT TO authenticated USING (true);
CREATE POLICY "pmem_insert" ON project_members FOR INSERT TO authenticated WITH CHECK (is_admin());
CREATE POLICY "pmem_update" ON project_members FOR UPDATE TO authenticated USING (is_admin());
CREATE POLICY "pmem_delete" ON project_members FOR DELETE TO authenticated USING (is_admin());

-- Project payments
CREATE POLICY "ppay_select" ON project_payments FOR SELECT TO authenticated USING (true);
CREATE POLICY "ppay_insert" ON project_payments FOR INSERT TO authenticated WITH CHECK (is_admin());
CREATE POLICY "ppay_update" ON project_payments FOR UPDATE TO authenticated USING (is_admin());
CREATE POLICY "ppay_delete" ON project_payments FOR DELETE TO authenticated USING (is_admin());

-- Project expenses
CREATE POLICY "pexp_select" ON project_expenses FOR SELECT TO authenticated USING (true);
CREATE POLICY "pexp_insert" ON project_expenses FOR INSERT TO authenticated WITH CHECK (is_admin());
CREATE POLICY "pexp_update" ON project_expenses FOR UPDATE TO authenticated USING (is_admin());
CREATE POLICY "pexp_delete" ON project_expenses FOR DELETE TO authenticated USING (is_admin());

-- Member payments
CREATE POLICY "mpay_select" ON project_member_payments FOR SELECT TO authenticated USING (true);
CREATE POLICY "mpay_insert" ON project_member_payments FOR INSERT TO authenticated WITH CHECK (is_admin());
CREATE POLICY "mpay_update" ON project_member_payments FOR UPDATE TO authenticated USING (is_admin());
CREATE POLICY "mpay_delete" ON project_member_payments FOR DELETE TO authenticated USING (is_admin());

-- Monthly calculations
CREATE POLICY "mcalc_select" ON monthly_calculations FOR SELECT TO authenticated USING (true);
CREATE POLICY "mcalc_insert" ON monthly_calculations FOR INSERT TO authenticated WITH CHECK (is_admin());
CREATE POLICY "mcalc_update" ON monthly_calculations FOR UPDATE TO authenticated USING (is_admin());
CREATE POLICY "mcalc_delete" ON monthly_calculations FOR DELETE TO authenticated USING (is_admin());

-- Profit distribution
CREATE POLICY "pdist_select" ON profit_distribution FOR SELECT TO authenticated USING (true);
CREATE POLICY "pdist_insert" ON profit_distribution FOR INSERT TO authenticated WITH CHECK (is_admin());
CREATE POLICY "pdist_update" ON profit_distribution FOR UPDATE TO authenticated USING (is_admin());
CREATE POLICY "pdist_delete" ON profit_distribution FOR DELETE TO authenticated USING (is_admin());

-- Member payouts
CREATE POLICY "mpout_select" ON member_payouts FOR SELECT TO authenticated USING (is_admin() OR user_id = auth.uid());
CREATE POLICY "mpout_insert" ON member_payouts FOR INSERT TO authenticated WITH CHECK (is_admin());
CREATE POLICY "mpout_update" ON member_payouts FOR UPDATE TO authenticated USING (is_admin());
CREATE POLICY "mpout_delete" ON member_payouts FOR DELETE TO authenticated USING (is_admin());

-- Company fund
CREATE POLICY "fund_select" ON company_fund FOR SELECT TO authenticated USING (is_admin_or_advisor());
CREATE POLICY "fund_insert" ON company_fund FOR INSERT TO authenticated WITH CHECK (is_admin());
CREATE POLICY "fund_update" ON company_fund FOR UPDATE TO authenticated USING (is_admin());
CREATE POLICY "fund_delete" ON company_fund FOR DELETE TO authenticated USING (is_admin());

-- Audit logs
CREATE POLICY "audit_select" ON audit_logs FOR SELECT TO authenticated USING (is_admin());
CREATE POLICY "audit_insert" ON audit_logs FOR INSERT TO authenticated WITH CHECK (true);

-- =====================================================
-- PART 2 COMPLETE!
-- =====================================================
