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

    print(f"🦽 Rejecting Start!")
        
    try:
        try:        
            cur.execute(" CALL Staging.import_workflow_reject(%s)",
                    (session_id,)
                    )
            conn.commit()
            print(f"🎉 Pending Rejecting Complete !")

        except Exception as inner_e:
            print(f"⚠️ Rejecting Procedure Fail : {inner_e}")
                
    except Exception as e:
        err_message = str(e)
        print(f"⚠️ Rejecting Script Failed : {err_message}")

    finally:

        if cur:
            cur.close()
        if conn:
            conn.close()
        print(" 🔒 Connections Closed")

# import psycopg2
# import json
# import csv
# import os
# import sys
# conn = psycopg2.connect(
#     host = "localhost",
#        database = "erp_db",
#        user = "admin_user",
#        password = "change_me_in_production",
#        port=5432
# )

# session_id = 1

# cur = conn.cursor()

# print(f"🦽 Rejecting Start!")
    
# try:
#     try:        
#         cur.execute(" CALL Staging.import_workflow_reject(%s)",
#                 (session_id,)
#                 )
#         conn.commit()
#         print(f"🎉 Pending Rejecting Complete !")

#     except Exception as inner_e:
#         print(f"⚠️ Rejecting Procedure Fail : {inner_e}")
            
# except Exception as e:
#     err_message = str(e)
#     print(f"⚠️ Rejecting Script Failed : {err_message}")

# finally:

#     if cur:
#         cur.close()
#     if conn:
#         conn.close()
#     print(" 🔒 Connections Closed")