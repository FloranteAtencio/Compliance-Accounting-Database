import psycopg2
import json
import csv
import os
import sys

from dotenv import load_dotenv
load_dotenv (dotenv_path='.env.prod')

db_password=os.getenv('POSTGRES_PASSWORD')
db_name = os.getenv('POSTGRES_DB')
db_user = os.getenv('POSTGRES_USER')
# 1. SETUP CONNECTION (SECURE)
# stg_table = 'stg_ar_imports'
  client_code = 1
  source_file = 'data.csv'

# 🛡️ CRITICAL: Use Environment Variables for credentials
# Run this in your terminal before running the script:
# export DB_PASSWORD="p2r0o2d6uction!"
# db_password = os.getenv("DB_PASSWORD")
# if not db_password:
#     print("❌ ERROR: DB_PASSWORD environment variable not set.")
#     sys.exit(1)

conn = psycopg2.connect(
    host="localhost",
    database=db_name, 
    user=db_user, 
    password=db_password, 
    port=5432
)
cur = conn.cursor()
  
# Validate table name (prevent SQL injection)
if not stg_table.replace('.', '').replace('_', '').isalnum():
    raise ValueError("Invalid table name")
  
# 2. START SESSION
print("🚀 Starting Import Session...")
try:
    cur.execute(
        "SELECT Audit.start_import_session(%s, %s, %s, %s)", 
        (client_code, 'invoices', 'admin_user', 'data.csv')
    )
    session_id = cur.fetchone()[0]
    print(f"✅ Session ID: {session_id}")
    
    cur.execute(f"SET LOCAL app.import_session_id = {session_id}")
    cur.execute(f"SET LOCAL app.import_source_file = {source_file}")

except Exception as e:
    print(f"❌ Failed to start session: {e}")
    conn.close()
    sys.exit(1)

# 3. PROCESS CSV
try:
    with open('data.csv', 'r', newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        
        for i, row in enumerate(reader, start=1):
            staging_id = None  # Initialize before try block
            try:
                # --- INSERT INTO STAGING VIA FUNCTION ---
                # Assuming Staging.ar_import_data returns the new ID
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
                cur.execute(
                    "SELECT Audit.log_import_record(%s, %s, %s, %s, %s, %s, %s)",
                    (session_id, i, 'stg_ar_imports', json.dumps(row), 'SUCCESS', None, staging_id)
                )

            except Exception as e:
                error_msg = str(e)
                # Log failure - Ensure log_import_record accepts NULL for staging_id
                cur.execute(
                    "SELECT Audit.log_import_record(%s, %s, %s, %s, %s, %s, %s)",
                    (session_id, i, 'stg_ar_imports', json.dumps(row), 'FAILED', error_msg, staging_id)
                )
                print(f"⚠️ Row {i} failed: {error_msg}")

    # 4. SANITATION (Uncomment if needed)
    # If Staging.ar_import_data does NOT validate, run this:
    
    # print("🔍 Validating data...")
    try:
        cur.execute("CALL Staging.import_workflow_sanitation(%s)", (session_id,))
        conn.commit()
    except Exception as e:
        print(f"Error: {e}")
    # 5. COMPLETE SESSION
    print("✅ Import Loop Finished. Finalizing...")
    final_status = 'SUCCESS' 
    
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
    print("🔌 Connection closed.")