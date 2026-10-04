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

    print(f"🦽 Pending Approval Level 1 Start!")
        
    try:
        try:        
            cur.execute(" CALL staging.import_workflow_approval_l1(%s,%s)",
                    (session_id,'Bookkeeper')
                    )
            conn.commit()
            print(f"🎉 Pending Approval Level 1 Complete !")

        except Exception as inner_e:
            print(f"⚠️ Approval Level 1 Procedure Fail : {inner_e}")
                
    except Exception as e:
        err_message = str(e)
        print(f"⚠️ Approval Level 1 Script Failed : {err_message}")

    finally:

        if cur:
            cur.close()
        if conn:
            conn.close()
        print(" 🔒 Connections Closed")