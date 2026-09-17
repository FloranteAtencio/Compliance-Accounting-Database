CREATE OR REPLACE PROCEDURE Finance.transaction_lifecycle_approval(
    IN p_client_id INT
    ,IN p_approval_level INT -- 1=Bookkeeper, 2=Supervisor, 3=Manager, etc.
    ,IN p_approver_role VARCHAR -- NOT NULL
    ,IN p_approver_name VARCHAR
    ,IN p_status VARCHAR -- 'PENDING', 'APPROVED', 'REJECTED'
    ,IN p_approval_comment TEXT
    ,IN p_approved_at TIMESTAMP
    ,IN p_required_at TIMESTAMP
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

    INSERT INTO Audit.approval_chain (
        transaction_id
        ,client_id
        ,approval_level
        ,approver_role
        ,approver_name
        ,status
        ,approval_comment
        ,approved_at
        ,required_at
        )
    SELECT
        a.transaction_id
        ,new_client_id
        ,p_approval_level-- 1=Bookkeeper, 2=Supervisor, 3=Manager, etc.
        ,p_approver_role -- NOT NULL
        ,p_approver_name
        ,p_status -- 'PENDING', 'APPROVED', 'REJECTED'
        ,p_approval_comment
        ,p_approved_at
        ,p_required_at
    FROM transaction_lifecycle a
    WHERE a.client_id = p_client_id
    AND a.new_state = 'VALIDATED';

    -- UPDATE Audit.transaction_lifecycle
    -- SET new_state = 'APPROVED'
    --     ,previous_state = 'VALIDATED'
    -- WHERE client_id = new_client_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Finance.transaction_lifecycle_approval: %', SQLERRM;
END;
$$ SECURITY DEFINER SET search_path = Finance, Audit, Compliance, Security, Staging, pg_catalog;

-- PERFORM Finance.transaction_lifecycle_approval(1,1,'Bookkeeper','Leonardo','Pending',NULL,NULL,NULL);

-- PERFORM Finance.transaction_lifecycle_approval(1,2,'Accountant','Donatello','Pending',NULL,NULL,NULL);

-- PERFORM Finance.transaction_lifecycle_approval(1,3,'Manager','Raphaelo','Pending',NULL,NULL,NULL);

CREATE OR REPLACE PROCEDURE Finance.transaction_lifecycle_approval_status(
    IN p_client_id INT
    ,IN p_approval_level INT -- 1=Bookkeeper, 2=Supervisor, 3=Manager, etc.
    ,IN p_approver_role VARCHAR -- NOT NULL
    ,IN p_approver_name VARCHAR
    ,IN p_status VARCHAR -- 'PENDING', 'APPROVED', 'REJECTED'
    ,IN p_approval_comment TEXT
    ,IN p_approved_at TIMESTAMP
    ,IN p_required_at TIMESTAMP
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



EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Finance.transaction_lifecycle_approval: %', SQLERRM;
END;
$$ SECURITY DEFINER SET search_path = Finance, Audit, Compliance, Security, Staging, pg_catalog;
