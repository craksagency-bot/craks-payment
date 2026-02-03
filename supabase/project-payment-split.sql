-- =====================================================
-- PROJECT PAYMENT SPLIT SYSTEM
-- Complete SQL Schema for Supabase (PostgreSQL)
-- Version: 1.0
-- =====================================================
-- This schema automatically:
-- 1. Calculates member payments based on percentage
-- 2. Splits payments across months
-- 3. Validates percentage totals = 100%
-- 4. Handles all logic in database (no app-side logic)
-- =====================================================

-- =====================================================
-- STEP 1: CLEANUP (Drop existing objects if any)
-- =====================================================

-- Drop triggers first
DROP TRIGGER IF EXISTS trg_calculate_member_amount ON project_members;
DROP TRIGGER IF EXISTS trg_recalculate_on_project_update ON projects;
DROP TRIGGER IF EXISTS trg_generate_monthly_payments ON project_members;
DROP TRIGGER IF EXISTS trg_validate_percentage ON project_members;
DROP TRIGGER IF EXISTS trg_update_payments_on_member_change ON project_members;

-- Drop functions
DROP FUNCTION IF EXISTS fn_calculate_member_amount() CASCADE;
DROP FUNCTION IF EXISTS fn_recalculate_project_members() CASCADE;
DROP FUNCTION IF EXISTS fn_generate_monthly_payments() CASCADE;
DROP FUNCTION IF EXISTS fn_validate_percentage() CASCADE;
DROP FUNCTION IF EXISTS fn_get_months_between(DATE, DATE) CASCADE;
DROP FUNCTION IF EXISTS fn_update_all_payments() CASCADE;
DROP FUNCTION IF EXISTS fn_recalculate_member_payments() CASCADE;

-- Drop tables (in correct order due to FK constraints)
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS project_members CASCADE;
DROP TABLE IF EXISTS projects CASCADE;

-- =====================================================
-- STEP 2: CREATE TABLES
-- =====================================================

-- -----------------------------------------------------
-- Table: projects
-- Stores project information
-- -----------------------------------------------------
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_name VARCHAR(255) NOT NULL,
    total_amount DECIMAL(15, 2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'COMPLETED', 'CANCELLED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Ensure end_date is after or equal to start_date
    CONSTRAINT chk_dates CHECK (end_date >= start_date)
);

-- Add comments
COMMENT ON TABLE projects IS 'Stores all project information';
COMMENT ON COLUMN projects.total_amount IS 'Total project amount to be split among members';
COMMENT ON COLUMN projects.start_date IS 'Project start date for monthly calculation';
COMMENT ON COLUMN projects.end_date IS 'Project end date for monthly calculation';

-- -----------------------------------------------------
-- Table: project_members
-- Stores members assigned to each project with their percentage
-- -----------------------------------------------------
CREATE TABLE project_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    member_name VARCHAR(255) NOT NULL,
    role VARCHAR(100),
    percentage DECIMAL(5, 2) NOT NULL CHECK (percentage > 0 AND percentage <= 100),
    calculated_amount DECIMAL(15, 2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Prevent duplicate member names per project
    CONSTRAINT uq_project_member UNIQUE (project_id, member_name)
);

-- Add comments
COMMENT ON TABLE project_members IS 'Members assigned to projects with their share percentage';
COMMENT ON COLUMN project_members.percentage IS 'Percentage share (1-100). Total per project must equal 100%';
COMMENT ON COLUMN project_members.calculated_amount IS 'Auto-calculated: total_amount * percentage / 100';

-- -----------------------------------------------------
-- Table: payments
-- Stores monthly payment splits for each member
-- -----------------------------------------------------
CREATE TABLE payments (
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Prevent duplicate month entries per member per project
    CONSTRAINT uq_member_month UNIQUE (project_id, member_id, month_number)
);

-- Add comments
COMMENT ON TABLE payments IS 'Monthly payment schedule for each project member';
COMMENT ON COLUMN payments.total_amount IS 'Member total amount (copied for record keeping)';
COMMENT ON COLUMN payments.monthly_amount IS 'Amount for this specific month';
COMMENT ON COLUMN payments.month_number IS 'Which month (1, 2, 3, etc.)';
COMMENT ON COLUMN payments.payment_month IS 'Actual date of this payment month';

-- =====================================================
-- STEP 3: CREATE INDEXES
-- =====================================================

-- Projects indexes
CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_projects_dates ON projects(start_date, end_date);
CREATE INDEX idx_projects_created ON projects(created_at DESC);

-- Project members indexes
CREATE INDEX idx_members_project ON project_members(project_id);
CREATE INDEX idx_members_name ON project_members(member_name);

-- Payments indexes
CREATE INDEX idx_payments_project ON payments(project_id);
CREATE INDEX idx_payments_member ON payments(member_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_month ON payments(payment_month);
CREATE INDEX idx_payments_project_member ON payments(project_id, member_id);

-- =====================================================
-- STEP 4: CREATE HELPER FUNCTIONS
-- =====================================================

-- -----------------------------------------------------
-- Function: Calculate months between two dates
-- Returns the number of months (minimum 1)
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION fn_get_months_between(p_start DATE, p_end DATE)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_months INTEGER;
BEGIN
    -- Calculate months difference
    v_months := (EXTRACT(YEAR FROM p_end) - EXTRACT(YEAR FROM p_start)) * 12 +
                (EXTRACT(MONTH FROM p_end) - EXTRACT(MONTH FROM p_start)) + 1;

    -- Ensure minimum 1 month
    IF v_months < 1 THEN
        v_months := 1;
    END IF;

    RETURN v_months;
END;
$$;

COMMENT ON FUNCTION fn_get_months_between IS 'Calculates number of months between two dates (inclusive)';

-- =====================================================
-- STEP 5: CREATE TRIGGER FUNCTIONS
-- =====================================================

-- -----------------------------------------------------
-- Function: Validate percentage total = 100%
-- Called BEFORE INSERT/UPDATE on project_members
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validate_percentage()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_total DECIMAL(5, 2);
    v_new_total DECIMAL(5, 2);
BEGIN
    -- Get current total percentage for this project (excluding current record if UPDATE)
    IF TG_OP = 'UPDATE' THEN
        SELECT COALESCE(SUM(percentage), 0)
        INTO v_current_total
        FROM project_members
        WHERE project_id = NEW.project_id AND id != NEW.id;
    ELSE
        SELECT COALESCE(SUM(percentage), 0)
        INTO v_current_total
        FROM project_members
        WHERE project_id = NEW.project_id;
    END IF;

    -- Calculate new total
    v_new_total := v_current_total + NEW.percentage;

    -- Check if exceeds 100%
    IF v_new_total > 100 THEN
        RAISE EXCEPTION 'Total percentage cannot exceed 100%%. Current: %, Adding: %, Total would be: %',
            v_current_total, NEW.percentage, v_new_total;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_validate_percentage IS 'Validates that total percentage per project does not exceed 100%';

-- -----------------------------------------------------
-- Function: Calculate member amount from project total
-- Called AFTER INSERT/UPDATE on project_members
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calculate_member_amount()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_project_total DECIMAL(15, 2);
    v_calculated DECIMAL(15, 2);
BEGIN
    -- Get project total amount
    SELECT total_amount INTO v_project_total
    FROM projects
    WHERE id = NEW.project_id;

    -- Calculate member's amount
    v_calculated := ROUND(v_project_total * NEW.percentage / 100, 2);

    -- Update the calculated_amount
    UPDATE project_members
    SET calculated_amount = v_calculated,
        updated_at = NOW()
    WHERE id = NEW.id;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_calculate_member_amount IS 'Calculates member amount based on project total and percentage';

-- -----------------------------------------------------
-- Function: Generate monthly payments for a member
-- Called AFTER INSERT/UPDATE on project_members
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION fn_generate_monthly_payments()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_project RECORD;
    v_total_months INTEGER;
    v_monthly_amount DECIMAL(15, 2);
    v_member_total DECIMAL(15, 2);
    v_current_month DATE;
    v_month_counter INTEGER;
    v_remainder DECIMAL(15, 2);
    v_last_month_amount DECIMAL(15, 2);
BEGIN
    -- Get project details
    SELECT * INTO v_project
    FROM projects
    WHERE id = NEW.project_id;

    -- Calculate total months
    v_total_months := fn_get_months_between(v_project.start_date, v_project.end_date);

    -- Calculate member's total amount
    v_member_total := ROUND(v_project.total_amount * NEW.percentage / 100, 2);

    -- Calculate monthly amount (floor to avoid exceeding total)
    v_monthly_amount := TRUNC(v_member_total / v_total_months, 2);

    -- Calculate remainder to add to last month
    v_remainder := v_member_total - (v_monthly_amount * v_total_months);

    -- Delete existing payments for this member (for recalculation)
    DELETE FROM payments
    WHERE member_id = NEW.id;

    -- Generate payment records for each month
    v_current_month := DATE_TRUNC('month', v_project.start_date)::DATE;

    FOR v_month_counter IN 1..v_total_months LOOP
        -- Add remainder to last month
        IF v_month_counter = v_total_months THEN
            v_last_month_amount := v_monthly_amount + v_remainder;
        ELSE
            v_last_month_amount := v_monthly_amount;
        END IF;

        -- Insert payment record
        INSERT INTO payments (
            project_id,
            member_id,
            member_name,
            total_amount,
            monthly_amount,
            month_number,
            payment_month,
            status
        ) VALUES (
            NEW.project_id,
            NEW.id,
            NEW.member_name,
            v_member_total,
            v_last_month_amount,
            v_month_counter,
            v_current_month,
            'PENDING'
        );

        -- Move to next month
        v_current_month := v_current_month + INTERVAL '1 month';
    END LOOP;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_generate_monthly_payments IS 'Generates monthly payment schedule for a member based on project duration';

-- -----------------------------------------------------
-- Function: Recalculate all members when project is updated
-- Called AFTER UPDATE on projects
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION fn_recalculate_project_members()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_member RECORD;
    v_total_months INTEGER;
    v_monthly_amount DECIMAL(15, 2);
    v_member_total DECIMAL(15, 2);
    v_current_month DATE;
    v_month_counter INTEGER;
    v_remainder DECIMAL(15, 2);
    v_last_month_amount DECIMAL(15, 2);
BEGIN
    -- Only recalculate if amount or dates changed
    IF OLD.total_amount = NEW.total_amount
       AND OLD.start_date = NEW.start_date
       AND OLD.end_date = NEW.end_date THEN
        RETURN NEW;
    END IF;

    -- Calculate total months
    v_total_months := fn_get_months_between(NEW.start_date, NEW.end_date);

    -- Loop through all members of this project
    FOR v_member IN
        SELECT * FROM project_members WHERE project_id = NEW.id
    LOOP
        -- Calculate member's total amount
        v_member_total := ROUND(NEW.total_amount * v_member.percentage / 100, 2);

        -- Update member's calculated amount
        UPDATE project_members
        SET calculated_amount = v_member_total,
            updated_at = NOW()
        WHERE id = v_member.id;

        -- Calculate monthly amount
        v_monthly_amount := TRUNC(v_member_total / v_total_months, 2);
        v_remainder := v_member_total - (v_monthly_amount * v_total_months);

        -- Delete existing payments
        DELETE FROM payments WHERE member_id = v_member.id;

        -- Regenerate payments
        v_current_month := DATE_TRUNC('month', NEW.start_date)::DATE;

        FOR v_month_counter IN 1..v_total_months LOOP
            IF v_month_counter = v_total_months THEN
                v_last_month_amount := v_monthly_amount + v_remainder;
            ELSE
                v_last_month_amount := v_monthly_amount;
            END IF;

            INSERT INTO payments (
                project_id,
                member_id,
                member_name,
                total_amount,
                monthly_amount,
                month_number,
                payment_month,
                status
            ) VALUES (
                NEW.id,
                v_member.id,
                v_member.member_name,
                v_member_total,
                v_last_month_amount,
                v_month_counter,
                v_current_month,
                'PENDING'
            );

            v_current_month := v_current_month + INTERVAL '1 month';
        END LOOP;
    END LOOP;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_recalculate_project_members IS 'Recalculates all member amounts and payments when project is updated';

-- =====================================================
-- STEP 6: CREATE TRIGGERS
-- =====================================================

-- Trigger: Validate percentage before insert/update
CREATE TRIGGER trg_validate_percentage
    BEFORE INSERT OR UPDATE OF percentage ON project_members
    FOR EACH ROW
    EXECUTE FUNCTION fn_validate_percentage();

-- Trigger: Calculate member amount after insert
CREATE TRIGGER trg_calculate_member_amount
    AFTER INSERT ON project_members
    FOR EACH ROW
    EXECUTE FUNCTION fn_calculate_member_amount();

-- Trigger: Generate monthly payments after insert/update
CREATE TRIGGER trg_generate_monthly_payments
    AFTER INSERT OR UPDATE OF percentage ON project_members
    FOR EACH ROW
    EXECUTE FUNCTION fn_generate_monthly_payments();

-- Trigger: Recalculate when project is updated
CREATE TRIGGER trg_recalculate_on_project_update
    AFTER UPDATE OF total_amount, start_date, end_date ON projects
    FOR EACH ROW
    EXECUTE FUNCTION fn_recalculate_project_members();

-- =====================================================
-- STEP 7: CREATE VIEWS FOR EASY QUERYING
-- =====================================================

-- -----------------------------------------------------
-- View: Project Summary with percentage completion
-- -----------------------------------------------------
CREATE OR REPLACE VIEW v_project_summary AS
SELECT
    p.id AS project_id,
    p.project_name,
    p.total_amount,
    p.start_date,
    p.end_date,
    p.status,
    fn_get_months_between(p.start_date, p.end_date) AS total_months,
    COALESCE(SUM(pm.percentage), 0) AS allocated_percentage,
    100 - COALESCE(SUM(pm.percentage), 0) AS remaining_percentage,
    COUNT(pm.id) AS member_count,
    CASE
        WHEN COALESCE(SUM(pm.percentage), 0) = 100 THEN 'FULLY_ALLOCATED'
        WHEN COALESCE(SUM(pm.percentage), 0) > 0 THEN 'PARTIALLY_ALLOCATED'
        ELSE 'NOT_ALLOCATED'
    END AS allocation_status
FROM projects p
LEFT JOIN project_members pm ON p.id = pm.project_id
GROUP BY p.id, p.project_name, p.total_amount, p.start_date, p.end_date, p.status;

COMMENT ON VIEW v_project_summary IS 'Summary of projects with allocation status';

-- -----------------------------------------------------
-- View: Member Payment Schedule
-- -----------------------------------------------------
CREATE OR REPLACE VIEW v_member_payment_schedule AS
SELECT
    p.project_name,
    pm.member_name,
    pm.role,
    pm.percentage,
    pm.calculated_amount AS total_member_amount,
    pay.month_number,
    pay.payment_month,
    pay.monthly_amount,
    pay.status AS payment_status,
    pay.paid_date
FROM payments pay
JOIN project_members pm ON pay.member_id = pm.id
JOIN projects p ON pay.project_id = p.id
ORDER BY p.project_name, pm.member_name, pay.month_number;

COMMENT ON VIEW v_member_payment_schedule IS 'Complete payment schedule for all members';

-- -----------------------------------------------------
-- View: Monthly Payment Summary
-- -----------------------------------------------------
CREATE OR REPLACE VIEW v_monthly_summary AS
SELECT
    p.id AS project_id,
    p.project_name,
    pay.payment_month,
    pay.month_number,
    COUNT(pay.id) AS payment_count,
    SUM(pay.monthly_amount) AS total_monthly_amount,
    SUM(CASE WHEN pay.status = 'PAID' THEN pay.monthly_amount ELSE 0 END) AS paid_amount,
    SUM(CASE WHEN pay.status = 'PENDING' THEN pay.monthly_amount ELSE 0 END) AS pending_amount
FROM payments pay
JOIN projects p ON pay.project_id = p.id
GROUP BY p.id, p.project_name, pay.payment_month, pay.month_number
ORDER BY pay.payment_month;

COMMENT ON VIEW v_monthly_summary IS 'Monthly payment summary grouped by project and month';

-- =====================================================
-- STEP 8: CREATE UTILITY FUNCTIONS
-- =====================================================

-- -----------------------------------------------------
-- Function: Mark payment as paid
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION fn_mark_payment_paid(p_payment_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE payments
    SET status = 'PAID',
        paid_date = CURRENT_DATE
    WHERE id = p_payment_id AND status = 'PENDING';

    RETURN FOUND;
END;
$$;

COMMENT ON FUNCTION fn_mark_payment_paid IS 'Marks a payment as paid';

-- -----------------------------------------------------
-- Function: Mark all monthly payments as paid
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION fn_mark_month_paid(p_project_id UUID, p_month_number INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE payments
    SET status = 'PAID',
        paid_date = CURRENT_DATE
    WHERE project_id = p_project_id
      AND month_number = p_month_number
      AND status = 'PENDING';

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;

COMMENT ON FUNCTION fn_mark_month_paid IS 'Marks all payments for a specific month as paid';

-- -----------------------------------------------------
-- Function: Get project payment status
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION fn_get_project_payment_status(p_project_id UUID)
RETURNS TABLE (
    total_payments INTEGER,
    paid_payments INTEGER,
    pending_payments INTEGER,
    total_amount DECIMAL(15, 2),
    paid_amount DECIMAL(15, 2),
    pending_amount DECIMAL(15, 2),
    completion_percentage DECIMAL(5, 2)
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*)::INTEGER AS total_payments,
        COUNT(*) FILTER (WHERE status = 'PAID')::INTEGER AS paid_payments,
        COUNT(*) FILTER (WHERE status = 'PENDING')::INTEGER AS pending_payments,
        COALESCE(SUM(monthly_amount), 0) AS total_amount,
        COALESCE(SUM(monthly_amount) FILTER (WHERE status = 'PAID'), 0) AS paid_amount,
        COALESCE(SUM(monthly_amount) FILTER (WHERE status = 'PENDING'), 0) AS pending_amount,
        CASE
            WHEN COUNT(*) > 0 THEN
                ROUND((COUNT(*) FILTER (WHERE status = 'PAID')::DECIMAL / COUNT(*) * 100), 2)
            ELSE 0
        END AS completion_percentage
    FROM payments
    WHERE project_id = p_project_id;
END;
$$;

COMMENT ON FUNCTION fn_get_project_payment_status IS 'Returns payment status summary for a project';

-- =====================================================
-- STEP 9: ENABLE ROW LEVEL SECURITY (Optional)
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Create policies for authenticated users (full access for now)
CREATE POLICY "Allow all for authenticated" ON projects
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for authenticated" ON project_members
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Allow all for authenticated" ON payments
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- =====================================================
-- STEP 10: TEST DATA (Optional - Run separately)
-- =====================================================

-- Uncomment below to insert test data

/*
-- Insert a test project
INSERT INTO projects (project_name, total_amount, start_date, end_date)
VALUES ('Website Development', 100000.00, '2024-01-01', '2024-06-30');

-- Get the project ID
-- SELECT id FROM projects WHERE project_name = 'Website Development';
-- Use this ID in the members insert below

-- Insert members (replace PROJECT_ID with actual UUID)
-- INSERT INTO project_members (project_id, member_name, role, percentage) VALUES
-- ('PROJECT_ID', 'Ishaq', 'Lead Developer', 40),
-- ('PROJECT_ID', 'Ahmed', 'Designer', 30),
-- ('PROJECT_ID', 'Fathima', 'QA', 20),
-- ('PROJECT_ID', 'Ali', 'Support', 10);

-- View results
-- SELECT * FROM v_project_summary;
-- SELECT * FROM v_member_payment_schedule;
-- SELECT * FROM v_monthly_summary;
*/

-- =====================================================
-- VERIFICATION QUERIES (Run after setup)
-- =====================================================

-- Check tables created
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';

-- Check triggers created
-- SELECT trigger_name, event_manipulation, event_object_table FROM information_schema.triggers WHERE trigger_schema = 'public';

-- Check functions created
-- SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'public' AND routine_type = 'FUNCTION';

-- =====================================================
-- END OF SCHEMA
-- =====================================================
