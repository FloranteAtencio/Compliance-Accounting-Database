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
session_id = 1

conn = psycopg2.connect(
    host="localhost",
    database=db_name, 
    user=db_user, 
    password=db_password, 
    port=5432
)

cur = conn.cursor()
try:
    print(f"🦽 Pending Validations Start!")
    try:        
        cur.execute(" CALL staging.import_workflow_approval_l2(%s,%s)",
                (session_id,'Accountant')
                )
        conn.commit()
        print(f"🎉 Validation Complete !")
    except Exception as inner_e:
        print(f"⚠️  procedure fail : {inner_e}")
            
except Exception as e:
    err_message = str(e)
    print(f"⚠️  Failed : {err_message}")

finally:

    print(f"🎉 Import Complete! Validations {session_id} ")

    if cur:
        cur.close()
    if conn:
        conn.close()
    print(" 🔒 Connections Closed")