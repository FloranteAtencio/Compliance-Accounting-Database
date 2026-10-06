DROP TABLE IF EXISTS Finance.service_engagements CASCADE;
CREATE TABLE Finance.service_engagements (
    project_id SERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES Finance.clients(client_id),
    project_code VARCHAR(30) UNIQUE NOT NULL, -- e.g., PRJ-2025-001
    service_line VARCHAR(30) NOT NULL CHECK (service_line IN ('FP&A','Treasury','Core_GL','AR_AP_Optimization')),
    scope_desc TEXT,
    start_date DATE NOT NULL,
    end_date DATE,
    billing_type VARCHAR(20) CHECK (billing_type IN ('Retainer','Hourly','Fixed')),
    status VARCHAR(20) DEFAULT 'Active'
);