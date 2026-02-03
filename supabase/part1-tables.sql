-- =====================================================
-- PART 1: TABLES ONLY - Run this FIRST
-- =====================================================

-- Drop existing tables
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
-- CREATE TABLES
-- =====================================================

-- 1. Users
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'MEMBER' CHECK (role IN ('ADMIN', 'ADVISOR', 'MEMBER')),
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
    phone VARCHAR(20),
    join_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. User Bank Details
CREATE TABLE user_bank_details (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    bank_name VARCHAR(255) NOT NULL,
    account_number VARCHAR(50) NOT NULL,
    account_holder VARCHAR(255) NOT NULL,
    branch_name VARCHAR(255),
    ifsc_swift VARCHAR(50),
    is_primary BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Projects
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_name VARCHAR(255) NOT NULL,
    client_name VARCHAR(255) NOT NULL,
    category VARCHAR(50) DEFAULT 'Other' CHECK (category IN ('Media', 'Photo', 'Video', 'Web', 'Design', 'Other')),
    description TEXT,
    total_budget DECIMAL(15,2) DEFAULT 0 CHECK (total_budget >= 0),
    project_date DATE DEFAULT CURRENT_DATE,
    start_date DATE,
    end_date DATE,
    status VARCHAR(20) DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'CLOSED', 'CANCELLED')),
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Project Members
CREATE TABLE project_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    member_name VARCHAR(255) NOT NULL,
    role VARCHAR(100),
    percentage DECIMAL(5,2) CHECK (percentage > 0 AND percentage <= 100),
    calculated_amount DECIMAL(15,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (project_id, member_name)
);

-- 5. Project Payments
CREATE TABLE project_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    payment_date DATE DEFAULT CURRENT_DATE,
    payment_type VARCHAR(20) DEFAULT 'Partial' CHECK (payment_type IN ('Advance', 'Partial', 'Final')),
    notes TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Project Expenses
CREATE TABLE project_expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    expense_date DATE DEFAULT CURRENT_DATE,
    category VARCHAR(50) DEFAULT 'Other' CHECK (category IN ('Travel', 'Equipment', 'Freelance', 'Software', 'Materials', 'Other')),
    notes TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Project Member Payments
CREATE TABLE project_member_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    member_id UUID REFERENCES project_members(id) ON DELETE CASCADE,
    member_name VARCHAR(255),
    total_amount DECIMAL(15,2) DEFAULT 0,
    monthly_amount DECIMAL(15,2) DEFAULT 0,
    month_number INTEGER CHECK (month_number > 0),
    payment_month DATE,
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PAID', 'CANCELLED')),
    paid_date DATE,
    paid_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (project_id, member_id, month_number)
);

-- 8. Monthly Calculations
CREATE TABLE monthly_calculations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    month VARCHAR(7) UNIQUE NOT NULL,
    total_income DECIMAL(15,2) DEFAULT 0,
    total_expense DECIMAL(15,2) DEFAULT 0,
    net_profit DECIMAL(15,2) DEFAULT 0,
    locked BOOLEAN DEFAULT false,
    locked_by UUID REFERENCES users(id),
    locked_at TIMESTAMPTZ,
    calculated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. Profit Distribution
CREATE TABLE profit_distribution (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    month VARCHAR(7) NOT NULL,
    role VARCHAR(20) CHECK (role IN ('Founder', 'Advisor', 'Company', 'Team')),
    percentage DECIMAL(5,2),
    amount DECIMAL(15,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (month, role)
);

-- 10. Member Payouts
CREATE TABLE member_payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    month VARCHAR(7) NOT NULL,
    amount DECIMAL(15,2) DEFAULT 0,
    status VARCHAR(20) DEFAULT 'Pending' CHECK (status IN ('Pending', 'Paid', 'Cancelled')),
    paid_date DATE,
    paid_by UUID REFERENCES users(id),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (user_id, month)
);

-- 11. Company Fund
CREATE TABLE company_fund (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(10) CHECK (type IN ('Credit', 'Debit')),
    amount DECIMAL(15,2) CHECK (amount > 0),
    reason TEXT NOT NULL,
    reference_month VARCHAR(7),
    entry_date DATE DEFAULT CURRENT_DATE,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 12. Audit Logs
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name VARCHAR(50),
    record_id UUID,
    action VARCHAR(10) CHECK (action IN ('INSERT', 'UPDATE', 'DELETE', 'LOGIN')),
    user_id UUID,
    user_name VARCHAR(255),
    old_data JSONB,
    new_data JSONB,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- CREATE INDEXES
-- =====================================================

CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_projects_date ON projects(project_date);
CREATE INDEX idx_payments_project ON project_payments(project_id);
CREATE INDEX idx_payments_date ON project_payments(payment_date);
CREATE INDEX idx_expenses_project ON project_expenses(project_id);
CREATE INDEX idx_expenses_date ON project_expenses(expense_date);
CREATE INDEX idx_payouts_user ON member_payouts(user_id);
CREATE INDEX idx_payouts_month ON member_payouts(month);
CREATE INDEX idx_fund_type ON company_fund(type);
CREATE INDEX idx_audit_time ON audit_logs(timestamp DESC);

-- =====================================================
-- PART 1 COMPLETE - Tables Created!
-- Now run PART 2
-- =====================================================
