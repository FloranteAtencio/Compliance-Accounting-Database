CREATE SCHEMA IF NOT EXISTS management;

-- 1. DATA SUBJECTS (Moved up to avoid ordering issues)
CREATE TABLE IF NOT EXISTS management.data_subject_types (
    subject_type_id BIGSERIAL PRIMARY KEY,
    subject_type_name VARCHAR(100) NOT NULL UNIQUE -- e.g., 'Customer', 'Employee', 'Vendor'
);

-- 2. DATA INVENTORY (The Bridge)
CREATE TABLE IF NOT EXISTS management.data_inventory (
    dataset_id BIGSERIAL PRIMARY KEY,
    dataset_name VARCHAR(150) NOT NULL UNIQUE,
    owner_id BIGINT, -- Link to governance_v2.owners(owner_id)
    
    -- LINK TO GOVERNANCE
    domain_id INT REFERENCES governance_v2.domains(domain_id),
    
    lifecycle_stage VARCHAR(50),
    source_system VARCHAR(150),
    contains_personal_data BOOLEAN DEFAULT FALSE,
    
    -- LEVEL 14: DATA RESIDENCY (Where is this data stored?)
    residency_country_code CHAR(2), -- e.g., 'PH', 'US'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE management.dataset_table_map (
    dataset_id   BIGINT REFERENCES management.data_inventory(dataset_id),
    schema_name  TEXT NOT NULL,
    table_name   TEXT NOT NULL,
    PRIMARY KEY (dataset_id, schema_name, table_name)
);

-- 3. POLICIES
CREATE TABLE IF NOT EXISTS management.privacy_policies (
    policy_id BIGSERIAL PRIMARY KEY,
    policy_name VARCHAR(150) NOT NULL,
    policy_type VARCHAR(100), -- 'Data Retention', 'Cross Border', 'Incident Response'
    version_no VARCHAR(20),
    effective_date DATE,
    status VARCHAR(20) DEFAULT 'ACTIVE'
);

CREATE TABLE IF NOT EXISTS management.dataset_policy_map (
    dataset_id BIGINT REFERENCES management.data_inventory(dataset_id),
    policy_id BIGINT REFERENCES management.privacy_policies(policy_id),
    PRIMARY KEY (dataset_id, policy_id)
);

-- 4. JURISDICTION
CREATE TABLE IF NOT EXISTS management.jurisdiction_mapping (
    jurisdiction_id SERIAL PRIMARY KEY,
    region VARCHAR(100) NOT NULL,
    regulation VARCHAR(200) NOT NULL,
    country_code CHAR(2) NOT NULL UNIQUE -- ISO Code
);

-- 5. CROSS-BORDER TRANSFERS
CREATE TABLE IF NOT EXISTS management.cross_border_transfer (
    transfer_id BIGSERIAL PRIMARY KEY,
    dataset_id BIGINT REFERENCES management.data_inventory(dataset_id),
    
    source_jurisdiction_id INT REFERENCES management.jurisdiction_mapping(jurisdiction_id),
    dest_jurisdiction_id INT REFERENCES management.jurisdiction_mapping(jurisdiction_id),
    
    transfer_legal_basis VARCHAR(200), -- e.g., 'SCCs', 'Adequacy Decision'
    transfer_status VARCHAR(50) DEFAULT 'ACTIVE', -- 'ACTIVE', 'SUSPENDED'
    approved_by VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6. SECURITY CONTROLS
CREATE TABLE IF NOT EXISTS management.security_controls (
    control_id BIGSERIAL PRIMARY KEY,
    control_name VARCHAR(150) NOT NULL,
    control_type VARCHAR(100), -- 'TECHNICAL', 'ADMINISTRATIVE', 'PHYSICAL'
    control_description TEXT,
    framework_ref VARCHAR(50) -- e.g., 'SOC2 CC6.1', 'GDPR Art 32'
);

-- 7. RISK REGISTER
CREATE TABLE IF NOT EXISTS management.risk_register (
    risk_id BIGSERIAL PRIMARY KEY,
    dataset_id BIGINT REFERENCES management.data_inventory(dataset_id),
    control_id BIGINT REFERENCES management.security_controls(control_id),
    risk_description TEXT NOT NULL,
    likelihood SMALLINT CHECK (likelihood BETWEEN 1 AND 5),
    impact SMALLINT CHECK (impact BETWEEN 1 AND 5),
    risk_level VARCHAR(20), -- Derived: 'HIGH', 'MEDIUM', 'LOW'
    mitigation_plan TEXT,
    status VARCHAR(20) DEFAULT 'OPEN' -- 'OPEN', 'MITIGATED', 'ACCEPTED', 'CLOSED'
);

-- 8. INCIDENT RESPONSE
CREATE TABLE IF NOT EXISTS management.incident_response (
    incident_id BIGSERIAL PRIMARY KEY,
    risk_id BIGINT REFERENCES management.risk_register(risk_id),
    incident_type VARCHAR(150),
    severity VARCHAR(20), -- 'CRITICAL', 'HIGH', 'MEDIUM', 'LOW'
    response_action TEXT,
    detected_at TIMESTAMP,
    resolved_at TIMESTAMP,
    resolution_status VARCHAR(50),
    reported_to_regulator BOOLEAN DEFAULT FALSE
);

-- 9. EVIDENCE
CREATE TABLE IF NOT EXISTS management.controls_evidence (
    evidence_id BIGSERIAL PRIMARY KEY,
    control_id BIGINT REFERENCES management.security_controls(control_id),
    audit_period_start DATE,
    audit_period_end DATE,
    auditor_name VARCHAR(100),
    result_status VARCHAR(20) CHECK (result_status IN ('PASS', 'FAIL', 'N/A')),
    evidence_detail TEXT,
    attachment_url TEXT
);

-- 10. DATA SUBJECTS MAPPING
CREATE TABLE IF NOT EXISTS management.dataset_data_subjects (
    dataset_subject_id BIGSERIAL PRIMARY KEY,
    dataset_id BIGINT REFERENCES management.data_inventory(dataset_id),
    subject_type_id BIGINT REFERENCES management.data_subject_types(subject_type_id),
    jurisdiction_id BIGINT REFERENCES management.jurisdiction_mapping(jurisdiction_id)
);

-- 11. DATA EXPORTS (Fixed Logic)
CREATE TABLE IF NOT EXISTS management.data_exports (
    export_id BIGSERIAL PRIMARY KEY,
    dataset_id BIGINT REFERENCES management.data_inventory(dataset_id),
    vendor_id BIGINT REFERENCES management.vendor_registry(vendor_id), -- Link to vendor
    recipient_name VARCHAR(150),
    destination_country VARCHAR(50),
    export_format VARCHAR(50),
    row_count BIGINT,
    approved_by VARCHAR(100),
    exported_by VARCHAR(100),
    export_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 12. VENDOR REGISTRY (Fixed)
CREATE TABLE IF NOT EXISTS management.vendor_registry (
    vendor_id BIGSERIAL PRIMARY KEY,
    vendor_name VARCHAR(150) NOT NULL,
    vendor_type VARCHAR(100), -- 'CLOUD', 'ACCOUNTANT', 'ANALYTICS', 'AUDITOR'
    jurisdiction VARCHAR(50), -- Vendor's location
    compliance_status VARCHAR(50) DEFAULT 'PENDING', -- 'COMPLIANT', 'NON-COMPLIANT'
    risk_level VARCHAR(20) DEFAULT 'MEDIUM'
);

-- 13. DATA RESIDENCY (Fixed Linkage)
CREATE TABLE IF NOT EXISTS management.data_residency (
    residency_id BIGSERIAL PRIMARY KEY,
    country_code CHAR(2) NOT NULL UNIQUE,
    country_name VARCHAR(50) NOT NULL,
    data_localization_required BOOLEAN DEFAULT FALSE -- e.g., PH, CN require local storage
);

-- 14. DATA EXPORT METADATA (Fixed Linkage)
-- This table tracks the *destination* residency of an export
CREATE TABLE IF NOT EXISTS management.data_export_metadata (
    metadata_id BIGSERIAL PRIMARY KEY,
    export_id BIGINT REFERENCES management.data_exports(export_id), -- Fixed column name
    residency_id BIGINT REFERENCES management.data_residency(residency_id), -- Destination country
    vendor_id BIGINT REFERENCES management.vendor_registry(vendor_id), -- Who received it?
    transfer_record_id BIGINT REFERENCES management.cross_border_transfer(transfer_id), -- Optional link to legal basis
    approved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- POPULATION
-- =============================================================================

INSERT INTO management.data_inventory 
(dataset_name, domain_id, contains_personal_data, residency_country_code, source_system)
VALUES
('Customer Financial Records', 1, TRUE,  'PH', 'ERP Core'),
('Vendor Payables',            1, FALSE, 'PH', 'ERP Core'),
('Transaction History',        1, FALSE, 'PH', 'ERP Core'),
('Inventory Movements',        2, FALSE, 'PH', 'ERP Core');

-- Then map physical tables to each dataset
INSERT INTO management.dataset_table_map VALUES
(1,'Finance','customers'), (1,'Finance','account_receivables'),
(1,'Finance','ar_ext'),    (1,'Finance','ar_product_line'),
(2,'Finance','vendors'),   (2,'Finance','account_payables'),
(2,'Finance','ap_ext');

INSERT INTO management.privacy_policies(policy_name,policy_type,version_no,effective_date)
VALUES
('Financial Retention','Data Retention','Version 1', CURRENT_TIMESTAMP),
('PH Data Privacy','Cross Border','Version 1', CURRENT_TIMESTAMP),
('Data Breach','Incident','Version 1', CURRENT_TIMESTAMP);

INSERT INTO management.dataset_policy_map
VALUES (1,1),(1,2),(2,1),(2,2);

-- Populate Reference Data (Examples)
INSERT INTO management.jurisdiction_mapping (region, regulation, country_code) VALUES
('Philippines', 'Data Privacy Act', 'PH'),
('Australia', 'APP', 'AU'),
('New Zealand', 'Privacy Act', 'NZ'),
('European Union', 'GDPR', 'EU'),
('United States', 'CCPA/State Laws', 'US');

INSERT INTO management.cross_border_transfer(dataset_id,source_jurisdiction_id,dest_jurisdiction_id,transfer_legal_basis,transfer_status,approved_by)
VALUES(1,2,1,'External Accountanting','Active','Accountant_CJ');

INSERT INTO management.security_controls (control_name,control_type,control_description,framework_ref)
VALUES
('privacy Act','ADMINISTRATIVE','How data is use or collect','Data Privacy act PH'),
('privacy Act','ADMINISTRATIVE','How data is use or collect','Data Privacy act AUS');

-- INSERT INTO management.risk_register(dataset_id,control_id,risk_description,likelihood,impact,risk_level,mitigation_plan,status)
-- VALUES(1,1,'Unauthorized Access of data',4,4,'HIGH','Role Base Access', 'OPEN');
-- VALUES(1,2,'Leakage of data',1,1,'LOW','Data minimization, masking or tokenization', 'OPEN');

-- INSERT INTO management.incident_response(risk_id,incident_type,severity,response_action,detected_at,resolved_at,resolution_status,reported_to_regulator)
-- VALUES(2,'Data Leakage','LOW','Limit Storage Access(Cloud Storage)',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,'GOOD',FALSE)

INSERT INTO management.data_residency (country_code, country_name, data_localization_required) VALUES
('PH', 'Philippines', TRUE),
('US', 'United States', FALSE),
('AU', 'Australia', FALSE);

INSERT INTO management.data_subject_types (subject_type_name) VALUES
('Customer'), ('Employee'), ('Vendor'), ('Contractor'), ('Partner');

INSERT INTO management.vendor_registry (vendor_name, vendor_type, jurisdiction, compliance_status) VALUES
('AWS', 'CLOUD', 'US', 'COMPLIANT'),
('Power BI', 'ANALYTICS', 'US', 'COMPLIANT'),
('External Auditor', 'AUDITOR', 'PH', 'PENDING');

SELECT 'Management Schema Complete!' as Status;
