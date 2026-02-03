-- =====================================================
-- CRAKS PAYMENT MANAGEMENT SYSTEM - DATABASE SCHEMA V2
-- Complete Professional Enterprise-Level Schema
-- =====================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- 1️⃣ USERS TABLE
-- =====================================================
CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('ADMIN', 'ADVISOR', 'MEMBER')),
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    join_date DATE NOT NULL DEFAULT CURRENT_DATE,
    leave_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 2️⃣ USER BANK DETAILS TABLE
-- =====================================================
CREATE TABLE user_bank_details (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    bank_name VARCHAR(100) NOT NULL,
    account_holder VARCHAR(100) NOT NULL,
    account_number VARCHAR(50) NOT NULL,
    branch_name VARCHAR(100),
    ifsc_swift VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 3️⃣ PROJECTS TABLE
-- =====================================================
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_name VARCHAR(200) NOT NULL,
    category VARCHAR(50) NOT NULL CHECK (category IN ('Media', 'Photo', 'Video', 'Web', 'Design', 'Other')),
    client_name VARCHAR(100) NOT NULL,
    project_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'CLOSED')),
    description TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 4️⃣ PROJECT PAYMENTS TABLE
-- =====================================================
CREATE TABLE project_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
    payment_date DATE NOT NULL,
    payment_type VARCHAR(20) NOT NULL CHECK (payment_type IN ('Advance', 'Partial', 'Final')),
    notes TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 5️⃣ PROJECT EXPENSES TABLE
-- =====================================================
CREATE TABLE project_expenses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    category VARCHAR(50) NOT NULL CHECK (category IN ('Travel', 'Equipment', 'Freelance', 'Software', 'Materials', 'Other')),
    amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
    expense_date DATE NOT NULL,
    notes TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 6️⃣ MONTHLY CALCULATIONS TABLE
-- =====================================================
CREATE TABLE monthly_calculations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    month VARCHAR(7) NOT NULL UNIQUE, -- YYYY-MM format
    total_income DECIMAL(12,2) DEFAULT 0,
    total_expense DECIMAL(12,2) DEFAULT 0,
    net_profit DECIMAL(12,2) DEFAULT 0,
    locked BOOLEAN DEFAULT FALSE,
    locked_by UUID REFERENCES users(id),
    locked_at TIMESTAMP WITH TIME ZONE,
    calculated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 7️⃣ PROFIT DISTRIBUTION TABLE
-- =====================================================
CREATE TABLE profit_distribution (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    month VARCHAR(7) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('Founder', 'Advisor', 'Company', 'Team')),
    percentage DECIMAL(5,2) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(month, role)
);

-- =====================================================
-- 8️⃣ MEMBER PAYOUTS TABLE
-- =====================================================
CREATE TABLE member_payouts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    month VARCHAR(7) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'Pending' CHECK (status IN ('Pending', 'Paid')),
    paid_date DATE,
    paid_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, month)
);

-- =====================================================
-- 9️⃣ COMPANY FUND TABLE
-- =====================================================
CREATE TABLE company_fund (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type VARCHAR(10) NOT NULL CHECK (type IN ('Credit', 'Debit')),
    amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
    reason VARCHAR(200) NOT NULL,
    reference_month VARCHAR(7), -- Link to monthly calculation
    entry_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 🔟 AUDIT LOGS TABLE
-- =====================================================
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    user_name VARCHAR(100),
    action VARCHAR(20) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE', 'LOGIN', 'LOGOUT')),
    table_name VARCHAR(50) NOT NULL,
    record_id UUID,
    old_data JSONB,
    new_data JSONB,
    ip_address VARCHAR(50),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_projects_date ON projects(project_date);
CREATE INDEX idx_payments_project ON project_payments(project_id);
CREATE INDEX idx_payments_date ON project_payments(payment_date);
CREATE INDEX idx_expenses_project ON project_expenses(project_id);
CREATE INDEX idx_expenses_date ON project_expenses(expense_date);
CREATE INDEX idx_monthly_month ON monthly_calculations(month);
CREATE INDEX idx_distribution_month ON profit_distribution(month);
CREATE INDEX idx_payouts_user ON member_payouts(user_id);
CREATE INDEX idx_payouts_month ON member_payouts(month);
CREATE INDEX idx_payouts_status ON member_payouts(status);
CREATE INDEX idx_fund_date ON company_fund(entry_date);
CREATE INDEX idx_audit_timestamp ON audit_logs(timestamp);
CREATE INDEX idx_audit_user ON audit_logs(user_id);
CREATE INDEX idx_audit_table ON audit_logs(table_name);

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Check if user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users
        WHERE id = auth.uid() AND role = 'ADMIN'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Check if user is advisor
CREATE OR REPLACE FUNCTION is_advisor()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users
        WHERE id = auth.uid() AND role = 'ADVISOR'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Check if user is admin or advisor
CREATE OR REPLACE FUNCTION is_admin_or_advisor()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users
        WHERE id = auth.uid() AND role IN ('ADMIN', 'ADVISOR')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Get current user role
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS VARCHAR AS $$
DECLARE
    user_role VARCHAR;
BEGIN
    SELECT role INTO user_role FROM users WHERE id = auth.uid();
    RETURN user_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- =====================================================
-- AUTO-DELETE OLD DATA (6 MONTHS RETENTION)
-- =====================================================
CREATE OR REPLACE FUNCTION cleanup_old_data()
RETURNS void AS $$
DECLARE
    cutoff_month VARCHAR(7);
BEGIN
    cutoff_month := TO_CHAR(NOW() - INTERVAL '6 months', 'YYYY-MM');

    -- Delete old audit logs
    DELETE FROM audit_logs WHERE timestamp < NOW() - INTERVAL '6 months';

    -- Delete old monthly calculations (unlocked only)
    DELETE FROM monthly_calculations WHERE month < cutoff_month AND locked = FALSE;

    -- Delete old profit distributions
    DELETE FROM profit_distribution WHERE month < cutoff_month;

    -- Delete old member payouts
    DELETE FROM member_payouts WHERE month < cutoff_month;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- =====================================================
-- AUDIT TRIGGER FUNCTION
-- =====================================================
CREATE OR REPLACE FUNCTION log_audit()
RETURNS TRIGGER AS $$
DECLARE
    user_name_val VARCHAR;
BEGIN
    SELECT name INTO user_name_val FROM users WHERE id = auth.uid();

    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_logs (user_id, user_name, action, table_name, record_id, new_data)
        VALUES (auth.uid(), user_name_val, 'INSERT', TG_TABLE_NAME, NEW.id, to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_logs (user_id, user_name, action, table_name, record_id, old_data, new_data)
        VALUES (auth.uid(), user_name_val, 'UPDATE', TG_TABLE_NAME, NEW.id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_logs (user_id, user_name, action, table_name, record_id, old_data)
        VALUES (auth.uid(), user_name_val, 'DELETE', TG_TABLE_NAME, OLD.id, to_jsonb(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- =====================================================
-- CREATE AUDIT TRIGGERS
-- =====================================================
CREATE TRIGGER audit_users AFTER INSERT OR UPDATE OR DELETE ON users FOR EACH ROW EXECUTE FUNCTION log_audit();
CREATE TRIGGER audit_projects AFTER INSERT OR UPDATE OR DELETE ON projects FOR EACH ROW EXECUTE FUNCTION log_audit();
CREATE TRIGGER audit_payments AFTER INSERT OR UPDATE OR DELETE ON project_payments FOR EACH ROW EXECUTE FUNCTION log_audit();
CREATE TRIGGER audit_expenses AFTER INSERT OR UPDATE OR DELETE ON project_expenses FOR EACH ROW EXECUTE FUNCTION log_audit();
CREATE TRIGGER audit_monthly AFTER INSERT OR UPDATE OR DELETE ON monthly_calculations FOR EACH ROW EXECUTE FUNCTION log_audit();
CREATE TRIGGER audit_distribution AFTER INSERT OR UPDATE OR DELETE ON profit_distribution FOR EACH ROW EXECUTE FUNCTION log_audit();
CREATE TRIGGER audit_payouts AFTER INSERT OR UPDATE OR DELETE ON member_payouts FOR EACH ROW EXECUTE FUNCTION log_audit();
CREATE TRIGGER audit_fund AFTER INSERT OR UPDATE OR DELETE ON company_fund FOR EACH ROW EXECUTE FUNCTION log_audit();

-- =====================================================
-- VIEWS FOR EASY REPORTING
-- =====================================================

-- Project summary view (fixed - separate subqueries to avoid duplicate counting)
CREATE OR REPLACE VIEW v_project_summary AS
SELECT
    p.id,
    p.project_name,
    p.category,
    p.client_name,
    p.project_date,
    p.status,
    COALESCE((SELECT SUM(amount) FROM project_payments WHERE project_id = p.id), 0) as total_payments,
    COALESCE((SELECT SUM(amount) FROM project_expenses WHERE project_id = p.id), 0) as total_expenses,
    COALESCE((SELECT SUM(amount) FROM project_payments WHERE project_id = p.id), 0) -
    COALESCE((SELECT SUM(amount) FROM project_expenses WHERE project_id = p.id), 0) as net_profit
FROM projects p;

-- Monthly summary view
CREATE OR REPLACE VIEW v_monthly_summary AS
SELECT
    TO_CHAR(pay.payment_date, 'YYYY-MM') as month,
    SUM(pay.amount) as total_income,
    COALESCE((SELECT SUM(amount) FROM project_expenses WHERE TO_CHAR(expense_date, 'YYYY-MM') = TO_CHAR(pay.payment_date, 'YYYY-MM')), 0) as total_expense
FROM project_payments pay
GROUP BY TO_CHAR(pay.payment_date, 'YYYY-MM');

-- Company fund balance view
CREATE OR REPLACE VIEW v_fund_balance AS
SELECT
    SUM(CASE WHEN type = 'Credit' THEN amount ELSE 0 END) -
    SUM(CASE WHEN type = 'Debit' THEN amount ELSE 0 END) as current_balance,
    SUM(CASE WHEN type = 'Credit' THEN amount ELSE 0 END) as total_credits,
    SUM(CASE WHEN type = 'Debit' THEN amount ELSE 0 END) as total_debits
FROM company_fund;

COMMENT ON TABLE users IS 'All system users - Admin, Advisor, Members';
COMMENT ON TABLE user_bank_details IS 'Secure bank details for payouts';
COMMENT ON TABLE projects IS 'All CRAKS projects/works';
COMMENT ON TABLE project_payments IS 'Client payments (can be installments)';
COMMENT ON TABLE project_expenses IS 'Project-wise expenses';
COMMENT ON TABLE monthly_calculations IS 'Month-wise financial snapshot';
COMMENT ON TABLE profit_distribution IS 'Fixed 30-15-15-40 split records';
COMMENT ON TABLE member_payouts IS 'Individual team member earnings';
COMMENT ON TABLE company_fund IS 'Company 15% fund tracking';
COMMENT ON TABLE audit_logs IS 'Complete audit trail for security';
