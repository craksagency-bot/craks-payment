-- =====================================================
-- CRAKS PAYMENT MANAGEMENT SYSTEM - FINAL WORKING
-- Run this in Supabase SQL Editor
-- =====================================================

-- =====================================================
-- PART 1: DROP EVERYTHING (Clean Start)
-- =====================================================

DROP TRIGGER IF EXISTS trg_audit_users ON users;
DROP TRIGGER IF EXISTS trg_audit_projects ON projects;
DROP TRIGGER IF EXISTS trg_audit_payments ON project_payments;
DROP TRIGGER IF EXISTS trg_audit_expenses ON project_expenses;
DROP TRIGGER IF EXISTS trg_audit_payouts ON member_payouts;
DROP TRIGGER IF EXISTS trg_audit_fund ON company_fund;
DROP TRIGGER IF EXISTS trg_validate_percentage ON project_members;
DROP TRIGGER IF EXISTS trg_calculate_member_amount ON project_members;
DROP TRIGGER IF EXISTS trg_generate_member_payments ON project_members;
DROP TRIGGER IF EXISTS trg_recalculate_on_project_update ON projects;

DROP FUNCTION IF EXISTS fn_audit_trigger() CASCADE;
DROP FUNCTION IF EXISTS fn_validate_percentage() CASCADE;
DROP FUNCTION IF EXISTS fn_calculate_member_amount() CASCADE;
DROP FUNCTION IF EXISTS fn_generate_member_payments() CASCADE;
DROP FUNCTION IF EXISTS fn_recalculate_project_members() CASCADE;
DROP FUNCTION IF EXISTS fn_get_months_between(DATE, DATE) CASCADE;
DROP FUNCTION IF EXISTS is_admin() CASCADE;
DROP FUNCTION IF EXISTS is_advisor() CASCADE;
DROP FUNCTION IF EXISTS is_admin_or_advisor() CASCADE;

DROP VIEW IF EXISTS v_project_summary CASCADE;
DROP VIEW IF EXISTS v_member_payment_schedule CASCADE;
DROP VIEW IF EXISTS v_monthly_summary CASCADE;

DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS member_payouts CASCADE;
DROP TABLE IF EXISTS profit_distribution CASCADE;
DROP TABLE IF EXISTS monthly_calculations CASCADE;
DROP TABLE IF EXISTS company_fund CASCADE;
DROP TABLE IF EXISTS project_member_payments CASCADE;
DROP TABLE IF EXISTS project_members CASCADE;
DROP TABLE IF EXISTS project_expenses CASCADE;
DROP TABLE IF EXISTS project_payments CASCADE;
DROP TABLE IF EXISTS user_bank_details CASCADE;
DROP TABLE IF EXISTS projects CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- =====================================================
-- PART 2: CREATE ALL TABLES
-- =====================================================

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'MEMBER',
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    phone VARCHAR(20),
    join_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_role CHECK (role IN ('ADMIN', 'ADVISOR', 'MEMBER')),
    CONSTRAINT chk_status CHECK (status IN ('ACTIVE', 'INACTIVE'))
);

-- User bank details
CREATE TABLE user_bank_details (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    bank_name VARCHAR(255) NOT NULL,
    account_number VARCHAR(50) NOT NULL,
    account_holder VARCHAR(255) NOT NULL,
    branch_name VARCHAR(255),
    ifsc_swift VARCHAR(50),
    is_primary BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Projects table
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_name VARCHAR(255) NOT NULL,
    client_name VARCHAR(255) NOT NULL,
    category VARCHAR(50) DEFAULT 'Other',
    description TEXT,
    total_budget DECIMAL(15,2) DEFAULT 0,
    project_date DATE DEFAULT CURRENT_DATE,
    start_date DATE,
    end_date DATE,
    status VARCHAR(20) DEFAULT 'OPEN',
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_category CHECK (category IN ('Media', 'Photo', 'Video', 'Web', 'Design', 'Other')),
    CONSTRAINT chk_proj_status CHECK (status IN ('OPEN', 'CLOSED', 'CANCELLED')),
    CONSTRAINT chk_budget CHECK (total_budget >= 0)
);

-- Project members
CREATE TABLE project_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    member_name VARCHAR(255) NOT NULL,
    role VARCHAR(100),
    percentage DECIMAL(5,2) NOT NULL,
    calculated_amount DECIMAL(15,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_percentage CHECK (percentage > 0 AND percentage <= 100),
    CONSTRAINT uq_project_member UNIQUE (project_id, member_name)
);

-- Project payments
CREATE TABLE project_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    amount DECIMAL(15,2) NOT NULL,
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_type VARCHAR(20) DEFAULT 'Partial',
    notes TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_pay_amount CHECK (amount > 0),
    CONSTRAINT chk_pay_type CHECK (payment_type IN ('Advance', 'Partial', 'Final'))
);

-- Project expenses
CREATE TABLE project_expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    amount DECIMAL(15,2) NOT NULL,
    expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
    category VARCHAR(50) DEFAULT 'Other',
    notes TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_exp_amount CHECK (amount > 0),
    CONSTRAINT chk_exp_category CHECK (category IN ('Travel', 'Equipment', 'Freelance', 'Software', 'Materials', 'Other'))
);

-- Project member payments (monthly split)
CREATE TABLE project_member_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES project_members(id) ON DELETE CASCADE,
    member_name VARCHAR(255) NOT NULL,
    total_amount DECIMAL(15,2) DEFAULT 0,
    monthly_amount DECIMAL(15,2) DEFAULT 0,
    month_number INTEGER NOT NULL,
    payment_month DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING',
    paid_date DATE,
    paid_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_month_num CHECK (month_number > 0),
    CONSTRAINT chk_mem_pay_status CHECK (status IN ('PENDING', 'PAID', 'CANCELLED')),
    CONSTRAINT uq_member_month UNIQUE (project_id, member_id, month_number)
);

-- Monthly calculations
CREATE TABLE monthly_calculations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    month VARCHAR(7) NOT NULL UNIQUE,
    total_income DECIMAL(15,2) DEFAULT 0,
    total_expense DECIMAL(15,2) DEFAULT 0,
    net_profit DECIMAL(15,2) DEFAULT 0,
    locked BOOLEAN DEFAULT false,
    locked_by UUID REFERENCES users(id),
    locked_at TIMESTAMPTZ,
    calculated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Profit distribution
CREATE TABLE profit_distribution (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    month VARCHAR(7) NOT NULL,
    role VARCHAR(20) NOT NULL,
    percentage DECIMAL(5,2) NOT NULL,
    amount DECIMAL(15,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_dist_role CHECK (role IN ('Founder', 'Advisor', 'Company', 'Team')),
    CONSTRAINT uq_month_role UNIQUE (month, role)
);

-- Member payouts
CREATE TABLE member_payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    month VARCHAR(7) NOT NULL,
    amount DECIMAL(15,2) DEFAULT 0,
    status VARCHAR(20) DEFAULT 'Pending',
    paid_date DATE,
    paid_by UUID REFERENCES users(id),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_payout_status CHECK (status IN ('Pending', 'Paid', 'Cancelled')),
    CONSTRAINT uq_user_month UNIQUE (user_id, month)
);

-- Company fund
CREATE TABLE company_fund (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(10) NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    reason TEXT NOT NULL,
    reference_month VARCHAR(7),
    entry_date DATE DEFAULT CURRENT_DATE,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_fund_type CHECK (type IN ('Credit', 'Debit')),
    CONSTRAINT chk_fund_amount CHECK (amount > 0)
);

-- Audit logs
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name VARCHAR(50) NOT NULL,
    record_id UUID,
    action VARCHAR(10) NOT NULL,
    user_id UUID,
    user_name VARCHAR(255),
    old_data JSONB,
    new_data JSONB,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_action CHECK (action IN ('INSERT', 'UPDATE', 'DELETE', 'LOGIN'))
);

-- =====================================================
-- PART 3: CREATE INDEXES
-- =====================================================

CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_projects_date ON projects(project_date);
CREATE INDEX idx_proj_members_project ON project_members(project_id);
CREATE INDEX idx_payments_project ON project_payments(project_id);
CREATE INDEX idx_payments_date ON project_payments(payment_date);
CREATE INDEX idx_expenses_project ON project_expenses(project_id);
CREATE INDEX idx_expenses_date ON project_expenses(expense_date);
CREATE INDEX idx_member_payments_project ON project_member_payments(project_id);
CREATE INDEX idx_member_payments_member ON project_member_payments(member_id);
CREATE INDEX idx_member_payments_status ON project_member_payments(status);
CREATE INDEX idx_monthly_calc_month ON monthly_calculations(month);
CREATE INDEX idx_payouts_month ON member_payouts(month);
CREATE INDEX idx_payouts_user ON member_payouts(user_id);
CREATE INDEX idx_fund_type ON company_fund(type);
CREATE INDEX idx_audit_table ON audit_logs(table_name);
CREATE INDEX idx_audit_time ON audit_logs(timestamp DESC);

-- =====================================================
-- PART 4: CREATE HELPER FUNCTIONS
-- =====================================================

-- Get months between dates
CREATE OR REPLACE FUNCTION fn_get_months_between(p_start DATE, p_end DATE)
RETURNS INTEGER
LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
    IF p_start IS NULL OR p_end IS NULL THEN RETURN 1; END IF;
    RETURN GREATEST(
        (EXTRACT(YEAR FROM p_end) - EXTRACT(YEAR FROM p_start)) * 12 +
        (EXTRACT(MONTH FROM p_end) - EXTRACT(MONTH FROM p_start)) + 1,
        1
    );
END;
$$;

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
-- PART 5: CREATE TRIGGER FUNCTIONS
-- =====================================================

-- Audit trigger
CREATE OR REPLACE FUNCTION fn_audit_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_name VARCHAR(255);
BEGIN
    SELECT name INTO v_name FROM users WHERE id = auth.uid();
    IF TG_OP = 'DELETE' THEN
        INSERT INTO audit_logs (table_name, record_id, action, user_id, user_name, old_data)
        VALUES (TG_TABLE_NAME, OLD.id, 'DELETE', auth.uid(), v_name, to_jsonb(OLD));
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_logs (table_name, record_id, action, user_id, user_name, old_data, new_data)
        VALUES (TG_TABLE_NAME, NEW.id, 'UPDATE', auth.uid(), v_name, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO audit_logs (table_name, record_id, action, user_id, user_name, new_data)
        VALUES (TG_TABLE_NAME, NEW.id, 'INSERT', auth.uid(), v_name, to_jsonb(NEW));
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$;

-- Validate percentage
CREATE OR REPLACE FUNCTION fn_validate_percentage()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE v_total DECIMAL(5,2);
BEGIN
    IF TG_OP = 'UPDATE' THEN
        SELECT COALESCE(SUM(percentage), 0) INTO v_total FROM project_members WHERE project_id = NEW.project_id AND id != NEW.id;
    ELSE
        SELECT COALESCE(SUM(percentage), 0) INTO v_total FROM project_members WHERE project_id = NEW.project_id;
    END IF;
    IF v_total + NEW.percentage > 100 THEN
        RAISE EXCEPTION 'Total percentage cannot exceed 100%%. Current: %, Adding: %', v_total, NEW.percentage;
    END IF;
    RETURN NEW;
END;
$$;

-- Calculate member amount
CREATE OR REPLACE FUNCTION fn_calculate_member_amount()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE v_budget DECIMAL(15,2);
BEGIN
    SELECT total_budget INTO v_budget FROM projects WHERE id = NEW.project_id;
    UPDATE project_members SET calculated_amount = ROUND(v_budget * NEW.percentage / 100, 2), updated_at = NOW() WHERE id = NEW.id;
    RETURN NEW;
END;
$$;

-- Generate monthly payments
CREATE OR REPLACE FUNCTION fn_generate_member_payments()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_proj RECORD;
    v_months INT;
    v_total DECIMAL(15,2);
    v_monthly DECIMAL(15,2);
    v_rem DECIMAL(15,2);
    v_month DATE;
    i INT;
BEGIN
    SELECT * INTO v_proj FROM projects WHERE id = NEW.project_id;
    IF v_proj.start_date IS NULL OR v_proj.end_date IS NULL OR v_proj.total_budget <= 0 THEN RETURN NEW; END IF;

    v_months := fn_get_months_between(v_proj.start_date, v_proj.end_date);
    v_total := ROUND(v_proj.total_budget * NEW.percentage / 100, 2);
    v_monthly := TRUNC(v_total / v_months, 2);
    v_rem := v_total - (v_monthly * v_months);

    DELETE FROM project_member_payments WHERE member_id = NEW.id;
    v_month := DATE_TRUNC('month', v_proj.start_date)::DATE;

    FOR i IN 1..v_months LOOP
        INSERT INTO project_member_payments (project_id, member_id, member_name, total_amount, monthly_amount, month_number, payment_month)
        VALUES (NEW.project_id, NEW.id, NEW.member_name, v_total, CASE WHEN i = v_months THEN v_monthly + v_rem ELSE v_monthly END, i, v_month);
        v_month := v_month + INTERVAL '1 month';
    END LOOP;
    RETURN NEW;
END;
$$;

-- Recalculate on project update
CREATE OR REPLACE FUNCTION fn_recalculate_project_members()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_member RECORD;
    v_months INT;
    v_total DECIMAL(15,2);
    v_monthly DECIMAL(15,2);
    v_rem DECIMAL(15,2);
    v_month DATE;
    i INT;
BEGIN
    IF OLD.total_budget = NEW.total_budget AND OLD.start_date IS NOT DISTINCT FROM NEW.start_date AND OLD.end_date IS NOT DISTINCT FROM NEW.end_date THEN
        RETURN NEW;
    END IF;
    IF NEW.start_date IS NULL OR NEW.end_date IS NULL THEN RETURN NEW; END IF;

    v_months := fn_get_months_between(NEW.start_date, NEW.end_date);

    FOR v_member IN SELECT * FROM project_members WHERE project_id = NEW.id LOOP
        v_total := ROUND(NEW.total_budget * v_member.percentage / 100, 2);
        UPDATE project_members SET calculated_amount = v_total, updated_at = NOW() WHERE id = v_member.id;

        IF NEW.total_budget > 0 THEN
            v_monthly := TRUNC(v_total / v_months, 2);
            v_rem := v_total - (v_monthly * v_months);
            DELETE FROM project_member_payments WHERE member_id = v_member.id;
            v_month := DATE_TRUNC('month', NEW.start_date)::DATE;

            FOR i IN 1..v_months LOOP
                INSERT INTO project_member_payments (project_id, member_id, member_name, total_amount, monthly_amount, month_number, payment_month)
                VALUES (NEW.id, v_member.id, v_member.member_name, v_total, CASE WHEN i = v_months THEN v_monthly + v_rem ELSE v_monthly END, i, v_month);
                v_month := v_month + INTERVAL '1 month';
            END LOOP;
        END IF;
    END LOOP;
    RETURN NEW;
END;
$$;

-- =====================================================
-- PART 6: CREATE TRIGGERS
-- =====================================================

CREATE TRIGGER trg_audit_users AFTER INSERT OR UPDATE OR DELETE ON users FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();
CREATE TRIGGER trg_audit_projects AFTER INSERT OR UPDATE OR DELETE ON projects FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();
CREATE TRIGGER trg_audit_payments AFTER INSERT OR UPDATE OR DELETE ON project_payments FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();
CREATE TRIGGER trg_audit_expenses AFTER INSERT OR UPDATE OR DELETE ON project_expenses FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();
CREATE TRIGGER trg_audit_payouts AFTER INSERT OR UPDATE OR DELETE ON member_payouts FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();
CREATE TRIGGER trg_audit_fund AFTER INSERT OR UPDATE OR DELETE ON company_fund FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

CREATE TRIGGER trg_validate_percentage BEFORE INSERT OR UPDATE OF percentage ON project_members FOR EACH ROW EXECUTE FUNCTION fn_validate_percentage();
CREATE TRIGGER trg_calculate_member_amount AFTER INSERT ON project_members FOR EACH ROW EXECUTE FUNCTION fn_calculate_member_amount();
CREATE TRIGGER trg_generate_member_payments AFTER INSERT OR UPDATE OF percentage ON project_members FOR EACH ROW EXECUTE FUNCTION fn_generate_member_payments();
CREATE TRIGGER trg_recalculate_on_project_update AFTER UPDATE OF total_budget, start_date, end_date ON projects FOR EACH ROW EXECUTE FUNCTION fn_recalculate_project_members();

-- =====================================================
-- PART 7: CREATE VIEWS
-- =====================================================

CREATE VIEW v_project_summary AS
SELECT p.id, p.project_name, p.client_name, p.category, p.total_budget, p.project_date, p.start_date, p.end_date, p.status,
    COALESCE((SELECT SUM(amount) FROM project_payments WHERE project_id = p.id), 0) AS total_payments,
    COALESCE((SELECT SUM(amount) FROM project_expenses WHERE project_id = p.id), 0) AS total_expenses,
    COALESCE((SELECT SUM(amount) FROM project_payments WHERE project_id = p.id), 0) - COALESCE((SELECT SUM(amount) FROM project_expenses WHERE project_id = p.id), 0) AS net_profit,
    COALESCE((SELECT SUM(percentage) FROM project_members WHERE project_id = p.id), 0) AS allocated_percentage,
    (SELECT COUNT(*) FROM project_members WHERE project_id = p.id) AS member_count
FROM projects p;

CREATE VIEW v_member_payment_schedule AS
SELECT p.project_name, pm.member_name, pm.role, pm.percentage, pm.calculated_amount, pmp.month_number, pmp.payment_month, pmp.monthly_amount, pmp.status, pmp.paid_date
FROM project_member_payments pmp
JOIN project_members pm ON pmp.member_id = pm.id
JOIN projects p ON pmp.project_id = p.id
ORDER BY p.project_name, pm.member_name, pmp.month_number;

-- =====================================================
-- PART 8: ENABLE RLS
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
-- PART 9: CREATE RLS POLICIES
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
CREATE POLICY "mpay_all" ON project_member_payments FOR ALL TO authenticated USING (is_admin());

-- Monthly calculations
CREATE POLICY "mcalc_select" ON monthly_calculations FOR SELECT TO authenticated USING (true);
CREATE POLICY "mcalc_all" ON monthly_calculations FOR ALL TO authenticated USING (is_admin());

-- Profit distribution
CREATE POLICY "pdist_select" ON profit_distribution FOR SELECT TO authenticated USING (true);
CREATE POLICY "pdist_all" ON profit_distribution FOR ALL TO authenticated USING (is_admin());

-- Member payouts
CREATE POLICY "mpout_select" ON member_payouts FOR SELECT TO authenticated USING (is_admin() OR user_id = auth.uid());
CREATE POLICY "mpout_all" ON member_payouts FOR ALL TO authenticated USING (is_admin());

-- Company fund
CREATE POLICY "fund_select" ON company_fund FOR SELECT TO authenticated USING (is_admin_or_advisor());
CREATE POLICY "fund_all" ON company_fund FOR ALL TO authenticated USING (is_admin());

-- Audit logs
CREATE POLICY "audit_select" ON audit_logs FOR SELECT TO authenticated USING (is_admin());

-- =====================================================
-- DONE!
-- =====================================================
