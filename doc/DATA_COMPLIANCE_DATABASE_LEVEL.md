Yes. And this is an important boundary to establish, because as a database developer you do not need to become a lawyer, privacy officer, or full-time compliance auditor.

Your goal is to understand compliance deeply enough to design, build, operate, and provide evidence for compliant data systems.

Think of your scope like this:

You own the database/data-system side of compliance, but you don't own the entire organization's legal compliance program.

Your scope

I would divide your learning into 5 layers:

Level	What you need to know	Your depth
1. Data	What data exists, sensitivity, classification	Deep
2. Privacy	Why data is collected/used/shared	Working knowledge
3. Security	How data is protected technically	Deep
4. Governance	Ownership, lifecycle, retention, access, evidence	Working → strong
5. Legal/Compliance	Laws, regulations, contracts, obligations	Awareness → working knowledge

The mistake would be going all the way into Level 5 and trying to become a privacy lawyer.

Where you should START

Given your database background, I would actually start here:

1. Data Inventory

You need to be able to answer:

What data do we have?

For example:

Customer
 ├── customer_id
 ├── name
 ├── email
 ├── phone
 ├── address
 ├── tax_id
 └── credit_limit

Then ask:

Is it personal data?
Is it confidential?
How sensitive is it?
Why do we have it?
Who owns it?
Who can access it?
Where is it stored?
How long should we keep it?

This is where your database knowledge becomes extremely valuable.

2. Data Mapping

Then learn:

Where does the data go?

For your accounting system, for example:

Customer
   ↓
Web/Application
   ↓
Staging
   ↓
PostgreSQL
   ↓
Accounting System
   ↓
Data Warehouse
   ↓
Power BI
   ↓
External Accountant
   ↓
Backup

Now you can start seeing compliance problems.

For example:

Customer Tax ID
       ↓
PostgreSQL       ✓
       ↓
Power BI         ?
       ↓
External Accountant ?
       ↓
CSV Export       ???
       ↓
Backup           ???

Your job becomes:

"Where is this sensitive data going, and is every destination justified and controlled?"

That's a very valuable database/data-engineering mindset.

3. Data Lifecycle

You've already started this.

You should understand:

Collection
    ↓
Ingestion
    ↓
Validation
    ↓
Storage
    ↓
Processing
    ↓
Sharing
    ↓
Retention
    ↓
Archive / Disposal

And importantly:

Copies exist everywhere.

For example:

Production DB
     │
     ├── Backup
     ├── CSV export
     ├── Data warehouse
     ├── Power BI dataset
     ├── Audit log
     ├── Application cache
     └── Developer copy

That last part is where database developers often discover that compliance is much bigger than:

"I encrypted my database."

4. Privacy Principles

You don't need to memorize every law yet.

Learn the common principles first:

Data minimization
Purpose limitation
Accuracy
Transparency
Access rights
Correction
Retention limitation
Appropriate security
Accountability

You should be able to look at a database column and ask:

Why are we storing this?

That's more important initially than memorizing dozens of legal provisions.

5. Technical Security Controls

This is where I want you to go deep, because this is your natural territory.

You should understand:

Identity & access
Authentication
       ↓
Authorization
       ↓
RBAC
       ↓
Least privilege
       ↓
Row/column restrictions

PostgreSQL examples:

Roles
Grants
RBAC
Row-Level Security
Views
Column privileges
Separation of duties
Data protection

Understand:

Encryption at rest
Encryption in transit
Hashing
Tokenization
Masking
Pseudonymization
Key management

And know the difference.

For example:

Password
   ↓
Hashing

Bank account
   ↓
Encryption / tokenization / masking

HTTPS
   ↓
Encryption in transit
6. Auditability & Evidence

This one is very important for you.

You've already been building audit logging, and now you can see why it matters.

Compliance isn't merely:

"We have a policy."

It's:

"Show me evidence that the control actually operates."

For example:

Requirement
     ↓
Control
     ↓
Implementation
     ↓
Evidence

Example:

Requirement:
Only authorized accounting staff can access payroll.

        ↓

Control:
RBAC

        ↓

Implementation:
finance_role
payroll_role
GRANT / REVOKE

        ↓

Evidence:
Role configuration
Access logs
Audit logs
Access reviews

This is where your database auditing experience becomes particularly useful.

7. Risk Management

You don't need to become a risk manager, but you need to understand the basic thinking.

Instead of:

"We have a customer table."

Think:

"What could go wrong?"

For example:

Asset:
Customer Tax ID

Threat:
Unauthorized access

Vulnerability:
Too many users have SELECT permission

Impact:
Privacy breach / financial harm

Control:
Least privilege + masking + auditing

Evidence:
Permission review + access logs

That is compliance thinking.

Where should you STOP?

This is the important part.

You should not initially go deep into:

❌ Becoming a lawyer

You don't need to interpret every clause of every country's privacy legislation.

You should know enough to recognize:

"This requirement affects my database."

Then work with the appropriate legal/privacy/compliance person.

❌ Becoming a Chief Privacy Officer

You don't need to own the organization's entire privacy program.

You should understand what the privacy team needs from your systems.

❌ Becoming a full compliance auditor

You should understand:

controls
evidence
audit trails
testing
remediation

But you don't necessarily need to specialize in conducting enterprise-wide audits.

❌ Memorizing every regulation

Don't try to memorize:

GDPR Article 6
RA 10173 Section XX
Privacy Act APP X
NZ IPP X
CCPA Section X
...

Instead learn the concept first.

Then when a project requires a particular jurisdiction:

"Okay, which specific requirements apply here?"

That's when you study the law.

So your ideal boundary looks like this

I'd draw your role like this:

                    DATA COMPLIANCE
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
      LEGAL            PRIVACY          TECHNICAL
        │                 │                 │
        │                 │                 │
     Lawyer         Privacy Officer     YOU
        │                 │                 │
        │                 │                 │
        └───────────────┬─┴─────────────────┘
                        │
                    DATABASE
                    / DATA SYSTEM

You don't need to become the person on the left.

You want to become very strong on the right while understanding enough of the middle and left to collaborate intelligently.

Your actual learning boundary

For you specifically, I'd target this:

🟢 Go DEEP

Data

Data classification
Data inventory
Data mapping
Data lifecycle
Data lineage
Data minimization

Database security

Authentication
Authorization
RBAC
RLS
Encryption
Masking
Tokenization
Auditing
Logging
Key management
Backup security

Governance from a technical perspective

Ownership
Access reviews
Retention implementation
Data quality
Metadata
Data dictionary
Evidence

Compliance engineering

Controls
Control implementation
Evidence
Monitoring
Testing
Remediation
🟡 Know WELL ENOUGH

Privacy

Personal data
Sensitive data
Purpose limitation
Data minimization
Data subject rights
Collection/use/sharing
Retention
Cross-border transfers

Risk

Identify
Assess
Mitigate
Monitor

Incident response

Detect
Contain
Investigate
Preserve evidence
Remediate
Understand when escalation/notification may be required
🔴 Don't specialize yet
Detailed legal interpretation
Legal drafting
Privacy litigation
Enterprise legal compliance programs
Becoming a certified auditor
Memorizing every country's legislation

You can learn these later if you decide you want to move into Data Privacy Officer / GRC / Compliance as a career.

And there's a very nice career intersection here

Your existing skill set is actually pointing toward something interesting:

Database Developer + Data Security + Data Governance + Compliance

That's much more distinctive than simply saying:

"I'm a PostgreSQL developer."

You could eventually position yourself as someone who can build:

                    Business
                       │
                       ↓
                Data Requirements
                       │
                       ↓
                Data Governance
                       │
                       ↓
              ┌────────┴────────┐
              ↓                 ↓
          Compliance         Security
              │                 │
              └────────┬────────┘
                       ↓
                 DATABASE
                       ↓
              Audit + Evidence

And that is the level I would aim for.

So I would not move into country-specific laws yet.

Your next lesson should be:

Level 5 — Data Inventory & Data Mapping

Because that's the point where your database developer brain starts transitioning from:

"How do I store and protect this data?"

to:

"Why does this data exist, where does it go, who needs it, and can the organization prove that it is being handled appropriately?"

That's the real bridge into professional data compliance.

--=========================================================================

--=========================================================================
Your Practical Project

And here's what I'd really like you to do.

Instead of studying compliance purely theoretically, take your accounting database project and turn it into a mini compliance-aware database.

Build these components:

1. Data Classification
2. RBAC
3. Least Privilege
4. Sensitive Data Protection
5. Audit Logging
6. Data Retention
7. Data Lifecycle
8. Data Dictionary
9. Data Lineage
10. Access Review
11. Backup & Recovery Controls
12. Compliance Documentation

Then create a document like:

DATABASE COMPLIANCE SPECIFICATION

1. Data Inventory
2. Data Classification
3. Data Owners
4. Access Control Matrix
5. Sensitive Data Register
6. Audit Logging Design
7. Retention Policy
8. Data Lifecycle
9. Security Controls
10. Backup/Recovery
11. Data Lineage
12. Compliance Evidence

That would make a fantastic portfolio project because you're demonstrating much more than:

"I know PostgreSQL."

You're demonstrating:

"I know how to design and operate a database with security, governance, auditability, and compliance considerations."

🧭 The complete learning path

I'd structure your journey like this:

DATABASE FUNDAMENTALS
        │
        ▼
ADVANCED SQL / PostgreSQL
        │
        ▼
DATABASE ADMINISTRATION
        │
        ▼
DATABASE SECURITY
        │
        ▼
DATA GOVERNANCE
        │
        ▼
DATA PRIVACY
        │
        ▼
DATA COMPLIANCE
        │
        ▼
AUDIT / CONTROLS
        │
        ▼
DATA WAREHOUSE / ETL
        │
        ▼
DATA GOVERNANCE + COMPLIANCE
        │
        ▼
ENTERPRISE DATA ARCHITECTURE

And honestly, I would not put compliance at the end of your journey. Start learning the fundamentals now while continuing PostgreSQL, ETL, and data warehousing.

Your existing database project gives you something many beginners don't have: a real system to practice these concepts against.

If we continue this as a course, I'd suggest we start with Lesson 1: Data Privacy vs Data Security vs Data Governance vs Data Compliance, then I'll give you exercises using your PostgreSQL accounting system so you're learning the concepts and implementing them.