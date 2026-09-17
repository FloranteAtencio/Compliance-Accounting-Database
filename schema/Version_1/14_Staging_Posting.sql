BEGIN;

CREATE OR REPLACE PROCEDURE Staging.post_ar_import( IN p_session_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
    new_previous_state VARCHAR(50);
    new_previous_hash VARCHAR(50);
BEGIN    

    SET LOCAL app.allow_direct_insert = 'true';
    
    FOR r IN
        SELECT a.*
        FROM Staging.stg_ar_imports a
        LEFT JOIN Audit.import_workflows b ON a.id = b.staging_record_id 
        WHERE a.session_id = p_session_id
          AND validation_status = 'VALID'
          AND b.new_state = 'APPROVE_L3'
    LOOP
        
        CALL Finance.ar_transaction(
            r.client_code::INT,
            r.customer_code::INT,
            r.due_date::DATE,
            r.invoice_date::DATE,
            r.amount::DECIMAL,
            r.status::VARCHAR,
            gen_random_uuid()::TEXT
        );
    
        SELECT row_hash
        INTO new_previous_hash
        FROM Audit.record_lineage
        ORDER BY lineage_id DESC
        LIMIT 1
        FOR UPDATE;
        
        INSERT INTO Audit.record_lineage (
            table_name, 
            record_id, 
            client_id, 
            source_type, 
            source_file, 
            import_session_id, 
            created_by,
            prev_hash, 
            row_hash
        ) VALUES (
            'stg_ar_import', 
            r.id, 
            r.client_code::INT, 
            'SPREADSHEET_IMPORT',
            current_setting('app.import_source_file', TRUE),
            p_session_id::INT,
            current_user,
            new_previous_hash,
            md5(
                COALESCE(new_previous_hash,'')
                || p_session_id
                || 'stg_ar_import'
                || 'SPREADSHEET_IMPORT'
                || r.id
                || current_user
            )
        );

    END LOOP;
        
    -- IF current_setting('app.import_session_id', TRUE) IS NOT NULL THEN


    UPDATE Audit.import_workflows
    SET new_state = 'POSTED',
        previous_state = 'APPROVE_L3'
    WHERE session_id = p_session_id AND new_state = 'APPROVE_L3';

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Staging post_ar_import failed : % ', SQLERRM;

END;
$$ SECURITY DEFINER SET search_path = Finance, Audit, Compliance, Security, Staging, pg_catalog;


CREATE OR REPLACE PROCEDURE Staging.import_workflow_posting(
    IN p_session_id INT
)
LANGUAGE plpgsql AS $$
DECLARE
    new_session_id INT;
    table_related VARCHAR;
BEGIN
    
    SELECT session_id INTO new_session_id
    FROM Audit.import_sessions a
    WHERE a.session_id = p_session_id
    LIMIT 1;
    
    SELECT Staging.table_verification(new_session_id) INTO table_related;

    IF new_session_id IS NULL THEN
        RAISE EXCEPTION 'invalid Session ID : %', new_session_id;
    END IF;

    IF table_related IS NULL THEN   
        RAISE EXCEPTION 'Invalid table referecne : %',table_related;
    END IF;

    PERFORM 1 FROM Audit.import_sessions WHERE session_id = p_session_id;

    IF table_related = 'Staging.stg_ar_imports' THEN
        CALL Staging.post_ar_import(new_session_id);
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Staging.import_workflow_posting failed : % ', SQLERRM;

END;
$$ SECURITY DEFINER SET search_path = Finance, Audit, Compliance, Security, Staging, pg_catalog;


COMMIT;

SELECT '14 Staging Schema import data posting complete' as Status;
