-- CRAKS Payment Management System - Database Schema
-- Run this FIRST in Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Table 1: users
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  phone TEXT,
  bank_details TEXT,
  role TEXT NOT NULL CHECK (role IN ('admin', 'advisor', 'team')),
  active BOOLEAN DEFAULT true,
  join_date DATE DEFAULT CURRENT_DATE,
  leave_date DATE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_active ON users(active);

-- Table 2: projects
CREATE TABLE projects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  client_name TEXT NOT NULL,
  project_name TEXT,
  project_date DATE NOT NULL,
  total_payment DECIMAL(12,2) NOT NULL DEFAULT 0,
  total_expenses DECIMAL(12,2) NOT NULL DEFAULT 0,
  net_profit DECIMAL(12,2) GENERATED ALWAYS AS (total_payment - total_expenses) STORED,
  status TEXT DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_projects_date ON projects(project_date);
CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_projects_client ON projects(client_name);

-- Table 3: project_installments
CREATE TABLE project_installments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  installment_number INTEGER NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  payment_date DATE NOT NULL,
  notes TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_installments_project ON project_installments(project_id);
CREATE INDEX idx_installments_date ON project_installments(payment_date);

-- Table 4: expenses
CREATE TABLE expenses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  category TEXT NOT NULL CHECK (category IN (
    'equipment', 'transport', 'freelancer', 'software',
    'props', 'ads', 'marketing', 'other'
  )),
  amount DECIMAL(12,2) NOT NULL,
  description TEXT,
  expense_date DATE NOT NULL,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_expenses_project ON expenses(project_id);
CREATE INDEX idx_expenses_category ON expenses(category);
CREATE INDEX idx_expenses_date ON expenses(expense_date);

-- Table 5: payouts
CREATE TABLE payouts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id),
  month DATE NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'paid')),
  payment_method TEXT,
  paid_by UUID REFERENCES users(id),
  paid_date DATE,
  notes TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, month)
);

CREATE INDEX idx_payouts_user ON payouts(user_id);
CREATE INDEX idx_payouts_month ON payouts(month);
CREATE INDEX idx_payouts_status ON payouts(status);

-- Table 6: company_fund
CREATE TABLE company_fund (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('credit', 'debit')),
  amount DECIMAL(12,2) NOT NULL,
  balance DECIMAL(12,2) NOT NULL,
  description TEXT NOT NULL,
  transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_fund_date ON company_fund(transaction_date);
CREATE INDEX idx_fund_type ON company_fund(transaction_type);

-- Table 7: payout_calculations
CREATE TABLE payout_calculations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  month DATE NOT NULL UNIQUE,
  total_net_profit DECIMAL(12,2) NOT NULL,
  founder_amount DECIMAL(12,2) NOT NULL,
  advisor_amount DECIMAL(12,2) NOT NULL,
  company_fund_amount DECIMAL(12,2) NOT NULL,
  team_pool_amount DECIMAL(12,2) NOT NULL,
  active_team_count INTEGER NOT NULL,
  per_member_amount DECIMAL(12,2) NOT NULL,
  calculation_date TIMESTAMP DEFAULT NOW(),
  calculated_by UUID REFERENCES users(id)
);

CREATE INDEX idx_calc_month ON payout_calculations(month);

-- Table 8: system_settings
CREATE TABLE system_settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  setting_key TEXT UNIQUE NOT NULL,
  setting_value TEXT NOT NULL,
  updated_at TIMESTAMP DEFAULT NOW(),
  updated_by UUID REFERENCES users(id)
);

CREATE INDEX idx_settings_key ON system_settings(setting_key);

-- Trigger: Update total_expenses on projects when expenses change
CREATE OR REPLACE FUNCTION update_project_expenses()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    UPDATE projects SET total_expenses = (
      SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE project_id = OLD.project_id
    ), updated_at = NOW() WHERE id = OLD.project_id;
    RETURN OLD;
  ELSE
    UPDATE projects SET total_expenses = (
      SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE project_id = NEW.project_id
    ), updated_at = NOW() WHERE id = NEW.project_id;
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_expenses
AFTER INSERT OR UPDATE OR DELETE ON expenses
FOR EACH ROW EXECUTE FUNCTION update_project_expenses();

-- Trigger: Update total_payment on projects when installments change
CREATE OR REPLACE FUNCTION update_project_payment()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    UPDATE projects SET total_payment = (
      SELECT COALESCE(SUM(amount), 0) FROM project_installments WHERE project_id = OLD.project_id
    ), updated_at = NOW() WHERE id = OLD.project_id;
    RETURN OLD;
  ELSE
    UPDATE projects SET total_payment = (
      SELECT COALESCE(SUM(amount), 0) FROM project_installments WHERE project_id = NEW.project_id
    ), updated_at = NOW() WHERE id = NEW.project_id;
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_payment
AFTER INSERT OR UPDATE OR DELETE ON project_installments
FOR EACH ROW EXECUTE FUNCTION update_project_payment();

-- Trigger: Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_users_updated
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_projects_updated
BEFORE UPDATE ON projects
FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_payouts_updated
BEFORE UPDATE ON payouts
FOR EACH ROW EXECUTE FUNCTION update_updated_at();
