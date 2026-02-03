-- =====================================================
-- CRAKS PAYMENT MANAGEMENT SYSTEM - V3 INTEGRATED
-- Complete SQL Schema for Supabase (PostgreSQL)
-- =====================================================
-- This integrates with the existing CRAKS system AND
-- adds the new Project Payment Split functionality
-- =====================================================
-- Features:
-- 1. User Management (Admin, Advisor, Member)
-- 2. Project Management with Auto Payment Split
-- 3. Monthly Payment Calculation (30-15-15-40 split)
-- 4. Company Fund Tracking
-- 5. Audit Logging
-- =====================================================

-- =====================================================
-- STEP 1: CLEANUP - Drop everything for fresh start
-- =====================================================

-- Drop triggers
DROP TRIGGER IF EXISTS trg_audit_users ON users;
DROP TRIGGER IF EXISTS trg_audit_projects ON projects;
DROP TRIGGER IF EXISTS trg_audit_payments ON project_payments;
DROP TRIGGER IF EXISTS trg_audit_expenses ON project_expenses;
DROP TRIGGER IF EXISTS trg_audit_payouts ON member_payouts;
DROP TRIGGER IF EXISTS trg_audit_fund ON company_fund;
DROP TRIGGER IF EXISTS trg_calculate_member_amount ON project_members;
DROP TRIGGER IF EXISTS trg_recalculate_on_project_update ON projects;
DROP TRIGGER IF EXISTS trg_generate_monthly_payments ON project_members;
DROP TRIGGER IF EXISTS trg_validate_percentage ON project_members;

-- Drop functions
DROP FUNCTION IF EXISTS fn_audit_trigger() CASCADE;
DROP FUNCTION IF EXISTS fn_calculate_member_amount() CASCADE;
DROP FUNCTION IF EXISTS fn_recalculate_project_members() CASCADE;
DROP FUNCTION IF EXISTS fn_generate_member_payments() CASCADE;
DROP FUNCTION IF EXISTS fn_validate_percentage() CASCADE;
DROP FUNCTION IF EXISTS fn_get_months_between(DATE, DATE) CASCADE;
DROP FUNCTION IF EXISTS is_admin() CASCADE;
DROP FUNCTION IF EXISTS is_advisor() CASCADE;
DROP FUNCTION IF EXISTS is_admin_or_advisor() CASCADE;
DROP FUNCTION IF EXISTS get_user_role() CASCADE;

-- Drop views
DROP VIEW IF EXISTS v_project_summary CASCADE;
DROP VIEW IF EXISTS v_member_payment_schedule CASCADE;
DROP VIEW IF EXISTS v_monthly_summary CASCADE;

-- Drop tables (in order due to FK)
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
-- STEP 2: CREATE CORE TABLES
-- =====================================================

-- -----------------------------------------------------
-- Table: users
-- Stores all system users (Admin, Advisor, Member)
-- -----------------------------------------------------
CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'MEMBER' CHECK (role IN ('ADMIN', 'ADVISOR', 'MEMBER')),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    phone VARCHAR(20),
    join_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE users IS 'System users with roles: ADMIN (full access), ADVISOR (read + 15% share), MEMBER (own data + 40% pool)';

-- -----------------------------------------------------
-- Table: user_bank_details
-- Bank details for payouts
-- -----------------------------------------------------
CREATE TABLE user_bank_details (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    bank_name VARCHAR(255) NOT NULL,
    account_number VARCHAR(50) NOT NULL,
    account_holder VARCHAR(255) NOT NULL,
    branch_name VARCHAR(255),
    ifsc_swift VARCHAR(50),
    is_primary BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE user_bank_details IS 'Bank account details for member payouts';

-- -----------------------------------------------------
-- Table: projects
-- Stores all project information
-- -----------------------------------------------------
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_name VARCHAR(255) NOT NULL,
    client_name VARCHAR(255) NOT NULL,
    category VARCHAR(50) DEFAULT 'Other' CHECK (category IN ('Media', 'Photo', 'Video', 'Web', 'Design', 'Other')),
    description TEXT,
    total_budget DECIMAL(15, 2) DEFAULT 0 CHECK (total_budget >= 0),
    project_date DATE DEFAULT CURRENT_DATE,
    start_date DATE,
    end_date DATE,
    status VARCHAR(20) DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'CLOSED', 'CANCELLED')),
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT chk_project_dates CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

COMMENT ON TABLE projects IS 'All projects with budget and date tracking';

-- -----------------------------------------------------
-- Table: project_members
-- Members assigned to specific projects with percentage
-- -----------------------------------------------------
CREATE TABLE project_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    member_name VARCHAR(255) NOT NULL,
    role VARCHAR(100),
    percentage DECIMAL(5, 2) NOT NULL CHECK (percentage > 0 AND percentage <= 100),
    calculated_amount DECIMAL(15, 2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT uq_project_member UNIQUE (project_id, member_name)
);

COMMENT ON TABLE project_members IS 'Project-specific member assignments with percentage share';

-- -----------------------------------------------------
-- Table: project_payments
-- Payments received for projects
-- -----------------------------------------------------
CREATE TABLE project_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_type VARCHAR(20) DEFAULT 'Partial' CHECK (payment_type IN ('Advance', 'Partial', 'Final')),
    notes TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE project_payments IS 'All payments received for projects';

-- -----------------------------------------------------
-- Table: project_expenses
-- Expenses incurred for projects
-- -----------------------------------------------------
CREATE TABLE project_expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
    expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
    category VARCHAR(50) DEFAULT 'Other' CHECK (category IN ('Travel', 'Equipment', 'Freelance', 'Software', 'Materials', 'Other')),
    notes TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE project_expenses IS 'All expenses for projects';

-- -----------------------------------------------------
-- Table: project_member_payments
-- Auto-generated monthly payments for project members
-- -----------------------------------------------------
CREATE TABLE project_member_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES project_members(id) ON DELETE CASCADE,
    member_name VARCHAR(255) NOT NULL,
    total_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
    monthly_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
    month_number INTEGER NOT NULL CHECK (month_number > 0),
    payment_month DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PAID', 'CANCELLED')),
    paid_date DATE,
    paid_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT uq_member_project_month UNIQUE (project_id, member_id, month_number)
);

COMMENT ON TABLE project_member_payments IS 'Auto-calculated monthly payment schedule for project members';

-- -----------------------------------------------------
-- Table: monthly_calculations
-- Monthly financial summary
-- -----------------------------------------------------
CREATE TABLE monthly_calculations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    month VARCHAR(7) NOT NULL UNIQUE,
    total_income DECIMAL(15, 2) DEFAULT 0,
    total_expense DECIMAL(15, 2) DEFAULT 0,
    net_profit DECIMAL(15, 2) DEFAULT 0,
    locked BOOLEAN DEFAULT false,
    locked_by UUID REFERENCES users(id),
    locked_at TIMESTAMP WITH TIME ZONE,
    calculated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE monthly_calculations IS 'Monthly financial calculations with lock feature';

-- -----------------------------------------------------
-- Table: profit_distribution
-- How profit is split (30-15-15-40)
-- -----------------------------------------------------
CREATE TABLE profit_distribution (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    month VARCHAR(7) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('Founder', 'Advisor', 'Company', 'Team')),
    percentage DECIMAL(5, 2) NOT NULL,
    amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT uq_month_role UNIQUE (month, role)
);

COMMENT ON TABLE profit_distribution IS 'Monthly profit distribution: Founder 30%, Advisor 15%, Company 15%, Team 40%';

-- -----------------------------------------------------
-- Table: member_payouts
-- Individual member payouts from team pool
-- -----------------------------------------------------
CREATE TABLE member_payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    month VARCHAR(7) NOT NULL,
    amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
    status VARCHAR(20) DEFAULT 'Pending' CHECK (status IN ('Pending', 'Paid', 'Cancelled')),
    paid_date DATE,
    paid_by UUID REFERENCES users(id),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT uq_user_month UNIQUE (user_id, month)
);

COMMENT ON TABLE member_payouts IS 'Monthly payouts to team members from 40% team pool';

-- -----------------------------------------------------
-- Table: company_fund
-- Company fund transactions (15% monthly)
-- -----------------------------------------------------
CREATE TABLE company_fund (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(10) NOT NULL CHECK (type IN ('Credit', 'Debit')),
    amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
    reason TEXT NOT NULL,
    reference_month VARCHAR(7),
    entry_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE company_fund IS 'Company fund ledger - 15% monthly credit + manual debits';

-- -----------------------------------------------------
-- Table: audit_logs
-- System audit trail
-- -----------------------------------------------------
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name VARCHAR(50) NOT NULL,
    record_id UUID,
    action VARCHAR(10) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE', 'LOGIN')),
    user_id UUID,
    user_name VARCHAR(255),
    old_data JSONB,
    new_data JSONB,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE audit_logs IS 'Complete audit trail of all database changes';

-- =====================================================
-- STEP 3: CREATE INDEXES
-- =====================================================

-- Users
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_email ON users(email);

-- Projects
CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_projects_date ON projects(project_date);
CREATE INDEX idx_projects_category ON projects(category);

-- Project Members
CREATE INDEX idx_proj_members_project ON project_members(project_id);
CREATE INDEX idx_proj_members_user ON project_members(user_id);

-- Payments & Expenses
CREATE INDEX idx_payments_project ON project_payments(project_id);
CREATE INDEX idx_payments_date ON project_payments(payment_date);
CREATE INDEX idx_expenses_project ON project_expenses(project_id);
CREATE INDEX idx_expenses_date ON project_expenses(expense_date);

-- Member Payments
CREATE INDEX idx_member_payments_project ON project_member_payments(project_id);
CREATE INDEX idx_member_payments_member ON project_member_payments(member_id);
CREATE INDEX idx_member_payments_status ON project_member_payments(status);
CREATE INDEX idx_member_payments_month ON project_member_payments(payment_month);

-- Monthly
CREATE INDEX idx_monthly_calc_month ON monthly_calculations(month);
CREATE INDEX idx_profit_dist_month ON profit_distribution(month);
CREATE INDEX idx_payouts_month ON member_payouts(month);
CREATE INDEX idx_payouts_user ON member_payouts(user_id);

-- Fund
CREATE INDEX idx_fund_type ON company_fund(type);
CREATE INDEX idx_fund_month ON company_fund(reference_month);

-- Audit
CREATE INDEX idx_audit_table ON audit_logs(table_name);
CREATE INDEX idx_audit_action ON audit_logs(action);
CREATE INDEX idx_audit_time ON audit_logs(timestamp DESC);

-- =====================================================
-- STEP 4: CREATE HELPER FUNCTIONS
-- =====================================================

-- Get months between two dates
CREATE OR REPLACE FUNCTION fn_get_months_between(p_start DATE, p_end DATE)
RETURNS INTEGER
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
    v_months INTEGER;
BEGIN
    IF p_start IS NULL OR p_end IS NULL THEN
        RETURN 1;
    END IF;

    v_months := (EXTRACT(YEAR FROM p_end) - EXTRACT(YEAR FROM p_start)) * 12 +
                (EXTRACT(MONTH FROM p_end) - EXTRACT(MONTH FROM p_start)) + 1;

    RETURN GREATEST(v_months, 1);
END;
$$;

-- Check if current user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users
        WHERE id = auth.uid() AND role = 'ADMIN' AND status = 'ACTIVE'
    );
END;
$$;

-- Check if current user is advisor
CREATE OR REPLACE FUNCTION is_advisor()
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users
        WHERE id = auth.uid() AND role = 'ADVISOR' AND status = 'ACTIVE'
    );
END;
$$;

-- Check if current user is admin or advisor
CREATE OR REPLACE FUNCTION is_admin_or_advisor()
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users
        WHERE id = auth.uid() AND role IN ('ADMIN', 'ADVISOR') AND status = 'ACTIVE'
    );
END;
$$;

-- Get current user's role
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS VARCHAR
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_role VARCHAR(20);
BEGIN
    SELECT role INTO v_role FROM users WHERE id = auth.uid();
    RETURN v_role;
END;
$$;

-- =====================================================
-- STEP 5: CREATE TRIGGER FUNCTIONS
-- =====================================================

-- Audit trigger function
CREATE OR REPLACE FUNCTION fn_audit_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_user_name VARCHAR(255);
BEGIN
    SELECT name INTO v_user_name FROM users WHERE id = auth.uid();

    IF TG_OP = 'DELETE' THEN
        INSERT INTO audit_logs (table_name, record_id, action, user_id, user_name, old_data)
        VALUES (TG_TABLE_NAME, OLD.id, 'DELETE', auth.uid(), v_user_name, to_jsonb(OLD));
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_logs (table_name, record_id, action, user_id, user_name, old_data, new_data)
        VALUES (TG_TABLE_NAME, NEW.id, 'UPDATE', auth.uid(), v_user_name, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO audit_logs (table_name, record_id, action, user_id, user_name, new_data)
        VALUES (TG_TABLE_NAME, NEW.id, 'INSERT', auth.uid(), v_user_name, to_jsonb(NEW));
        RETURN NEW;
    END IF;

    RETURN NULL;
END;
$$;

-- Validate project member percentage (max 100% per project)
CREATE OR REPLACE FUNCTION fn_validate_percentage()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_current_total DECIMAL(5, 2);
    v_new_total DECIMAL(5, 2);
BEGIN
    IF TG_OP = 'UPDATE' THEN
        SELECT COALESCE(SUM(percentage), 0) INTO v_current_total
        FROM project_members
        WHERE project_id = NEW.project_id AND id != NEW.id;
    ELSE
        SELECT COALESCE(SUM(percentage), 0) INTO v_current_total
        FROM project_members
        WHERE project_id = NEW.project_id;
    END IF;

    v_new_total := v_current_total + NEW.percentage;

    IF v_new_total > 100 THEN
        RAISE EXCEPTION 'Total percentage cannot exceed 100%%. Current: %, Adding: %, Total: %',
            v_current_total, NEW.percentage, v_new_total;
    END IF;

    RETURN NEW;
END;
$$;

-- Calculate member amount from project budget
CREATE OR REPLACE FUNCTION fn_calculate_member_amount()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_budget DECIMAL(15, 2);
BEGIN
    SELECT total_budget INTO v_budget
    FROM projects WHERE id = NEW.project_id;

    UPDATE project_members
    SET calculated_amount = ROUND(v_budget * NEW.percentage / 100, 2),
        updated_at = NOW()
    WHERE id = NEW.id;

    RETURN NEW;
END;
$$;

-- Generate monthly payments for project member
CREATE OR REPLACE FUNCTION fn_generate_member_payments()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_project RECORD;
    v_months INTEGER;
    v_member_total DECIMAL(15, 2);
    v_monthly DECIMAL(15, 2);
    v_remainder DECIMAL(15, 2);
    v_current_month DATE;
    i INTEGER;
BEGIN
    SELECT * INTO v_project FROM projects WHERE id = NEW.project_id;

    -- Only generate if project has dates and budget
    IF v_project.start_date IS NULL OR v_project.end_date IS NULL OR v_project.total_budget <= 0 THEN
        RETURN NEW;
    END IF;

    v_months := fn_get_months_between(v_project.start_date, v_project.end_date);
    v_member_total := ROUND(v_project.total_budget * NEW.percentage / 100, 2);
    v_monthly := TRUNC(v_member_total / v_months, 2);
    v_remainder := v_member_total - (v_monthly * v_months);

    -- Delete existing payments
    DELETE FROM project_member_payments WHERE member_id = NEW.id;

    -- Generate new payments
    v_current_month := DATE_TRUNC('month', v_project.start_date)::DATE;

    FOR i IN 1..v_months LOOP
        INSERT INTO project_member_payments (
            project_id, member_id, member_name, total_amount,
            monthly_amount, month_number, payment_month
        ) VALUES (
            NEW.project_id, NEW.id, NEW.member_name, v_member_total,
            CASE WHEN i = v_months THEN v_monthly + v_remainder ELSE v_monthly END,
            i, v_current_month
        );

        v_current_month := v_current_month + INTERVAL '1 month';
    END LOOP;

    RETURN NEW;
END;
$$;

-- Recalculate all members when project budget/dates change
CREATE OR REPLACE FUNCTION fn_recalculate_project_members()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_member RECORD;
    v_months INTEGER;
    v_member_total DECIMAL(15, 2);
    v_monthly DECIMAL(15, 2);
    v_remainder DECIMAL(15, 2);
    v_current_month DATE;
    i INTEGER;
BEGIN
    IF OLD.total_budget = NEW.total_budget
       AND OLD.start_date IS NOT DISTINCT FROM NEW.start_date
       AND OLD.end_date IS NOT DISTINCT FROM NEW.end_date THEN
        RETURN NEW;
    END IF;

    -- Skip if no dates
    IF NEW.start_date IS NULL OR NEW.end_date IS NULL THEN
        RETURN NEW;
    END IF;

    v_months := fn_get_months_between(NEW.start_date, NEW.end_date);

    FOR v_member IN SELECT * FROM project_members WHERE project_id = NEW.id LOOP
        v_member_total := ROUND(NEW.total_budget * v_member.percentage / 100, 2);

        UPDATE project_members
        SET calculated_amount = v_member_total, updated_at = NOW()
        WHERE id = v_member.id;

        IF NEW.total_budget > 0 THEN
            v_monthly := TRUNC(v_member_total / v_months, 2);
            v_remainder := v_member_total - (v_monthly * v_months);

            DELETE FROM project_member_payments WHERE member_id = v_member.id;

            v_current_month := DATE_TRUNC('month', NEW.start_date)::DATE;

            FOR i IN 1..v_months LOOP
                INSERT INTO project_member_payments (
                    project_id, member_id, member_name, total_amount,
                    monthly_amount, month_number, payment_month
                ) VALUES (
                    NEW.id, v_member.id, v_member.member_name, v_member_total,
                    CASE WHEN i = v_months THEN v_monthly + v_remainder ELSE v_monthly END,
                    i, v_current_month
                );
                v_current_month := v_current_month + INTERVAL '1 month';
            END LOOP;
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$;

-- =====================================================
-- STEP 6: CREATE TRIGGERS
-- =====================================================

-- Audit triggers
CREATE TRIGGER trg_audit_users AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

CREATE TRIGGER trg_audit_projects AFTER INSERT OR UPDATE OR DELETE ON projects
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

CREATE TRIGGER trg_audit_payments AFTER INSERT OR UPDATE OR DELETE ON project_payments
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

CREATE TRIGGER trg_audit_expenses AFTER INSERT OR UPDATE OR DELETE ON project_expenses
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

CREATE TRIGGER trg_audit_payouts AFTER INSERT OR UPDATE OR DELETE ON member_payouts
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

CREATE TRIGGER trg_audit_fund AFTER INSERT OR UPDATE OR DELETE ON company_fund
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

-- Project member triggers
CREATE TRIGGER trg_validate_percentage
    BEFORE INSERT OR UPDATE OF percentage ON project_members
    FOR EACH ROW EXECUTE FUNCTION fn_validate_percentage();

CREATE TRIGGER trg_calculate_member_amount
    AFTER INSERT ON project_members
    FOR EACH ROW EXECUTE FUNCTION fn_calculate_member_amount();

CREATE TRIGGER trg_generate_member_payments
    AFTER INSERT OR UPDATE OF percentage ON project_members
    FOR EACH ROW EXECUTE FUNCTION fn_generate_member_payments();

-- Project update trigger
CREATE TRIGGER trg_recalculate_on_project_update
    AFTER UPDATE OF total_budget, start_date, end_date ON projects
    FOR EACH ROW EXECUTE FUNCTION fn_recalculate_project_members();

-- =====================================================
-- STEP 7: CREATE VIEWS
-- =====================================================

-- Project summary with payments and expenses
CREATE OR REPLACE VIEW v_project_summary AS
SELECT
    p.id,
    p.project_name,
    p.client_name,
    p.category,
    p.total_budget,
    p.project_date,
    p.start_date,
    p.end_date,
    p.status,
    COALESCE((SELECT SUM(amount) FROM project_payments WHERE project_id = p.id), 0) AS total_payments,
    COALESCE((SELECT SUM(amount) FROM project_expenses WHERE project_id = p.id), 0) AS total_expenses,
    COALESCE((SELECT SUM(amount) FROM project_payments WHERE project_id = p.id), 0) -
    COALESCE((SELECT SUM(amount) FROM project_expenses WHERE project_id = p.id), 0) AS net_profit,
    COALESCE((SELECT SUM(percentage) FROM project_members WHERE project_id = p.id), 0) AS allocated_percentage,
    (SELECT COUNT(*) FROM project_members WHERE project_id = p.id) AS member_count
FROM projects p;

-- Member payment schedule
CREATE OR REPLACE VIEW v_member_payment_schedule AS
SELECT
    p.project_name,
    pm.member_name,
    pm.role,
    pm.percentage,
    pm.calculated_amount AS total_member_amount,
    pmp.month_number,
    pmp.payment_month,
    pmp.monthly_amount,
    pmp.status,
    pmp.paid_date
FROM project_member_payments pmp
JOIN project_members pm ON pmp.member_id = pm.id
JOIN projects p ON pmp.project_id = p.id
ORDER BY p.project_name, pm.member_name, pmp.month_number;

-- Monthly payment summary
CREATE OR REPLACE VIEW v_monthly_summary AS
SELECT
    p.id AS project_id,
    p.project_name,
    pmp.payment_month,
    pmp.month_number,
    COUNT(*) AS payment_count,
    SUM(pmp.monthly_amount) AS total_monthly,
    SUM(CASE WHEN pmp.status = 'PAID' THEN pmp.monthly_amount ELSE 0 END) AS paid_amount,
    SUM(CASE WHEN pmp.status = 'PENDING' THEN pmp.monthly_amount ELSE 0 END) AS pending_amount
FROM project_member_payments pmp
JOIN projects p ON pmp.project_id = p.id
GROUP BY p.id, p.project_name, pmp.payment_month, pmp.month_number;

-- =====================================================
-- STEP 8: ENABLE ROW LEVEL SECURITY
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
-- STEP 9: CREATE RLS POLICIES
-- =====================================================

-- Users
CREATE POLICY "users_select" ON users FOR SELECT TO authenticated USING (true);
CREATE POLICY "users_insert" ON users FOR INSERT TO authenticated WITH CHECK (is_admin());
CREATE POLICY "users_update" ON users FOR UPDATE TO authenticated USING (is_admin());
CREATE POLICY "users_delete" ON users FOR DELETE TO authenticated USING (is_admin());

-- Bank Details
CREATE POLICY "bank_admin" ON user_bank_details FOR ALL TO authenticated USING (is_admin());
CREATE POLICY "bank_own" ON user_bank_details FOR SELECT TO authenticated USING (user_id = auth.uid());

-- Projects
CREATE POLICY "projects_select" ON projects FOR SELECT TO authenticated USING (true);
CREATE POLICY "projects_admin" ON projects FOR ALL TO authenticated USING (is_admin());

-- Project Members
CREATE POLICY "members_select" ON project_members FOR SELECT TO authenticated USING (true);
CREATE POLICY "members_admin" ON project_members FOR ALL TO authenticated USING (is_admin());

-- Project Payments
CREATE POLICY "payments_select" ON project_payments FOR SELECT TO authenticated USING (true);
CREATE POLICY "payments_admin" ON project_payments FOR ALL TO authenticated USING (is_admin());

-- Project Expenses
CREATE POLICY "expenses_select" ON project_expenses FOR SELECT TO authenticated USING (true);
CREATE POLICY "expenses_admin" ON project_expenses FOR ALL TO authenticated USING (is_admin());

-- Member Payments
CREATE POLICY "member_payments_select" ON project_member_payments FOR SELECT TO authenticated USING (true);
CREATE POLICY "member_payments_admin" ON project_member_payments FOR ALL TO authenticated USING (is_admin());

-- Monthly Calculations
CREATE POLICY "calc_select" ON monthly_calculations FOR SELECT TO authenticated USING (true);
CREATE POLICY "calc_admin" ON monthly_calculations FOR ALL TO authenticated USING (is_admin());

-- Profit Distribution
CREATE POLICY "dist_select" ON profit_distribution FOR SELECT TO authenticated USING (true);
CREATE POLICY "dist_admin" ON profit_distribution FOR ALL TO authenticated USING (is_admin());

-- Member Payouts
CREATE POLICY "payouts_admin" ON member_payouts FOR ALL TO authenticated USING (is_admin());
CREATE POLICY "payouts_own" ON member_payouts FOR SELECT TO authenticated USING (user_id = auth.uid());

-- Company Fund
CREATE POLICY "fund_select" ON company_fund FOR SELECT TO authenticated USING (is_admin_or_advisor());
CREATE POLICY "fund_admin" ON company_fund FOR ALL TO authenticated USING (is_admin());

-- Audit Logs
CREATE POLICY "audit_admin" ON audit_logs FOR SELECT TO authenticated USING (is_admin());

-- =====================================================
-- STEP 10: UTILITY FUNCTIONS
-- =====================================================

-- Mark payment as paid
CREATE OR REPLACE FUNCTION fn_mark_member_payment_paid(p_payment_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    UPDATE project_member_payments
    SET status = 'PAID', paid_date = CURRENT_DATE, paid_by = auth.uid()
    WHERE id = p_payment_id AND status = 'PENDING';
    RETURN FOUND;
END;
$$;

-- Get project payment status
CREATE OR REPLACE FUNCTION fn_get_project_payment_status(p_project_id UUID)
RETURNS TABLE (
    total_payments BIGINT,
    paid_count BIGINT,
    pending_count BIGINT,
    total_amount DECIMAL,
    paid_amount DECIMAL,
    pending_amount DECIMAL,
    completion_pct DECIMAL
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE status = 'PAID'),
        COUNT(*) FILTER (WHERE status = 'PENDING'),
        COALESCE(SUM(monthly_amount), 0),
        COALESCE(SUM(monthly_amount) FILTER (WHERE status = 'PAID'), 0),
        COALESCE(SUM(monthly_amount) FILTER (WHERE status = 'PENDING'), 0),
        CASE WHEN COUNT(*) > 0 THEN
            ROUND(COUNT(*) FILTER (WHERE status = 'PAID')::DECIMAL / COUNT(*) * 100, 2)
        ELSE 0 END
    FROM project_member_payments
    WHERE project_id = p_project_id;
END;
$$;

-- =====================================================
-- COMPLETE!
-- =====================================================
-- Run this entire script in Supabase SQL Editor
-- Then create admin user via Authentication
-- Then insert admin into users table
-- =====================================================
