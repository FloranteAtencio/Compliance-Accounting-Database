import psycopg2
import json
import csv
import os
import sys
import config as conf

def call_main(session_id):
    conn = psycopg2.connect(
        host=conf.SETTINGS["database"]["host"],
        database=conf.SETTINGS["database"]["database"],
        user=conf.SETTINGS["database"]["user"],
        password=conf.SETTINGS["database"]["password"],
        port=conf.SETTINGS["database"]["port"]
    )


    cur = conn.cursor()
    cur.execute("SET LOCAL app.import_source_file = 'data.csv'")

    try:
        print(f"🦽 Pending Posting Start!")
        try:        
            cur.execute(" CALL staging.import_workflow_posting(%s)",
                    (session_id,)
                    )
            conn.commit()
            print(f"🎉 Posting Complete !")
        except Exception as inner_e:
            print(f"⚠️ Posting procedure fail : {inner_e}")
                
    except Exception as e:
        err_message = str(e)
        print(f"⚠️  Posting script Failed : {err_message}")

    finally:

        if cur:
            cur.close()
        if conn:
            conn.close()
        print(" 🔒 Connections Closed")