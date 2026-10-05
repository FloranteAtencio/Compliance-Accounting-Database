-- PERFORM Finance.transaction_lifecycle_approval(1,1,'Bookkeeper','Leonardo','Pending',NULL,NULL,NULL);

-- PERFORM Finance.transaction_lifecycle_approval(1,2,'Accountant','Donatello','Pending',NULL,NULL,NULL);

-- PERFORM Finance.transaction_lifecycle_approval(1,3,'Manager','Raphaelo','Pending',NULL,NULL,NULL);

CREATE OR REPLACE PROCEDURE Finance.transaction_lifecycle_approval_ARCHIVED(
    IN p_client_id INT
    ,IN p_transaction_id INT
    -- ,IN p_approval_level INT -- 1=Bookkeeper, 2=Supervisor, 3=Manager, etc.
    -- ,IN p_approver_role VARCHAR -- NOT NULL
    -- ,IN p_approver_name VARCHAR
    -- ,IN p_status VARCHAR -- 'PENDING', 'APPROVED', 'REJECTED'
    -- ,IN p_approval_comment TEXT
    -- ,IN p_approved_at TIMESTAMP
    -- ,IN p_required_at TIMESTAMP
)
LANGUAGE plpgsql as $$
DECLARE
    new_client_id INT;
BEGIN

    SELECT client_id  INTO new_client_id
    FROM Finance.clients a
    WHERE a.client_id = p_client_id
    LIMIT 1;

    IF new_client_id IS NULL THEN
        RAISE EXCEPTION 'Please Check client_id provided!';
    END IF;

    PERFORM 1 FROM Finance.clients a where a.client_id = p_client_id;

    UPDATE Finance.transaction_lifecycle
    SET
        previous_state = 'POSTED'
        ,new_state = 'ARCHIVED'
    WHERE client_id = p_client_id 
    AND new_state = 'POSTED'
    AND transaction_id = p_transaction_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Finance.transaction_lifecycle_approval: %', SQLERRM;
END;
$$ SECURITY DEFINER SET search_path = Finance, Audit, Compliance, Security, Staging, pg_catalog;

CREATE OR REPLACE PROCEDURE Finance.transaction_lifecycle_approval_DELETION(
    IN p_client_id INT
    ,IN p_transaction_id INT
    -- ,IN p_approval_level INT -- 1=Bookkeeper, 2=Supervisor, 3=Manager, etc.
    -- ,IN p_approver_role VARCHAR -- NOT NULL
    -- ,IN p_approver_name VARCHAR
    -- ,IN p_status VARCHAR -- 'PENDING', 'APPROVED', 'REJECTED'
    -- ,IN p_approval_comment TEXT
    -- ,IN p_approved_at TIMESTAMP
    -- ,IN p_required_at TIMESTAMP
)
LANGUAGE plpgsql as $$
DECLARE
    new_client_id INT;
    new_client_id INT;
BEGIN

    SELECT client_id  INTO new_client_id
    FROM Finance.clients a
    WHERE a.client_id = p_client_id
    LIMIT 1;

    SELECT transaction_id INTO new_transaction_id
    FROM Finance.transactions a
    WHERE a.transaction_id = p_transaction_id
    LIMIT 1;

    IF new_client_id IS NULL THEN
        RAISE EXCEPTION 'Please Check client_id provided!';
    END IF;

    IF new_transaction_id IS NULL THEN
        RAISE EXCEPTION 'Please Check transaction_id provided!';
    END IF;

    PERFORM 1 FROM Finance.clients a where a.client_id = p_client_id;

    PERFORM 1 FROM Finance.Transaction a where a.transaction_id = p_transaction_id;

    UPDATE Finance.transaction_lifecycle
    SET
        previous_state = 'ARCHIVED'
        ,new_state = 'DELETION'
    WHERE client_id = p_client_id 
    AND new_state = 'ARCHIVED'
    AND transaction_id = p_transaction_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Finance.transaction_lifecycle_approval: %', SQLERRM;
END;
$$ SECURITY DEFINER SET search_path = Finance, Audit, Compliance, Security, Staging, pg_catalog;
