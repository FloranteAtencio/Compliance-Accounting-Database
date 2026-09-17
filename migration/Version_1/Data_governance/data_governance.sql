SELECT ' 05 DATA GOVERNANCE Schema Start!' as Status;


BEGIN;

CREATE SCHEMA IF NOT EXISTS governance;

-- 1. Data Domains
CREATE TABLE governance.domains (
    domain_id     SERIAL PRIMARY KEY,
    domain_name   TEXT NOT NULL UNIQUE,
    description   TEXT
);

-- 2. Data Owners (business side)
CREATE TABLE governance.owners (
    owner_id      SERIAL PRIMARY KEY,
    role_title    TEXT NOT NULL,
    person_name   TEXT,
    domain_id     INT REFERENCES governance.domains(domain_id)
);

-- 3. Technical Custodians
CREATE TABLE governance.custodians (
    custodian_id  SERIAL PRIMARY KEY,
    role_title    TEXT NOT NULL,
    person_name   TEXT
);

-- 4. Data Catalog (the core table)
CREATE TABLE governance.catalog (
    catalog_id        SERIAL PRIMARY KEY,
    schema_name       TEXT NOT NULL,
    table_name        TEXT NOT NULL,
    column_name       TEXT NOT NULL,
    data_element      TEXT,
    describes         TEXT,
    business_purpose  TEXT,
    domain_id         INT REFERENCES governance.domains(domain_id),
    business_owner_id INT REFERENCES governance.owners(owner_id),
    custodian_id      INT REFERENCES governance.custodians(custodian_id),
    UNIQUE (schema_name, table_name, column_name)
);

-- 5. Sensitivity Classification
CREATE TABLE governance.sensitivity (
    sensitivity_id    SERIAL PRIMARY KEY,
    level             TEXT NOT NULL CHECK (level IN ('Internal','Confidential','Restricted')),
    is_pii            BOOLEAN DEFAULT FALSE,
    pii_type          TEXT
);

-- 6. Column Classification (links catalog → sensitivity)
CREATE TABLE governance.column_classification (
    catalog_id     INT PRIMARY KEY REFERENCES governance.catalog(catalog_id),
    sensitivity_id INT NOT NULL REFERENCES governance.sensitivity(sensitivity_id)
);

-- 7. Handling Requirements
CREATE TABLE governance.handling (
    handling_id    SERIAL PRIMARY KEY,
    rule           TEXT NOT NULL,
    sensitivity_id INT REFERENCES governance.sensitivity(sensitivity_id),  -- applies to a level
    catalog_id     INT    REFERENCES governance.catalog(catalog_id),        -- applies to one column
    CHECK (sensitivity_id IS NOT NULL OR catalog_id IS NOT NULL)
);
-- 8. Roles (for RBAC)
CREATE TABLE governance.roles (
    role_id       SERIAL PRIMARY KEY,
    role_name     TEXT NOT NULL UNIQUE,
    description   TEXT
);

-- 9. Access Control Matrix
CREATE TABLE governance.access_matrix (
    role_id       INT REFERENCES governance.roles(role_id),
    domain_id     INT REFERENCES governance.domains(domain_id),
    access_level  TEXT NOT NULL CHECK (access_level IN ('None','Read','Limited','Full','Admin')),
    PRIMARY KEY (role_id, domain_id)
);   

INSERT INTO governance.domains (domain_name, description) VALUES
('Finance', 'Financial and client management data'),
('Operations', 'Inventory and transactional data');

INSERT INTO governance.owners (role_title, domain_id) VALUES
('Accounting/Management', 1),
('AR Manager', 1),
('AP Manager', 1),
('Inventory Manager', 2);

INSERT INTO governance.custodians (role_title) VALUES ('DBA');

INSERT INTO governance.sensitivity (level, is_pii, pii_type) VALUES
('Internal', FALSE, NULL),
('Confidential', TRUE, 'Individual'),
('Restricted', TRUE, 'Individual/Org');

INSERT INTO governance.catalog (schema_name, table_name, column_name, data_element, describes, business_purpose, domain_id, business_owner_id, custodian_id) VALUES
('Finance','clients','client_id','Client Identification','Client record','Uniquely identify and reference the client',1,1,1),
('Finance','clients','info','Client General Information','Client or Client org','Identify customer for business and account purpose',1,1,1),
('Finance','clients','created_at','Date/Time created','Client or Client org','Recorded creation time',1,1,1);

INSERT INTO governance.column_classification (catalog_id, sensitivity_id) VALUES
(1, 2),  -- client_id → Confidential
(2, 3),  -- info → Restricted
(3, 1);  -- created_at → Internal

INSERT INTO governance.handling (rule, applies_to) VALUES
('Access limited to authorized staff','Confidential'),
('Encrypted at rest','Confidential'),
('No export to personal devices','Confidential'),
('Audit logging on access','Confidential'),
('Role-based access only','Restricted'),
('Encrypted at rest and in transit','Restricted'),
('No email/IM transmission','Restricted'),
('Retention per org policy','Restricted'),
('Deletion on request (GDPR)','Restricted'),
('Standard backup/retention','Internal'),
('Audit logging on modification','Internal');

INSERT INTO governance.roles (role_name, description) VALUES
('Accountant','Accounting and financial reporting'),
('AR Staff','Customer receivables'),
('AP Staff','Vendor payables'),
('Inventory Staff','Inventory operations'),
('Manager','Business oversight'),
('Auditor','Audit/review'),
('DBA','Database administration'),
('Developer','Application development'),
('External Accountant','External financial reporting');

INSERT INTO governance.access_matrix (role_id, domain_id, access_level) VALUES
(1, 1, 'Limited'),   -- Accountant → Finance
(2, 1, 'Limited'),   -- AR Staff → Finance
(3, 1, 'Limited'),   -- AP Staff → Finance
(4, 2, 'Limited'),   -- Inventory Staff → Operations
(5, 1, 'Full'),      -- Manager → Finance
(5, 2, 'Full'),      -- Manager → Operations
(6, 1, 'Read'),      -- Auditor → Finance
(7, 1, 'Limited'),   -- DBA → Finance
(8, 1, 'Limited'),   -- Developer → Finance
(9, 1, 'None');      -- External Accountant → Finance   

COMMIT;

SELECT '05 DATA GOVERNANCE Schema Success! ' AS STATUS;
