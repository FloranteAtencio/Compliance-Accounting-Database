BEGIN;

-- =========================================================
-- Audit
-- Loging
-- =========================================================

DROP TABLE IF EXISTS Audit.audit_logs CASCADE;
CREATE TABLE IF NOT EXISTS Audit.audit_logs (
    audit_id SERIAL PRIMARY KEY,
    table_name VARCHAR(255) NOT NULL,
    rec_transact TEXT NOT NULL,
    operation VARCHAR(20) NOT NULL, 
    log_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by VARCHAR(50) NOT NULL,
    prev_hash TEXT,
    row_hash TEXT
);

DROP TABLE IF EXISTS Audit.audit_logs_extended CASCADE;
CREATE TABLE Audit.audit_logs_extended (
    extended_audit_id BIGSERIAL PRIMARY KEY,
    audit_id INT REFERENCES Audit.audit_logs(audit_id) ON DELETE NO ACTION,
    client_id INT REFERENCES Finance.clients(client_id) ON DELETE NO ACTION,
    table_name VARCHAR(255) NOT NULL,
    record_id INT NOT NULL,
    operation VARCHAR(20) NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    field_name VARCHAR(255),
    old_value TEXT,
    new_value TEXT,
    changed_by VARCHAR(50) NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    session_id TEXT,
    UNIQUE(audit_id, field_name)
);

DROP TABLE IF EXISTS Audit.import_sessions CASCADE;
CREATE TABLE Audit.import_sessions (
    session_id SERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES Finance.clients(client_id) ON DELETE NO ACTION,
    import_type VARCHAR(50) NOT NULL,  -- 'transactions', 'ar', 'ap', 'inventory', etc.
    imported_by VARCHAR(100) NOT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    status VARCHAR(20) DEFAULT 'IN_PROGRESS' CHECK (status IN ('IN_PROGRESS', 'SUCCESS', 'PARTIAL_SUCCESS', 'FAILED')),
    total_records INT DEFAULT 0,
    successful_records INT DEFAULT 0,
    failed_records INT DEFAULT 0,
    error_summary TEXT,
    source_file VARCHAR(500),
    notes TEXT
);


DROP TABLE IF EXISTS Audit.import_detail_logs CASCADE;
CREATE TABLE Audit.import_detail_logs (
    detail_id BIGSERIAL PRIMARY KEY,
    session_id INT NOT NULL REFERENCES Audit.import_sessions(session_id) ON DELETE NO ACTION,
    row_number INT NOT NULL,
    table_name VARCHAR(255) NOT NULL,
    record_data JSONB NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('SUCCESS', 'FAILED', 'SKIPPED', 'WARNED')),
    error_message TEXT,
    warning_message TEXT,
    created_record_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


DROP TABLE IF EXISTS Audit.import_validation_log CASCADE;
CREATE TABLE Audit.import_validation_log (
    validation_id BIGSERIAL PRIMARY KEY,
    session_id INT REFERENCES Audit.import_sessions(session_id) ON DELETE NO ACTION,
    row_number INT NOT NULL,
    field_name VARCHAR(255) NOT NULL,
    validation_rule VARCHAR(255) NOT NULL,
    expected_value TEXT,
    actual_value TEXT,
    is_valid BOOLEAN NOT NULL,
    severity VARCHAR(20) DEFAULT 'ERROR' CHECK (severity IN ('ERROR', 'WARNING', 'INFO')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- Staging  
-- Audit
-- Trail
-- =========================================================

-- 2. WORKFLOW TABLE
CREATE TABLE IF NOT EXISTS Audit.import_workflows (
    session_id INT,
    staging_record_id BIGINT,
    staging_table VARCHAR(50),
    previous_state VARCHAR(50),
    new_state VARCHAR(50),
    changed_by VARCHAR(100),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

-- 3. APPROVAL TABLE
CREATE TABLE IF NOT EXISTS Audit.import_approvals (
    session_id INT,
    staging_record_id BIGINT,   
    approval_level SMALLINT,
    approval_status VARCHAR(20),
    approved_by VARCHAR(100),
    approved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    comments TEXT
);

-- =========================================================
-- Production  
-- Audit
-- Trail
-- =========================================================

DROP TABLE IF EXISTS Audit.transaction_lifecycle CASCADE;
CREATE TABLE Audit.transaction_lifecycle (
    lifecycle_id BIGSERIAL PRIMARY KEY,
    transaction_id INT NOT NULL REFERENCES Finance.transactions(transaction_id) ON DELETE NO ACTION,
    client_id INT NOT NULL REFERENCES Finance.clients(client_id) ON DELETE NO ACTION,
    previous_state VARCHAR(50),
    new_state VARCHAR(50) NOT NULL CHECK (new_state IN (
        'DRAFT', 'SUBMITTED', 'VALIDATED', 'POSTED', 
        'RECONCILED', 'APPROVED', 'ARCHIVED', 'REJECTED'
    )),
    state_reason VARCHAR(255),
    changed_by VARCHAR(100) NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

DROP TABLE IF EXISTS Audit.approval_chain CASCADE;
CREATE TABLE Audit.approval_chain (
    approval_id BIGSERIAL PRIMARY KEY,
    transaction_id INT NOT NULL REFERENCES Finance.transactions(transaction_id) ON DELETE NO ACTION,
    client_id INT NOT NULL REFERENCES Finance.clients(client_id) ON DELETE NO ACTION,
    approval_level INT NOT NULL,  -- 1=Bookkeeper, 2=Supervisor, 3=Manager, etc.
    approver_role VARCHAR(100) NOT NULL,
    approver_name VARCHAR(100),
    status VARCHAR(20) NOT NULL CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    approval_comment TEXT,
    approved_at TIMESTAMP,
    required_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS Audit.reconciliation_tracking CASCADE;
CREATE TABLE Audit.reconciliation_tracking (
    reconciliation_id BIGSERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES Finance.clients(client_id) ON DELETE NO ACTION,
    account_id INT NOT NULL REFERENCES Finance.charts(chart_id) ON DELETE NO ACTION,
    reconciliation_date DATE NOT NULL,
    reconciled_by VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('PENDING', 'IN_PROGRESS', 'RECONCILED', 'DISCREPANCY_FOUND')),
    opening_balance DECIMAL(15,2),
    closing_balance DECIMAL(15,2),
    expected_balance DECIMAL(15,2),
    discrepancy_amount DECIMAL(15,2),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP
);

DROP TABLE IF EXISTS Audit.record_lineage CASCADE;
CREATE TABLE Audit.record_lineage (
    lineage_id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(255) NOT NULL,
    record_id INT NOT NULL,
    client_id INT REFERENCES Finance.clients(client_id) ON DELETE NO ACTION,
    source_type VARCHAR(50) NOT NULL CHECK (source_type IN (
        'MANUAL_ENTRY', 'SPREADSHEET_IMPORT', 'API_IMPORT', 
        'SYSTEM_GENERATED', 'CORRECTION', 'REVERSAL'
    )),
    source_file VARCHAR(500),
    import_session_id INT REFERENCES Audit.import_sessions(session_id) ON DELETE NO ACTION,
    import_row_number INT,
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_modified_by VARCHAR(100),
    last_modified_at TIMESTAMP,
    prev_hash TEXT,
    row_hash TEXT,
    is_original BOOLEAN DEFAULT TRUE
);

COMMIT;

SELECT '15 Audit Schema Tables Complete' as Status;