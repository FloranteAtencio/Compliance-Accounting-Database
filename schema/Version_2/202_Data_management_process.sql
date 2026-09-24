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

-- Populate Reference Data (Examples)
INSERT INTO management.jurisdiction_mapping (region, regulation, country_code) VALUES
('Philippines', 'Data Privacy Act', 'PH'),
('Australia', 'APP', 'AU'),
('New Zealand', 'Privacy Act', 'NZ'),
('European Union', 'GDPR', 'EU'),
('United States', 'CCPA/State Laws', 'US');

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

-- CREATE SCHEMA IF NOT EXISTS management;

-- -- 2. DATA INVENTORY (The Bridge)
-- CREATE TABLE IF NOT EXISTS management.data_inventory (
--     dataset_id BIGSERIAL PRIMARY KEY,
--     dataset_name VARCHAR(150) NOT NULL UNIQUE,
--     owner_id BIGINT, -- Should reference governance_v2.owners(owner_id) ideally
    
--     -- LINK TO GOVERNANCE (Replaces local classification)
--     domain_id INT REFERENCES governance_v2.domains(domain_id),
    
--     lifecycle_stage VARCHAR(50),
--     source_system VARCHAR(150),
--     contains_personal_data BOOLEAN DEFAULT FALSE,
--     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
-- );

-- -- 3. POLICIES (Needs linkage)
-- CREATE TABLE IF NOT EXISTS management.privacy_policies (
--     policy_id BIGSERIAL PRIMARY KEY,
--     policy_name VARCHAR(150) NOT NULL,
--     policy_type VARCHAR(100),
--     version_no VARCHAR(20),
--     effective_date DATE,
--     status VARCHAR(20) DEFAULT 'ACTIVE' -- ADDED: Track active vs deprecated
-- );

-- -- Data Retention Policy
-- -- Data Classification Policy
-- -- Cross Border Transfer Policy
-- -- Incident Response Policy

-- -- Junction: Which policies apply to which datasets?
-- CREATE TABLE IF NOT EXISTS management.dataset_policy_map (
--     dataset_id BIGINT REFERENCES management.data_inventory(dataset_id),
--     policy_id BIGINT REFERENCES management.privacy_policies(policy_id),
--     PRIMARY KEY (dataset_id, policy_id)
-- );

-- -- 4. JURISDICTION (Reference Data)
-- CREATE TABLE IF NOT EXISTS management.jurisdiction_mapping (
--     jurisdiction_id SERIAL PRIMARY KEY,
--     region VARCHAR(100) NOT NULL,
--     regulation VARCHAR(200) NOT NULL,
--     country_code CHAR(2) -- ADDED: ISO code for matching transfers
-- );

-- -- | Region         | Regulation        |
-- -- | -------------- | ----------------- |
-- -- | Philippines    | Data Privacy Act  |
-- -- | Australia      | APP               |
-- -- | New Zealand    | Privacy Act       |
-- -- | European Union | GDPR              |
-- -- | United States  | CCPA / State Laws |


-- -- 5. CROSS-BORDER TRANSFERS (Linked to Jurisdictions)
-- CREATE TABLE IF NOT EXISTS management.cross_border_transfer (
--     transfer_id BIGSERIAL PRIMARY KEY,
--     dataset_id BIGINT REFERENCES management.data_inventory(dataset_id),
    
--     -- LINK TO JURISDICTIONS
--     source_jurisdiction_id INT REFERENCES management.jurisdiction_mapping(jurisdiction_id),
--     dest_jurisdiction_id INT REFERENCES management.jurisdiction_mapping(jurisdiction_id),
    
--     transfer_legal_basis VARCHAR(200),
--     transfer_status VARCHAR(50),
--     approved_by VARCHAR(100), -- ADDED: Who authorized this?
--     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
-- );

-- -- | Dataset         | Source | Destination |
-- -- | --------------- | ------ | ----------- |
-- -- | AR Export       | PH     | Australia   |
-- -- | Customer Backup | PH     | US          |
-- -- | Analytics Feed  | PH     | NZ          |

-- -- 6. SECURITY CONTROLS (Keep as is)
-- CREATE TABLE IF NOT EXISTS management.security_controls (
--     control_id BIGSERIAL PRIMARY KEY,
--     control_name VARCHAR(150) NOT NULL,
--     control_type VARCHAR(100), -- TECHNICAL, ADMINISTRATIVE, PHYSICAL
--     control_description TEXT,
--     framework_ref VARCHAR(50) -- ADDED: e.g., 'SOC2 CC6.1', 'GDPR Art 32'
-- );

-- -- RBAC
-- -- Encryption At Rest
-- -- Audit Logging
-- -- MFA
-- -- RLS
-- -- Column Masking
-- -- Retention Policy

-- -- 7. RISK REGISTER (Linked to Inventory & Controls)
-- CREATE TABLE IF NOT EXISTS management.risk_register (
--     risk_id BIGSERIAL PRIMARY KEY,
--     dataset_id BIGINT REFERENCES management.data_inventory(dataset_id),
--     control_id BIGINT REFERENCES management.security_controls(control_id), -- Which control failed/is relevant?
--     risk_description TEXT NOT NULL,
--     likelihood SMALLINT CHECK (likelihood BETWEEN 1 AND 5), -- ADDED: Quantify
--     impact SMALLINT CHECK (impact BETWEEN 1 AND 5),         -- ADDED: Quantify
--     risk_level VARCHAR(20), -- Derived: High/Med/Low
--     mitigation_plan TEXT,
--     status VARCHAR(20) DEFAULT 'OPEN' -- OPEN, MITIGATED, ACCEPTED, CLOSED
-- );

-- -- Risk:
-- -- Unauthorized customer export

-- -- Mitigation:
-- -- RBAC + Approval Workflow

-- -- 8. INCIDENT RESPONSE (Linked to Risks)
-- CREATE TABLE IF NOT EXISTS management.incident_response (
--     incident_id BIGSERIAL PRIMARY KEY,
--     risk_id BIGINT REFERENCES management.risk_register(risk_id), -- Was this a known risk?
--     incident_type VARCHAR(150),
--     severity VARCHAR(20), -- CRITICAL, HIGH, MEDIUM, LOW
--     response_action TEXT,
--     detected_at TIMESTAMP,
--     resolved_at TIMESTAMP,
--     resolution_status VARCHAR(50),
--     reported_to_regulator BOOLEAN DEFAULT FALSE -- ADDED: GDPR requirement
-- );
-- -- Unauthorized Data Export
-- -- Cross Border Disclosure
-- -- Lost Backup
-- -- Privilege Escalation

-- -- 9. EVIDENCE (Keep as is, minor tweak)
-- CREATE TABLE IF NOT EXISTS management.controls_evidence (
--     evidence_id BIGSERIAL PRIMARY KEY,
--     control_id BIGINT REFERENCES management.security_controls(control_id),
--     audit_period_start DATE, -- ADDED: Period covered
--     audit_period_end DATE,   -- ADDED: Period covered
--     auditor_name VARCHAR(100), -- ADDED: Who checked?
--     result_status VARCHAR(20) CHECK (result_status IN ('PASS', 'FAIL', 'N/A')), -- ADDED
--     evidence_detail TEXT,
--     attachment_url TEXT -- ADDED: Link to screenshot/doc
-- );

-- -- Quarterly Access Review Completed
-- -- RBAC Configuration Screenshot
-- -- PostgreSQL GRANT Report
-- -- Audit Log Extract
-- -- SIEM Alert

-- -- linking table
-- CREATE TABLE management.dataset_data_subjects (
--     dataset_subject_id BIGSERIAL PRIMARY KEY,

--     dataset_id BIGINT
--         REFERENCES management.data_inventory(dataset_id),

--     subject_type_id BIGINT
--         REFERENCES management.data_subject_types(subject_type_id),

--     jurisdiction_id BIGINT
--         REFERENCES management.jurisdiction_mapping(jurisdiction_id)
-- );

-- CREATE TABLE management.data_subject_types (
--     subject_type_id BIGSERIAL PRIMARY KEY,
--     subject_type_name VARCHAR(100)
-- );

-- CREATE TABLE management.data_subject_categories (
--     category_id BIGSERIAL PRIMARY KEY,
--     category_name VARCHAR(100) NOT NULL,
--     description TEXT
-- );

-- CREATE TABLE management.data_exports(
--     export_id BIGSERIAL PRIMARY KEY,
--     dataset_id BIGINT,
--     recipient_name VARCHAR(150),
--     destination_country VARCHAR(100),
--     export_format VARCHAR(50),
--     row_count BIGINT,
--     approved_by VARCHAR(100),
--     exported_by VARCHAR(100),
--     export_date TIMESTAMP
-- );

-- CREATE TABLE management.vendor_registry
-- (
--     vendor_id BIGSERIAL PRIMARY KEY,
--     vendor_name VARCHAR(150), 

-- );
-- -- AWS
-- -- Azure
-- -- Google
-- -- Australian Accountant
-- -- NZ Analytics Provider
-- -- Power BI
-- -- External Auditor

-- CREATE TABLE management.data_residency(
--     residency_id BIGSERIAL PRIMARY KEY,
--     country_code VARCHAR(5),
--     country_name VARCHAR(50)
-- );

-- CREATE TABLE management.data_export_metadata(
--     residency_id BIGINT REFERENCES management.data_residency(residency_id),
--     vendor_id BIGINT REFERENCES management.vendor_registry (vendor_id),
--     export_id BIGINT REFERENCES management.data_exports(exported_id)
-- );