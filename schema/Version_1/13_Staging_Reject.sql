BEGIN;

CREATE OR REPLACE  PROCEDURE Staging.import_workflow_reject(
    IN p_session_id INT
)
LANGUAGE plpgsql AS $$
DECLARE
    new_session_id INT;
BEGIN

    SELECT a.session_id INTO new_session_id
    FROM Audit.import_sessions a
    WHERE a.session_id = p_session_id
    LIMIT 1;

    IF new_session_id IS NULL THEN 
        RAISE EXCEPTION 'Session ID not valid';
    END IF;

    PERFORM 1 FROM Audit.import_sessions WHERE session_id = p_session_id;

    UPDATE Audit.import_workflows a
    SET
        new_state = 'REJECT',
        previous_state = 'DRAFT'
    WHERE a.session_id = new_session_id AND (a.new_state = 'DRAFT' AND a.previous_state IS NULL) OR (  a.new_state = 'PENDING' AND a.previous_state = 'DRAFT');

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Staging import workflows Rejection Failed % ', SQLERRM;
END;
$$ SECURITY DEFINER SET search_path = Finance, Audit, Compliance, Security, Staging, pg_catalog;


COMMIT;

SELECT '13 Staging Schema import data reject complete' as Status;
