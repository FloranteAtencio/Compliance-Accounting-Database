import Importandsanitation as IS
import validation as val
import Approval_l1 as l1
import Approval_l2 as l2
import Approval_l3 as l3
import Posting as post
try:
        
    client_id = 1
    session_id= IS.call_main(client_id)
    val.call_main(session_id,client_id)
    l1.call_main(session_id)
    l2.call_main(session_id)
    l3.call_main(session_id)
    post.call_main(session_id)
    
except Exception as e:
    print(f"ERROR {e}")