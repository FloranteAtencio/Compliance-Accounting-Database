SELECT 'Staging table schema start!' as  Status;

BEGIN;

-- 1. STAGING TABLE
CREATE TABLE IF NOT EXISTS Staging.stg_ar_imports(
    id BIGSERIAL PRIMARY KEY,
    session_id INT,
    -- ID
    invoice_code TEXT,
    customer_code TEXT,
    client_code TEXT,
    
    -- measure
    amount TEXT,
    
    -- meta data
    invoice_date TEXT,
    due_date TEXT,
    status TEXT,
    validation_status VARCHAR(20),
    validation_errors TEXT,
    imported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS Staging.stg_ar_lines(
    id BIGSERIAL PRIMARY KEY,
    session_id INT,
    -- ID
    invoice_code TEXT,
    product_code TEXT,
    -- Measure
    quantity TEXT,
    discount TEXT,
    -- meta data
    validation_status VARCHAR(20),
    validation_errors TEXT,
    imported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    
);


COMMIT;

SELECT '08 Staging table schema complete!' as  Status;