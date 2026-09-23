-- ============================================
-- COMPLIANCE METADATA SCHEMA
-- Purpose: Add compliance & privacy tracking to all tables
-- Level 6: Privacy Principles Implementation
-- ============================================

SELECT 'Compliance Metadata Schema Start!' as Status;

BEGIN;

-- ============================================
-- 1. DATA CLASSIFICATION TYPES
-- ============================================
DROP TYPE IF EXISTS data_classification_enum CASCADE;
CREATE TYPE data_classification_enum AS ENUM (
    'PUBLIC',           -- No sensitivity restrictions
    'INTERNAL',         -- For organization use only
    'CONFIDENTIAL',     -- Restricted to authorized users
    'SENSITIVE'         -- Highly restricted (PII, Financial, etc)
);

-- ============================================
-- 2. DATA RETENTION PERIODS
-- ============================================
DROP TYPE IF EXISTS retention_period_enum CASCADE;
CREATE TYPE retention_period_enum AS ENUM (
    'PERMANENT',        -- Keep indefinitely (e.g., tax records)
    '7_YEARS',          -- 7 years (financial compliance)
    '5_YEARS',          -- 5 years (general business records)
    '3_YEARS',          -- 3 years (operational data)
    '1_YEAR',           -- 1 year (temporary operational)
    '90_DAYS',          -- 90 days (logs, cache)
    '30_DAYS'           -- 30 days (temporary, session data)
);

-- ============================================
-- 3. COMPLIANCE METADATA TABLE
-- ============================================
DROP TABLE IF EXISTS Compliance.compliance_metadata CASCADE;
CREATE TABLE Compliance.compliance_metadata (
    metadata_id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(255) NOT NULL UNIQUE,
    table_description TEXT,
    data_classification data_classification_enum NOT NULL,
    retention_period retention_period_enum NOT NULL,
    requires_encryption BOOLEAN DEFAULT FALSE,
    requires_audit_log BOOLEAN DEFAULT TRUE,
    pii_present BOOLEAN DEFAULT FALSE,
    financial_data BOOLEAN DEFAULT FALSE,
    data_steward VARCHAR(255),
    compliance_notes TEXT,
    gdpr_applicable BOOLEAN DEFAULT FALSE,
    ph_pdata_applicable BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 8. FIELD-LEVEL ENCRYPTION KEYS TABLE
-- ============================================
DROP TABLE IF EXISTS Compliance.encryption_keys CASCADE;
CREATE TABLE Compliance.encryption_keys (
    key_id BIGSERIAL PRIMARY KEY,
    key_name VARCHAR(255) NOT NULL UNIQUE,
    table_name VARCHAR(255) NOT NULL,
    column_name VARCHAR(255) NOT NULL,
    encryption_algorithm VARCHAR(50),  -- AES-256, etc
    key_rotation_enabled BOOLEAN DEFAULT TRUE,
    key_rotation_interval_days INT DEFAULT 90,
    last_rotated_at TIMESTAMP,
    next_rotation_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(table_name, column_name)
);

-- ============================================
-- 9. DATA RETENTION POLICY TABLE
-- ============================================
DROP TABLE IF EXISTS Compliance.retention_policy CASCADE;
CREATE TABLE Compliance.retention_policy (
    policy_id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(255) NOT NULL,
    retention_period retention_period_enum NOT NULL,
    archive_location VARCHAR(500),
    delete_method VARCHAR(50),  -- SOFT_DELETE, HARD_DELETE, ARCHIVE
    last_purge_date DATE,
    next_purge_date DATE,
    purge_enabled BOOLEAN DEFAULT TRUE,
    policy_description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(table_name)
);

-- ============================================
-- 10. CONSENT & PII MANAGEMENT TABLE
-- ============================================
DROP TABLE IF EXISTS Compliance.pii_consent CASCADE;
CREATE TABLE Compliance.pii_consent (
    consent_id BIGSERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES Compliance.clients(client_id) ON DELETE NO ACTION,
    consent_type VARCHAR(100),  -- MARKETING, ANALYTICS, PROCESSING, etc
    consent_given BOOLEAN NOT NULL,
    consent_date TIMESTAMP NOT NULL,
    consent_version VARCHAR(50),  -- Track which version of policy
    withdrawal_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_pii_consent_client ON Compliance.pii_consent(client_id);

-- ============================================
-- 11. COMPLIANCE AUDIT CHECKLIST
-- ============================================
DROP TABLE IF EXISTS Compliance.compliance_checklist CASCADE;
CREATE TABLE Compliance.compliance_checklist (
    checklist_id BIGSERIAL PRIMARY KEY,
    framework VARCHAR(100),  -- GDPR, PH_PDATA, ISO_27001, etc
    requirement_id VARCHAR(50),
    requirement_description TEXT,
    compliance_level VARCHAR(50),
    implementation_status VARCHAR(50),  -- NOT_STARTED, IN_PROGRESS, COMPLETE, REMEDIATION
    evidence_location TEXT,
    responsible_party VARCHAR(255),
    target_completion_date DATE,
    actual_completion_date DATE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 12. SECURITY INCIDENT LOG
-- ============================================
DROP TABLE IF EXISTS Compliance.security_incident CASCADE;
CREATE TABLE Compliance.security_incident (
    incident_id BIGSERIAL PRIMARY KEY,
    incident_type VARCHAR(100),  -- UNAUTHORIZED_ACCESS, DATA_BREACH, etc
    severity VARCHAR(20),  -- CRITICAL, HIGH, MEDIUM, LOW
    description TEXT,
    affected_tables VARCHAR[],
    affected_records_count INT,
    detected_at TIMESTAMP,
    detected_by VARCHAR(255),
    reported_at TIMESTAMP,
    investigation_status VARCHAR(50),
    resolution_status VARCHAR(50),
    resolution_date TIMESTAMP,
    remediation_actions TEXT,
    notification_sent_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sensitive Tables
INSERT INTO Compliance.compliance_metadata 
(table_name, table_description, data_classification, retention_period, requires_encryption, pii_present, financial_data, data_steward, gdpr_applicable, ph_pdata_applicable)
VALUES
('clients', 'Client master data with contact information', 'SENSITIVE', '7_YEARS', TRUE, TRUE, FALSE, 'Finance Manager', TRUE, TRUE),
('transactions', 'Financial transactions core table', 'CONFIDENTIAL', '7_YEARS', FALSE, FALSE, TRUE, 'Finance Manager', FALSE, FALSE),
('customers', 'Customer contact and billing information', 'SENSITIVE', '3_YEARS', TRUE, TRUE, FALSE, 'Sales Manager', TRUE, TRUE),
('vendors', 'Supplier/vendor contact information', 'CONFIDENTIAL', '5_YEARS', FALSE, FALSE, FALSE, 'Procurement Manager', FALSE, FALSE),
('charts', 'Chart of Accounts for clients', 'CONFIDENTIAL', 'PERMANENT', FALSE, FALSE, TRUE, 'Finance Manager', FALSE, FALSE),
('account_receivables', 'AR transactions', 'CONFIDENTIAL', '7_YEARS', FALSE, FALSE, TRUE, 'Finance Manager', FALSE, FALSE),
('account_payables', 'AP transactions', 'CONFIDENTIAL', '7_YEARS', FALSE, FALSE, TRUE, 'Finance Manager', FALSE, FALSE),
('journals', 'Double-entry journal entries', 'CONFIDENTIAL', '7_YEARS', FALSE, FALSE, TRUE, 'Finance Manager', FALSE, FALSE),
('products', 'Product master data', 'INTERNAL', '5_YEARS', FALSE, FALSE, FALSE, 'Inventory Manager', FALSE, FALSE),
('warehouses', 'Warehouse locations', 'INTERNAL', 'PERMANENT', FALSE, FALSE, FALSE, 'Inventory Manager', FALSE, FALSE),
('event_log', 'Transaction event logging', 'SENSITIVE', '7_YEARS', FALSE, FALSE, FALSE, 'Compliance Officer', TRUE, TRUE),
('audit_trail', 'Audit trail for transactions', 'SENSITIVE', '7_YEARS', FALSE, FALSE, FALSE, 'Compliance Officer', TRUE, TRUE);

COMMIT;

SELECT 'Compliance Metadata Schema Complete!' as Status;
