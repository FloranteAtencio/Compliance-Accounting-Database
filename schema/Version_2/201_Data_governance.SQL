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

-- 1. Add enforcement columns to governance's classification
ALTER TABLE governance_v2.column_classification
ADD COLUMN requires_encryption BOOLEAN DEFAULT FALSE,
ADD COLUMN masking_required    BOOLEAN DEFAULT FALSE;

-- -- 2. Migrate existing values from Finance
-- UPDATE governance_v2.column_classification cc
-- SET requires_encryption = fc.requires_encryption,
--     masking_required    = fc.masking_required
-- FROM governance_v2.catalog g
-- JOIN Finance.column_classification fc
--   ON fc.table_name  = g.table_name
--  AND fc.column_name = g.column_name
-- WHERE cc.catalog_id = g.catalog_id;

-- -- 3. Then drop
-- DROP TABLE Finance.column_classification CASCADE;

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

CREATE TABLE governance_v2.access_reviews (
    review_id       BIGSERIAL PRIMARY KEY,
    reviewed_by     TEXT NOT NULL,
    review_date     TIMESTAMPTZ DEFAULT NOW(),
    review_period   TEXT NOT NULL,          -- '2026-Q3'
    scope           TEXT NOT NULL,          -- 'ALL' or domain name
    findings        TEXT,                   -- what was wrong
    actions_taken   TEXT,                   -- what got fixed
    next_review_due DATE NOT NULL,
    sign_off        BOOLEAN DEFAULT FALSE
);

-- Optional: track per-role decisions within a review
CREATE TABLE governance_v2.access_review_items (
    item_id      BIGSERIAL PRIMARY KEY,
    review_id    BIGINT REFERENCES governance_v2.access_reviews(review_id),
    role_id      INT REFERENCES governance_v2.roles(role_id),
    domain_id    INT REFERENCES governance_v2.domains(domain_id),
    decision     TEXT CHECK (decision IN ('APPROVED','REVOKED','MODIFIED')),
    notes        TEXT
);
-- Data Policy
CREATE TABLE governance_v2.data_standards (
    standard_id   SERIAL PRIMARY KEY,
    standard_name TEXT NOT NULL,        -- 'currency_format'
    applies_to    TEXT NOT NULL,        -- 'pattern: %amount%' or specific cols
    rule_text     TEXT NOT NULL,        -- human-readable definition
    enforcement   TEXT CHECK (enforcement IN 
                  ('CONSTRAINT','TRIGGER','ETL','MANUAL','Domain')),
    owner_id      INT REFERENCES governance_v2.owners(owner_id),
    effective_from DATE DEFAULT CURRENT_DATE
);
-- ==========================================================
-- POPULATE DATA
-- ==========================================================

INSERT INTO governance_v2.domains (domain_name, description) VALUES
('Finance', 'Financial and client management data'), --1
('Operations', 'Inventory and transactional data'),--2
('Management', 'Business Oversight data'), --3
('Audit', 'Auidt and compliance data'), --4
('Administration', 'Control data'), --5 
('Analsyt', 'Business and analytic data'), --6
('Developer', 'Develop project data'); --7

INSERT INTO governance_v2.owners (role_title, domain_id) VALUES
('Accounting/Management', 3),--1
('AR Manager', 1),--2
('AP Manager', 1),--3
('Sale Manager', 1),--4
('Administrator', 5),--5
('Developer', 7),--6
('Data Clerk', 2),--7
('Auditor', 4),--8
('Inventory Manager', 1),--9
('Analysts', 6);--10
INSERT INTO governance_v2.custodians (role_title) VALUES ('DBA');

INSERT INTO governance_v2.sensitivity (level, is_pii, pii_type) VALUES
('Public', FALSE, NULL), -- 1
('Internal', FALSE, NULL), -- 2
('Confidential', TRUE, 'Individual'), -- 3
('Restricted', TRUE, 'Individual/Org'); -- 4
('Highly Restricted', TRUE, 'Individual/Org'); -- 5

INSERT INTO governance_v2.catalog 
    (schema_name, table_name, column_name, data_element, describes, business_purpose, domain_id, business_owner_id, custodian_id) 
VALUES
('Finance',	'clients',	'client_id',	'Client Identification',	'Client record',	'To uniquely Identify and reference the client within the system',	1,	2,	1),
('Finance',	'clients',	'info',	'Client General Information',	'Client or Client org',	'To Identify the customer for business and account purpose',	1,	2,	1),
('Finance',	'clients',	'created_at',	'Date and Time created',	'Client or Client org',	'To have a recorded time when it created',	1,	2,	1),
('Finance',	'coa_templates',	'template_id',	'Template unique identification',	'Template Identification',	'To uniquely Identify and reference the template',	1,	2,	1),
('Finance',	'coa_templates',	'template_name',	'Template name',	'Template name',	'To Identify the account template',	1,	2,	1),
('Finance',	'coa_templates',	'description',	'Template Description',	'Template description',	'To provide more details',	1,	2,	1),
('Finance',	'coa_templates',	'created_at',	'Date and Time created',	'Template created time',	'To have a recorded time when it created',	1,	2,	1),
('Finance',	'coa_template_accounts',	'template_account_id',	'Unique Identification',	'chart of account assigned to a template Identification',	'To uniquely identify and reference chart of account',	1,	2,	1),
('Finance',	'coa_template_accounts',	'template_id',	'Unique Identification on related table',	'chart of account assigned to a template related table identification',	'To identify table related',	1,	2,	1),
('Finance',	'coa_template_accounts',	'account_code',	'Identification code',	'chart of account assigned to a template code',	'To identify account via code',	1,	2,	1),
('Finance',	'coa_template_accounts',	'account_name',	'account name',	'chart of account assigned to a template name',	'To identify account name',	1,	2,	1),
('Finance',	'coa_template_accounts',	'account_type',	'account type',	'chart of account assigned to a template type',	'To identify account type',	1,	2,	1),
('Finance',	'charts',	'chart_id',	'Unique Identification',	'account uniquely identification',	'to Uniquely Identify and reference',	1,	2,	1),
('Finance',	'charts',	'client_id',	'Unique Identification on related table',	'account table related identification',	'To identify account related table',	1,	2,	1),
('Finance',	'charts',	'account',	'account name',	'account name',	'To identify account',	1,	2,	1),
('Finance',	'charts',	'account_code',	'Identification code',	'account code',	'To Identify number',	1,	2,	1),
('Finance',	'charts',	'type',	'account type',	'account type',	'To identify type',	1,	2,	1),
('Finance',	'charts',	'is_active',	'account reusable',	'account is usable',	'To check if it still usable',	1,	2,	1),
('Finance',	'charts',	'created_at',	'Date and Time created',	'account time created',	'To have a recorded time when it created',	1,	2,	1),
('Finance',	'account_roles',	'role_id',	'Unique Identification',	'account role uniquely identification',	'To Uniquely identify and reference',	1,	2,	1),
('Finance',	'account_roles',	'chart_id',	'Unique Identification on related table',	'account role table related identification',	'To identify related table',	1,	2,	1),
('Finance',	'account_roles',	'role_name',	'role_name',	'role name',	'To Identify role name',	1,	2,	1),
('Finance',	'account_roles',	'created_at',	'Date and Time created',	'Role time created',	'To have a recorded time when it created',	1,	2,	1),
('Finance',	'account_properties',	'property_id',	'Unique Identification',	'account properties uniquely identification',	'To Uniquely identify and reference',	1,	2,	1),
('Finance',	'account_properties',	'chart_id',	'Unique Identification on related table',	'account properties table related identification',	'To identify related table',	1,	2,	1),
('Finance',	'account_properties',	'is_payable',	'account verification',	'account properties usability',	'To check if it still usable',	1,	2,	1),
('Finance',	'account_properties',	'is_debt',	'account verification',	'account properties usability',	'To check if it still usable',	1,	2,	1),
('Finance',	'account_properties',	'is_bank_account',	'account verification',	'account properties usability',	'To check if it still usable',	1,	2,	1),
('Finance',	'account_properties',	'is_credit_card',	'account verification',	'account properties usability',	'To check if it still usable',	1,	2,	1),
('Finance',	'account_properties',	'requires_reconciliation',	'account verification',	'account properties usability',	'To check if it still usable',	1,	2,	1),
('Finance',	'account_properties',	'created_at',	'Date and Time created',	'account properties created',	'To check if it still usable',	1,	2,	1),
('Finance',	'transactions',	'transaction_id',	'Transaction Identification',	'Transaction record',	'To uniquely identify and reference the transaction',	1,	2,	1),
('Finance',	'transactions',	'description',	'Transaction Description',	'Transaction details',	'To provide transaction context and details',	1,	2,	1),
('Finance',	'transactions',	'idempotency_key',	'Unique Transaction Key',	'Prevents duplicate transactions',	'To ensure transaction uniqueness and prevent duplicates',	1,	2,	1),
('Finance',	'transactions',	'client_id',	'Related Client Identification',	'Transaction owner',	'To link transaction to client',	1,	2,	1),
('Finance',	'transactions',	'created_at',	'Date and Time created',	'Transaction timestamp',	'To have recorded time when transaction created',	1,	2,	1),
('Finance',	'journals',	'journal_id',	'Journal Entry Identification',	'Journal entry record',	'To uniquely identify and reference journal entry',	1,	2,	1),
('Finance',	'journals',	'transaction_id',	'Related Transaction Identification',	'Journal to transaction link',	'To link journal to transaction',	1,	2,	1),
('Finance',	'journals',	'chart_id',	'Related Chart Identification',	'Journal to chart of account link',	'To link journal to account',	1,	2,	1),
('Finance',	'journals',	'date',	'Journal Entry Date',	'Date when entry posted',	'To record entry date for financial reporting',	1,	2,	1),
('Finance',	'journals',	'journal',	'Debit/Credit Indicator',	'Transaction direction',	'To indicate debit or credit',	1,	2,	1),
('Finance',	'journals',	'amount',	'Transaction Amount',	'Financial value',	'To record financial amount in journal',	1,	2,	1),
('Finance',	'customers',	'customer_id',	'Customer Identification',	'Customer record',	'To uniquely identify and reference customer',	1,	2,	1),
('Finance',	'customers',	'customer_name',	'Customer Name',	'Customer identity',	'To identify customer by name',	1,	2,	1),
('Finance',	'customers',	'contact_info',	'Customer Contact Information',	'Customer phone/contact details',	'To maintain customer contact',	1,	2,	1),
('Finance',	'customers',	'email',	'Customer Email Address',	'Customer email communication',	'To communicate with customer',	1,	2,	1),
('Finance',	'customers',	'address',	'Customer Address',	'Customer location',	'To maintain customer delivery/billing address',	1,	2,	1),
('Finance',	'vendors',	'vendor_id',	'Vendor Identification',	'Vendor record',	'To uniquely identify and reference vendor',	1,	2,	1),
('Finance',	'vendors',	'vendor_name',	'Vendor Name',	'Vendor identity',	'To identify vendor by name',	1,	2,	1),
('Finance',	'vendors',	'contact_info',	'Vendor Contact Information',	'Vendor phone/contact details',	'To maintain vendor contact',	1,	2,	1),
('Finance',	'vendors',	'email',	'Vendor Email Address',	'Vendor email communication',	'To communicate with vendor',	1,	2,	1),
('Finance',	'vendors',	'address',	'Vendor Address',	'Vendor location',	'To maintain vendor delivery address',	1,	2,	1),
('Finance',	'products',	'product_id',	'Product Identification',	'Product record',	'To uniquely identify and reference product',	1,	2,	1),
('Finance',	'products',	'product_name',	'Product Name',	'Product identity',	'To identify product by name',	1,	2,	1),
('Finance',	'products',	'description',	'Product Description',	'Product details',	'To provide product details and specifications',	1,	2,	1),
('Finance',	'products',	'product_unit',	'Product Unit of Measure',	'Product quantity unit',	'To specify product measurement unit',	1,	2,	1),
('Finance',	'operations',	'operation_id',	'Operation Identification',	'Operation record',	'To uniquely identify and reference operation',	1,	2,	1),
('Finance',	'operations',	'product_id',	'Related Product Identification',	'Product in operation',	'To link operation to product',	1,	2,	1),
('Finance',	'operations',	'quantity',	'Operation Quantity',	'Quantity in operation',	'To track operation quantity',	1,	2,	1),
('Finance',	'operations',	'product_cost',	'Product Cost',	'Product unit cost',	'To record product cost',	1,	2,	1),
('Finance',	'operations',	'product_price',	'Product Price',	'Product unit price',	'To record product selling price',	1,	2,	1),
('Finance',	'operations',	'purchase_date',	'Purchase Date',	'Date of operation',	'To record operation date',	1,	2,	1),
('Finance',	'operations',	'created_at',	'Date and Time created',	'Operation creation timestamp',	'To have recorded time when operation created',	1,	2,	1),
('Finance',	'warehouses',	'warehouse_id',	'Warehouse Identification',	'Warehouse record',	'To uniquely identify and reference warehouse',	1,	9,	1),
('Finance',	'warehouses',	'warehouse_name',	'Warehouse Name',	'Warehouse identity',	'To identify warehouse by name',	1,	9,	1),
('Finance',	'warehouses',	'location',	'Warehouse Location',	'Warehouse physical location',	'To record warehouse physical location',	1,	9,	1),
('Finance',	'account_receivables',	'receivable_id',	'Accounts Receivable Identification',	'AR record',	'To uniquely identify and reference AR transaction',	2,	2,	1),
('Finance',	'account_receivables',	'transaction_id',	'Related Transaction Identification',	'AR to transaction link',	'To link AR to transaction',	2,	2,	1),
('Finance',	'account_receivables',	'customer_id',	'Related Customer Identification',	'AR customer link',	'To link AR to customer',	2,	2,	1),
('Finance',	'ar_ext',	'ar_ext_id',	'AR Extension Identification',	'AR extension record',	'To uniquely identify and reference AR extension',	2,	2,	1),
('Finance',	'ar_ext',	'amount',	'AR Amount Due',	'Amount owed by customer',	'To record amount customer owes',	2,	2,	1),
('Finance',	'ar_ext',	'due_date',	'AR Due Date',	'Payment due date',	'To record when payment is due',	2,	2,	1),
('Finance',	'ar_ext',	'invoice_date',	'Invoice Date',	'Date invoice issued',	'To record invoice date',	2,	2,	1),
('Finance',	'ar_ext',	'status',	'AR Status',	'Payment status',	'To track payment status',	2,	2,	1),
('Finance',	'ar_ext',	'receivable_id',	'Related Receivable Identification',	'AR extension to AR link',	'To link AR extension to AR',	2,	2,	1),
('Finance',	'account_payables',	'payable_id',	'Accounts Payable Identification',	'AP record',	'To uniquely identify and reference AP transaction',	2,	3,	1),
('Finance',	'account_payables',	'transaction_id',	'Related Transaction Identification',	'AP to transaction link',	'To link AP to transaction',	2,	3,	1),
('Finance',	'account_payables',	'vendor_id',	'Related Vendor Identification',	'AP vendor link',	'To link AP to vendor',	2,	3,	1),
('Finance',	'ap_ext',	'ap_ext_id',	'AP Extension Identification',	'AP extension record',	'To uniquely identify and reference AP extension',	2,	3,	1),
('Finance',	'ap_ext',	'amount',	'AP Amount Due',	'Amount owed to vendor',	'To record amount owed to vendor',	2,	3,	1),
('Finance',	'ap_ext',	'due_date',	'AP Due Date',	'Payment due date',	'To record when payment is due',	2,	3,	1),
('Finance',	'ap_ext',	'invoice_date',	'Invoice Date',	'Date invoice received',	'To record invoice date',	2,	3,	1),
('Finance',	'ap_ext',	'status',	'AP Status',	'Payment status',	'To track payment status',	2,	3,	1),
('Finance',	'ap_ext',	'payable_id',	'Related Payable Identification',	'AP extension to AP link',	'To link AP extension to AP',	2,	3,	1),
('Finance',	'inventory_audits',	'management_id',	'Inventory Audit Identification',	'Inventory audit record',	'To uniquely identify and reference inventory audit',	1,	9,	1),
('Finance',	'inventory_audits',	'product_id',	'Related Product Identification',	'Product in audit',	'To link audit to product',	1,	9,	1),
('Finance',	'inventory_audits',	'warehouse_id',	'Related Warehouse Identification',	'Warehouse in audit',	'To link audit to warehouse',	1,	9,	1),
('Finance',	'inventory_audits',	'transaction_id',	'Related Transaction Identification',	'Audit to transaction link',	'To link audit to transaction',	1,	9,	1),
('Finance',	'inventory_audits',	'action_type',	'Inventory Action Type',	'Type of inventory action',	'To record type of inventory movement',	1,	9,	1),
('Finance',	'inventory_audits',	'quantity',	'Inventory Quantity',	'Quantity in audit',	'To record quantity affected',	1,	9,	1),
('Finance',	'inventory_audits',	'movement_date',	'Movement Date',	'Date of inventory movement',	'To record movement date',	1,	9,	1),
('Finance',	'inventory_audits',	'created_at',	'Date and Time created',	'Audit creation timestamp',	'To have recorded time when audit created',	1,	9,	1),
('Finance',	'purchase_returns',	'return_id',	'Purchase Return Identification',	'Return record',	'To uniquely identify and reference purchase return',	1,	3,	1),
('Finance',	'purchase_returns',	'payable_id',	'Related Payable Identification',	'Return to AP link',	'To link return to AP',	1,	3,	1),
('Finance',	'purchase_returns',	'return_amount',	'Return Amount',	'Amount of return',	'To record return amount',	1,	3,	1),
('Finance',	'purchase_returns',	'return_date',	'Return Date',	'Date of return',	'To record return date',	1,	3,	1),
('Finance',	'sale_returns',	'return_id',	'Sales Return Identification',	'Return record',	'To uniquely identify and reference sales return',	1,	2,	1),
('Finance',	'sale_returns',	'receivable_id',	'Related Receivable Identification',	'Return to AR link',	'To link return to AR',	1,	2,	1),
('Finance',	'sale_returns',	'return_amount',	'Return Amount',	'Amount of return',	'To record return amount',	1,	2,	1),
('Finance',	'sale_returns',	'return_date',	'Return Date',	'Date of return',	'To record return date',	1,	2,	1),
('Finance',	'inventory_transfers',	'transfer_id',	'Inventory Transfer Identification',	'Transfer record',	'To uniquely identify and reference inventory transfer',	1,	9,	1),
('Finance',	'inventory_transfers',	'from_location_id',	'Source Warehouse Identification',	'Transfer source',	'To identify source warehouse',	1,	9,	1),
('Finance',	'inventory_transfers',	'to_location_id',	'Destination Warehouse Identification',	'Transfer destination',	'To identify destination warehouse',	1,	9,	1),
('Finance',	'inventory_transfers',	'product_id',	'Related Product Identification',	'Product transferred',	'To identify product being transferred',	1,	9,	1),
('Finance',	'inventory_transfers',	'quantity',	'Transfer Quantity',	'Quantity transferred',	'To record transfer quantity',	1,	9,	1),
('Finance',	'inventory_transfers',	'transfer_date',	'Transfer Date',	'Date of transfer',	'To record transfer date',	1,	9,	1),
('Finance',	'inventory_transfers',	'notes',	'Transfer Notes',	'Additional transfer information',	'To provide transfer context',	1,	9,	1),
('Finance',	'event_log',	'event_id',	'Event Log Identification',	'Event record',	'To uniquely identify and reference event',	2,	7,	1),
('Finance',	'event_log',	'event_type',	'Event Type',	'Type of event',	'To categorize event type',	2,	7,	1),
('Finance',	'event_log',	'payload',	'Event Payload',	'Event detailed information',	'To store event details',	2,	7,	1),
('Finance',	'event_log',	'status',	'Event Status',	'Processing status of event',	'To track event processing status',	2,	7,	1),
('Finance',	'event_log',	'idempotency_key',	'Event Idempotency Key',	'Prevents duplicate events',	'To ensure event uniqueness',	2,	7,	1),
('Finance',	'event_log',	'created_at',	'Date and Time created',	'Event creation timestamp',	'To have recorded time when event created',	2,	7,	1),
('Finance',	'event_log',	'processed_at',	'Date and Time processed',	'Event processing timestamp',	'To have recorded time when event processed',	2,	7,	1),
('Finance',	'ar_product_line',	'ar_line_id',	'AR Product Line Identification',	'AR line item record',	'To uniquely identify and reference AR line item',	1,	2,	1),
('Finance',	'ar_product_line',	'invoice_id',	'Invoice Identification',	'Invoice reference',	'To link line to invoice',	1,	2,	1),
('Finance',	'ar_product_line',	'product_id',	'Related Product Identification',	'Product in line item',	'To link line item to product',	1,	2,	1),
('Finance',	'ar_product_line',	'receivable_id',	'Related Receivable Identification',	'Line to AR link',	'To link line item to AR',	1,	2,	1),
('Finance',	'ar_product_line',	'quantity',	'Line Item Quantity',	'Quantity in line item',	'To record quantity',	1,	2,	1),
('Finance',	'ar_product_line',	'discount',	'Line Item Discount',	'Discount amount',	'To record discount',	1,	2,	1),
('Finance',	'tax_types',	'tax_type_id',	'Tax Type Identification',	'Tax type record',	'To uniquely identify and reference tax type',	3,	1,	1),
('Finance',	'tax_types',	'client_id',	'Related Client Identification',	'Tax type owner',	'To link tax type to client',	3,	1,	1),
('Finance',	'tax_types',	'chart_id',	'Related Chart Identification',	'Tax type to account link',	'To link tax type to account',	3,	1,	1),
('Finance',	'tax_types',	'tax_name',	'Tax Type Name',	'Tax type identity',	'To identify tax type by name',	3,	1,	1),
('Finance',	'tax_types',	'tax_code',	'Tax Code',	'Tax code reference',	'To identify tax by code',	3,	1,	1),
('Finance',	'tax_types',	'tax_rate',	'Tax Rate',	'Tax percentage rate',	'To record tax rate percentage',	3,	1,	1),
('Finance',	'tax_types',	'is_active',	'Tax Type Active Status',	'Tax type usability',	'To track if tax type is active',	3,	1,	1);

-- 1:1 Linking (Enforced by PK)
INSERT INTO governance_v2.column_classification (catalog_id, sensitivity_id) VALUES
(1,	3),
(2,	4),
(3,	2),
(4,	2),
(5,	2),
(6,	2),
(7,	2),
(8,	2),
(9,	2),
(10,	2),
(11,	2),
(12,	2),
(13,	2),
(14,	2),
(15,	2),
(16,	2),
(17,	2),
(18,	2),
(19,	2),
(20,	2),
(21,	2),
(22,	2),
(23,	2),
(24,	2),
(25,	2),
(26,	2),
(27,	2),
(28,	2),
(29,	2),
(30,	2),
(31,	2),
(32,	3),
(33,	3),
(34,	5),
(35,	2),
(36,	2),
(37,	3),
(38,	2),
(39,	2),
(40,	3),
(41,	3),
(42,	5),
(43,	3),
(44,	5),
(45,	5),
(46,	5),
(47,	5),
(48,	3),
(49,	3),
(50,	3),
(51,	3),
(52,	3),
(53,	2),
(54,	3),
(55,	2),
(56,	2),
(57,	2),
(58,	2),
(59,	3),
(60,	5),
(61,	5),
(62,	3),
(63,	2),
(64,	2),
(65,	2),
(66,	2),
(67,	3),
(68,	2),
(69,	3),
(70,	3),
(71,	5),
(72,	3),
(73,	3),
(74,	3),
(75,	2),
(76,	3),
(77,	2),
(78,	3),
(79,	3),
(80,	5),
(81,	3),
(82,	3),
(83,	3),
(84,	2),
(85,	2),
(86,	2),
(87,	2),
(88,	2),
(89,	2),
(90,	3),
(91,	3),
(92,	2),
(93,	3),
(94,	2),
(95,	5),
(96,	3),
(97,	3),
(98,	2),
(99,	5),
(100,	3),
(101,	2),
(102,	2),
(103,	2),
(104,	2),
(105,	3),
(106,	3),
(107,	2),
(108,	2),
(109,	2),
(110,	3),
(111,	2),
(112,	5),
(113,	2),
(114,	2),
(115,	2),
(116,	3),
(117,	2),
(118,	2),
(119,	3),
(120,	3),
(121,	2),
(122,	2),
(123,	2),
(124,	2),
(125,	3),
(126,	3),
(127,	2);

-- Handling Rules (Now explicit FKs)
-- Example: Apply 'Encrypted at rest' to ALL Confidential items
INSERT INTO governance_v2.handling (rule, sensitivity_id) VALUES
('Access limited to authorized staff', 3), -- level 3 = Confidential
('Encrypted at rest', 3),
('No export to personal devices', 3),
('Audit logging on access', 3),
('Role-based access only', 4), -- level 4 = Restricted
('Encrypted at rest and in transit', 4),
('No email/IM transmission', 4),
('Retention per org policy', 4),
('Deletion on request (GDPR)', 4),
('Standard backup/retention', 2); -- level 2 = Internal

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


INSERT INTO governance_v2.access_reviews (
    reviewed_by, 
    review_period, 
    scope, 
    findings, 
    actions_taken, 
    next_review_due, 
    sign_off
) VALUES (
    'DBA_Jane', 
    '2026-Q3', 
    'Finance Domain', 
    'Developer role no longer needed; AR Staff promotion requires update.', 
    'Revoked Developer access; Updated AR Staff to Full.', 
    '2026-12-31', 
    TRUE
);

INSERT INTO governance_v2.access_review_items (
    review_id, 
    role_id, 
    domain_id, 
    decision, 
    notes
)
SELECT 
    1, -- The review_id from above
    r.role_id,
    d.domain_id,
    CASE 
        WHEN r.role_name = 'Developer' THEN 'REVOKED'
        WHEN r.role_name = 'AR Staff' THEN 'MODIFIED'
        ELSE 'APPROVED'
    END,
    CASE 
        WHEN r.role_name = 'Developer' THEN 'Role no longer exists in team.'
        WHEN r.role_name = 'AR Staff' THEN 'Promoted to Senior AR Manager.'
        ELSE 'Access remains appropriate.'
    END
FROM governance_v2.roles r
JOIN governance_v2.domains d ON d.domain_id = 1 -- Finance Domain ID
WHERE r.role_name IN ('Developer', 'AR Staff', 'Accountant');

INSERT INTO governance_v2.data_standards (standard_name, applies_to, rule_text, enforcement,    owner_id    )
VALUES
( 'valid_email', 'all emails columns', 'Followed the email format', 'Constraint',1),
( 'valid_phone', 'all phone columns', 'Followed the phone format', 'Constraint',1),
( 'quanty_type', 'quantity columns', 'quantity > 0', 'Constraint', 1),
( 'amount_type', 'amount columns', 'amount > 0', 'Constraint', 1),
( 'valid_account_code', 'acount columns', 'valid_account > 0', 'Constraint', 1),
( 'valid_chart_typing', 'charts columns', 'Value in (Asset Liability Equity Revenue Expense Contra Revenue Contra Asset Contra Liability Contra Equity Contra Expense)', 'Constraint', 1),
( 'valid_action_typing', 'status columns', 'VALUE IN (Purchase Sale Sale Return Purchase Return Transfer ) ', 'Constraint', 1),
( 'valid_status_typing', 'audit columns', 'VALUE IN (Pending Paid Overdue Returned Partially Returned Partially Paid', 'Constraint', 1),
( 'valid_audit_log_typing', 'charts columns', 'VALUE IN (INSERT UPDATE DELETE)', 'Constraint', 1),


-- Example of Explicit Deny with reason (e.g., a new contractor restricted)
-- INSERT INTO governance_v2.access_matrix (role_id, domain_id, access_level, denied_at, reason)
-- VALUES (9, 2, NULL, NOW(), 'Contractor not cleared for Operations');

COMMIT;

SELECT '05 DATA GOVERNANCE V2 - SCHEMA READY' AS STATUS;