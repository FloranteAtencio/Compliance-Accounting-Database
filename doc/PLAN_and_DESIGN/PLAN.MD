# 🧠 Accounting Database System (PostgreSQL)

A modular **Accounting database system** designed to handle Account Receivables , and financial transactions and more using PostgreSQL.

---

## 🚀 Features


* 💰 **Accounting System**

  * Double-entry bookkeeping (Debit/Credit)
  * Automatic journal entry generation

* 🧾 **Accounts Receivable**

  * Tracks customer balances and supplier obligations
  * Supports payment status and due dates

* 🥞 **Multitenant client and Chart of Account**

  * Multiple Clients can simultaneously operate 
  * Multiple Chart of account custom made for every Clients needs

* ⚙️ **Stored Procedures (PL/pgSQL)**

  * Centralized transaction processing
  * Modular design (Inventory + Accounting modules)

* 🧩 **Partitioned Tables**

  * Scalable handling of financial data using date-based partitioning

* 📊 **Reporting & Dashboard Queries**

  * Revenue and profit
  * Aging reports (AR/AP)

* 🫆 **Audit Logs / Extended Audit Logs**

  * Audit Hash Code Chain
  * Automatic Recording Every Transaction
  * Summary Import Logs

* 📋 **Audit Trail**
 
  * Transaction Life Cycle
  * Import Session

* 📝 **Compliance and Metadata**
  
  * Compliance log
  * import compliance log
  * policies for each table and column

* 🗂 **Staging**
  
   * Data Testing
   * Sanitation
   * Validation
   * Approval
    
* 🛡️ **Trigger Guard**

   * Prevent direct operation to table
   * Need specific setting to perform CRUD Operations

* 🔄 **Data Life cycle metadata**
    * History of entire data cycle  

* 📁 **Data  Governance**
    * regulation, authority, rules, confidentiality of data.
---

## 🏗️ System Architecture

```

[CSV/ API/ SPREAD_SHEET_IMPORT]
   
   
    ↓ ---------------> [log the import details in summary and every succes/fail transaction]


[Staging] ----------------> [log to import workflows status]
   

    ↓ ---------------> [update the import workflow status]


[Sanitation] ----------------> [Record Lineage] 
   

    ↓ ----------------> [update the import workflow status]


[Validations] ----------------> [Record Lineage]
   

    ↓ ----------------> [update the workflow status]


[Approval Chain] ----------------> [Record Lineage]


    ↓ ----------------> [update the workflow status]


[Posting] ----------------> [Record Lineage]
   
   
    ↓ ----------------> [update the workflow status and import workflow end here]


    ↓ ----------------> [Trigger guard work on this part to prevent by passing or cut the process]


[ AR / AP / Inventory Transactions and so on] ----------------> [Record Lineage, Audit Log, and transaction lifecycle] 
      

    ↓ ----------------> [Trigger guard work on this part to prevent by passing or cut the process]


[Journals] -> [Audit Log/ update transaction life cycle]    


    ↓ ----------------> [Trigger guard work on this part to prevent by passing or cut the process]


[Accounting Module/Inventory Module] ----------------> [Audit Log]


    ↓ ----------------> [Trigger guard work on this part to prevent by passing or cut the process]


[Validations at core production] ----------------> [Record Lineage]


    ↓ ----------------> [update the transaction life cycle status]


[Approval Chain at core production ] ----------------> [Record Lineage]


    ↓ ----------------> [update the transaction life cycle status]


[Transaction business/reports/reconcile]


    ↓


[Archive( 12 months)]

## 🧠 Key Demonstrated

* Relational Database Design (Normalization, Constraints)
* Partitioning Strategy (Range Partitioning by Date)
* Composite Keys in Partitioned Tables
* Foreign Key Integrity across modules
* Financial Data Modeling (ERP-style logic)
* Query Optimization using Indexes
* Modular Stored Procedure Design
* Audit Logs and Trails for Every success Operations
* Recording Data Lineage (From Staging to Production)
* Idempotency key for avoid duplicate transactions
* Code Hashing Chain to spot tampering
* Sanitation, Validation and Approval Chain at Staging 
* Trigger Guard Prevent bypassing validation and ensures every transaction follow the approved workflow
* Write Only Read Many 
* Data Complinace logs and metdata for each table and rows (rentention, encryption, pii_present, finance_data, data_steward, gpdr, ph_data_privacy)
* Data Governance set regulation on each data (handle, role, owners, custodians, domain, classification and sensitivity)
* Data Lifecycle (ingestion, staging, process, archive, retension, deletions, data lineage)

---

## 💼 Business Value

This system simulates a real Accounting backend where:

* Sales generate accounts receivable
* Financial reports can be derived from journal entries
* Record Data Lineage From Staging to Production to Archive
* Multiple Tenant and custom made Chart of Account
* Logs like Import, Audit, and Compliance
* Security (Idempotency key, Hash Chain, and Trigger Guard)
* Staging area (Sanitation, Validations and Approval)
* Transaction Lifecycle status tracking
  
---