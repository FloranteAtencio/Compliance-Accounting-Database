ALTER TABLE Finance.clients 
ADD COLUMN tax_id VARCHAR(50),
ADD COLUMN email VARCHAR(255) NOT NULL,
ADD COLUMN country_iso CHAR(2) NOT NULL DEFAULT 'US',
ADD COLUMN base_currency CHAR(3) NOT NULL DEFAULT 'USD',
ADD COLUMN engagement_manager VARCHAR(100);

-- Enforce uniqueness on Business Key (Tax ID + Country)
CREATE UNIQUE INDEX idx_client_tax_country ON Finance.clients(tax_id, country_iso) WHERE tax_id IS NOT NULL;

ALTER TABLE Finance.journals 
ADD COLUMN currency_code CHAR(3) NOT NULL DEFAULT 'USD',
ADD COLUMN fx_rate NUMERIC(12,6) NOT NULL DEFAULT 1.0,
ADD COLUMN amount_base DECIMAL(15,2) GENERATED ALWAYS AS (ROUND(amount * fx_rate, 2)) STORED,
ADD COLUMN project_id INT REFERENCES Finance.service_engagements(project_id);

-- Index for fast reporting by Project/Currency
CREATE INDEX idx_journal_project_currency ON Finance.journals(project_id, currency_code);