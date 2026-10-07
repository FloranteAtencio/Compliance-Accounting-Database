import psycopg2
import json
import csv
import os
import sys
import config as conf

def call_main(client_id):
    conn = psycopg2.connect(
        host=conf.SETTINGS["database"]["host"],
        database=conf.SETTINGS["database"]["database"],
        user=conf.SETTINGS["database"]["user"],
        password=conf.SETTINGS["database"]["password"],
        port=conf.SETTINGS["database"]["port"]
    )

    query_insert = """
            INSERT INTO audit.worm_approvals (
            table_name, 
            reason, 
            approver, 
            requested_by, 
            expires_at
            ) VALUES (
            'audit.import_sessions', 
            'Automated import update', 
            'SYSTEM_AUTOMATION',  -- The approver name
            'importandsanitation.py',     -- Who requested it
            now() + interval '1 hour' -- Valid for 1 hour
            );                
    """
    #--stg_table = 'stg_ar_imports'
    cur = conn.cursor()

    print("🚀 Starting Import Session...")
    try:
        cur.execute(
            "SELECT Audit.start_import_session(%s, %s, %s, %s)", 
            (1, 'invoices', 'admin_user', 'data.csv')
        )
        session_id = cur.fetchone()[0]
        print(f"✅ Session ID: {session_id}")

        cur.execute(f"SET LOCAL app.current_client_id ={client_id}")
        cur.execute("SET app.worm_override = 'true';")
        cur.execute("SET app.worm_approver = 'SYSTEM_AUTOMATION';")
        cur.execute(f"SET LOCAL app.import_session_id = {session_id}")
        cur.execute(F"SET LOCAL app.import_source_file = '{conf.SETTINGS["data"]["path"]}'")


    except Exception as e:
        print(f"❌ Failed to start session: {e}")
        conn.close()
        sys.exit(1)


    try:
        with open(conf.SETTINGS["data"]["path"], 'r', newline='', encoding='utf-8') as f:
            reader = csv.DictReader(f)     
            for i, row in enumerate(reader, start=1):
                staging_id = None  # Initialize before try block
                try:               
                    query = """
                        SELECT Staging.ar_import_data(%s, %s, %s, %s, %s, %s, %s)
                        """
                    values = (
                        session_id,
                        row.get('client_code'),   # Use .get() to avoid KeyError if missing
                        row.get('customer_code'),
                        row.get('invoice_date'),
                        row.get('due_date'),
                        row.get('amount'),
                        row.get('status') 
                    )

                    cur.execute(query, values) 
                    result = cur.fetchone()
                
                    if result and result[0] is not None:
                        staging_id = result[0]
                    else:
                        # Function returned NULL or no result
                        raise Exception("Stored procedure did not return a valid ID")
                    
                    # Log success (Optional: Only log if you have a separate workflow table)
                    # If Staging.ar_import_data handles workflow logging internally, you can skip this.
                    # cur.execute("SET app.worm_override = 'true';")
                    # cur.execute("SET app.worm_approver = 'SYSTEM_AUTOMATION';")
                    cur.execute(query_insert)       
                    cur.execute(
                        "SELECT Audit.log_import_record(%s, %s, %s, %s, %s, %s, %s)",
                        (session_id, i, 'stg_ar_imports', json.dumps(row), 'SUCCESS', None, staging_id)
                    )

                except Exception as e:
                    error_msg = str(e)
                    # Log failure - Ensure log_import_record accepts NULL for staging_id
                    # cur.execute("SET app.worm_override = 'true';")
                    # cur.execute("SET app.worm_approver = 'SYSTEM_AUTOMATION';")
                    cur.execute(query_insert)
                    cur.execute(
                        "SELECT Audit.log_import_record(%s, %s, %s, %s, %s, %s, %s)",
                        (session_id, i, 'stg_ar_imports', json.dumps(row), 'FAILED', error_msg, staging_id)
                    )

        try:
            cur.execute("CALL Staging.import_workflow_sanitation(%s)", (session_id,))
            conn.commit()
        except Exception as e:
            print(f"Error: {e}")
            
        # 5. COMPLETE SESSION
        print("✅ Import Loop Finished. Finalizing...")
        final_status = 'SUCCESS' 

        cur.execute(query_insert)    
        cur.execute(
            "SELECT Audit.complete_import_session(%s, %s, %s)",
            (session_id, final_status, 'Import completed successfully.')
        )
        
        conn.commit()
        print(f"🎉 Import Complete! Session {session_id} marked as {final_status}.")



    except Exception as e:
        # CRASH HANDLING
        print(f"💥 CRITICAL ERROR: {e}")
        try:
            
            cur.execute(query_insert)
            cur.execute(
                "SELECT Audit.complete_import_session(%s, %s, %s)",
                (session_id, 'FAILED', f'Script crashed: {str(e)}')
            )
            conn.rollback()  # Rollback the failed transaction
            # NO commit() here! The transaction is dead.
            print("⚠️ Session marked as FAILED and rolled back.")
        except Exception as inner_e:
            print(f"❌ Failed to mark session as FAILED: {inner_e}")
        finally:
            pass # Just close in the finally block

    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()
        print(" 🔒 Connections Closed")

    return session_id
