-- ============================================
-- DATA GOVERNANCE METADATA SCHEMA
-- Purpose: Add role and permission to all tables
-- Level 8: DATA GOVERNANCE 
-- ============================================
BEGIN;

CREATE SCHEMA IF NOT EXISTS governance_v2;

-- 1. Data Domains
CREATE TABLE governance_v2.domains (
    domain_id     SERIAL PRIMARY KEY,
    domain_name   TEXT NOT NULL UNIQUE,
    description   TEXT,
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Data Owners (Business Side)
-- Added unique constraint on role/title to prevent duplicates
CREATE TABLE governance_v2.owners (
    owner_id      SERIAL PRIMARY KEY,
    role_title    TEXT NOT NULL,
    person_name   TEXT,
    domain_id     INT REFERENCES governance_v2.domains(domain_id),
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    updated_at    TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(role_title, domain_id) -- Prevent duplicate roles per domain
);

-- 3. Technical Custodians
-- Added unique constraint on role title
CREATE TABLE governance_v2.custodians (
    custodian_id  SERIAL PRIMARY KEY,
    role_title    TEXT NOT NULL UNIQUE,
    person_name   TEXT,
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Data Catalog (Core Table)
-- Changes: NOT NULL on FKs, added audit columns
CREATE TABLE governance_v2.catalog (
    catalog_id        SERIAL PRIMARY KEY,
    schema_name       TEXT NOT NULL,
    table_name        TEXT NOT NULL,
    column_name       TEXT NOT NULL,
    data_element      TEXT,
    describes         TEXT,
    business_purpose  TEXT,
    domain_id         INT NOT NULL REFERENCES governance_v2.domains(domain_id),
    business_owner_id INT NOT NULL REFERENCES governance_v2.owners(owner_id),
    custodian_id      INT NOT NULL REFERENCES governance_v2.custodians(custodian_id),
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    updated_at        TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (schema_name, table_name, column_name)
);

-- 5. Sensitivity Classification
CREATE TABLE governance_v2.sensitivity (
    sensitivity_id    SERIAL PRIMARY KEY,
    level             TEXT NOT NULL CHECK (level IN ('Internal','Confidential','Restricted')),
    is_pii            BOOLEAN DEFAULT FALSE,
    pii_type          TEXT CHECK (pii_type IN ('Individual', 'Individual/Org', 'Organization', NULL)),
    created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Column Classification (Enforced 1:1)
-- PK is now just catalog_id. A column can only have ONE classification.
CREATE TABLE governance_v2.column_classification (
    catalog_id     INT PRIMARY KEY REFERENCES governance_v2.catalog(catalog_id) ON DELETE CASCADE,
    sensitivity_id INT NOT NULL REFERENCES governance_v2.sensitivity(sensitivity_id)
);

-- 7. Handling Requirements
-- Split applies_to into two nullable FKs.
-- You can apply a rule to ALL 'Confidential' items OR just ONE specific column.
CREATE TABLE governance_v2.handling (
    handling_id    SERIAL PRIMARY KEY,
    rule           TEXT NOT NULL,
    sensitivity_id INT REFERENCES governance_v2.sensitivity(sensitivity_id),
    catalog_id     INT    REFERENCES governance_v2.catalog(catalog_id),
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    CHECK (sensitivity_id IS NOT NULL OR catalog_id IS NOT NULL)
);

-- 8. Roles (for RBAC)
CREATE TABLE governance_v2.roles (
    role_id       SERIAL PRIMARY KEY,
    role_name     TEXT NOT NULL UNIQUE,
    description   TEXT,
    created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- 9. Access Control Matrix
-- Added 'denied_at' and 'reason' to allow explicit denies.
-- 'access_level' can be NULL if the row is purely an explicit deny.
CREATE TABLE governance_v2.access_matrix (
    role_id       INT REFERENCES governance_v2.roles(role_id),
    domain_id     INT REFERENCES governance_v2.domains(domain_id),
    access_level  TEXT CHECK (access_level IN ('None','Read','Limited','Full','Admin') OR access_level IS NULL),
    denied_at     TIMESTAMPTZ, -- If present, explicitly denies access
    reason        TEXT,        -- Why is it denied?
    PRIMARY KEY (role_id, domain_id)
);   
-- Note: If denied_at is NOT NULL, access_level should ideally be NULL or 'None'.

-- ==========================================================
-- POPULATE DATA
-- ==========================================================

INSERT INTO governance_v2.domains (domain_name, description) VALUES
('Finance', 'Financial and client management data'),
('Operations', 'Inventory and transactional data');

INSERT INTO governance_v2.owners (role_title, domain_id) VALUES
('Accounting/Management', 1),
('AR Manager', 1),
('AP Manager', 1),
('Inventory Manager', 2);

INSERT INTO governance_v2.custodians (role_title) VALUES ('DBA');

INSERT INTO governance_v2.sensitivity (level, is_pii, pii_type) VALUES
('Internal', FALSE, NULL),
('Confidential', TRUE, 'Individual'),
('Restricted', TRUE, 'Individual/Org');

INSERT INTO governance_v2.catalog 
    (schema_name, table_name, column_name, data_element, describes, business_purpose, domain_id, business_owner_id, custodian_id) 
VALUES
('Finance','clients','client_id','Client Identification','Client record','Uniquely identify and reference the client',1,1,1),
('Finance','clients','info','Client General Information','Client or Client org','Identify customer for business and account purpose',1,1,1),
('Finance','clients','created_at','Date/Time created','Client or Client org','Recorded creation time',1,1,1);

-- 1:1 Linking (Enforced by PK)
INSERT INTO governance_v2.column_classification (catalog_id, sensitivity_id) VALUES
(1, 2),  -- client_id → Confidential
(2, 3),  -- info → Restricted
(3, 1);  -- created_at → Internal

-- Handling Rules (Now explicit FKs)
-- Example: Apply 'Encrypted at rest' to ALL Confidential items
INSERT INTO governance_v2.handling (rule, sensitivity_id) VALUES
('Access limited to authorized staff', 2), -- level 2 = Confidential
('Encrypted at rest', 2),
('No export to personal devices', 2),
('Audit logging on access', 2),
('Role-based access only', 3), -- level 3 = Restricted
('Encrypted at rest and in transit', 3),
('No email/IM transmission', 3),
('Retention per org policy', 3),
('Deletion on request (GDPR)', 3),
('Standard backup/retention', 1); -- level 1 = Internal

-- Example: Apply a rule to a SPECIFIC column
INSERT INTO governance_v2.handling (rule, catalog_id) VALUES
('Strict retention for client info', 2); -- Only for clients.info

INSERT INTO governance_v2.roles (role_name, description) VALUES
('Accountant','Accounting and financial reporting'),
('AR Staff','Customer receivables'),
('AP Staff','Vendor payables'),
('Inventory Staff','Inventory operations'),
('Manager','Business oversight'),
('Auditor','Audit/review'),
('DBA','Database administration'),
('Developer','Application development'),
('External Accountant','External financial reporting');

-- Access Matrix (Explicit Deny Logic)
-- (role_id, domain_id, access_level)
INSERT INTO governance_v2.access_matrix (role_id, domain_id, access_level) VALUES
(1, 1, 'Limited'),   -- Accountant → Finance
(2, 1, 'Limited'),   -- AR Staff → Finance
(3, 1, 'Limited'),   -- AP Staff → Finance
(4, 2, 'Limited'),   -- Inventory Staff → Operations
(5, 1, 'Full'),      -- Manager → Finance
(5, 2, 'Full'),      -- Manager → Operations
(6, 1, 'Read'),      -- Auditor → Finance
(7, 1, 'Limited'),   -- DBA → Finance
(8, 1, 'Limited'),   -- Developer → Finance
(9, 1, 'None');      -- External Accountant → Finance (Explicit Deny)

-- Example of Explicit Deny with reason (e.g., a new contractor restricted)
-- INSERT INTO governance_v2.access_matrix (role_id, domain_id, access_level, denied_at, reason)
-- VALUES (9, 2, NULL, NOW(), 'Contractor not cleared for Operations');

COMMIT;

SELECT '05 DATA GOVERNANCE V2 - SCHEMA READY' AS STATUS;