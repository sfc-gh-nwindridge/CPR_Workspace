# KYC Superhero AI Workshop

An AI-powered KYC (Know Your Customer) document processing pipeline built on Snowflake Cortex AI, using a **Maker/Checker architecture** for compliance-grade validation.

The workshop uses superhero-themed documents to demonstrate how Cortex AI can extract, validate, and cross-reference identity documents against watchlists — mirroring real-world AML/KYC workflows.

## What It Does

1. **Document Extraction (Maker)** — AI reads ID card images (PNG) and KYC application forms (PDF) directly, extracting structured data without OCR
2. **Extraction Validation (Checker)** — A separate AI independently re-reads each document and challenges the maker's extraction
3. **Entity Cross-Reference** — Matches extracted names against a known-entities database and sanctions/watchlist
4. **Enhanced Due Diligence** — AI generates risk assessments for flagged entities
5. **Cross-Reference Validation (Checker)** — Independent AI validates matching decisions and EDD assessments
6. **Dashboard** — Final analytics views showing pipeline status, agreement rates, and escalations

## Prerequisites

- A Snowflake account with **ACCOUNTADMIN** access (for initial setup only)
- Cortex AI enabled in your region (for `AI_EXTRACT` and `AI_COMPLETE` functions)
- A **MEDIUM** warehouse (created by the setup script)

## Quick Start

### Step 1: Initial Setup (ACCOUNTADMIN — one time only)

Open `00_demo_environment.sql` in a Snowflake worksheet and run it as **ACCOUNTADMIN**.

> **Important:** Edit line 32 to replace `NWINDRIDGE` with your Snowflake username.

This creates:
- `KYC_WORKSHOP_ROLE` — a dedicated role that owns all workshop objects
- `KYC_WORKSHOP_WH` — a MEDIUM warehouse
- `kyc_workshop_git_integration` — API integration for Git access
- Cortex AI access grants

### Step 2: Run the Pipeline (KYC_WORKSHOP_ROLE)

Switch to `KYC_WORKSHOP_ROLE` and run each script **in order**:

| # | Script | What it does | Duration |
|---|--------|-------------|----------|
| 1 | `01_setup.sql` | Creates database, schemas, clones Git repo, stages documents | ~1 min |
| 2 | `02_reference_data.sql` | Loads hero master data + sanctions watchlist | ~5 sec |
| 3 | `03_document_extraction.sql` | **Maker**: AI extracts data from ID cards + KYC forms | ~2-3 min |
| 4 | `03b_checker_extraction.sql` | **Checker**: AI validates extractions | ~3-4 min |
| 5 | `04_crossref_and_edd.sql` | Cross-references entities + AI generates EDD assessments | ~2-3 min |
| 6 | `04b_checker_review.sql` | **Checker**: AI validates cross-references + EDD | ~3-4 min |
| 7 | `05_maker_checker_dashboard.sql` | Creates final analytics/dashboard views | ~10 sec |

Each script explicitly sets `USE ROLE KYC_WORKSHOP_ROLE` at the top, so you can run them independently in any worksheet.

### Step 3: Explore Results

After running all scripts, query the dashboard views:

```sql
USE ROLE KYC_WORKSHOP_ROLE;
USE DATABASE KYC_SUPERHERO_DB;
USE SCHEMA ANALYTICS;

-- Full pipeline status per applicant
SELECT * FROM PIPELINE_STATUS;

-- Maker/checker agreement analysis
SELECT * FROM AGREEMENT_ANALYSIS;

-- Items requiring human escalation
SELECT * FROM ESCALATION_QUEUE;
```

## Architecture

### Role Hierarchy

```
ACCOUNTADMIN
  └── SYSADMIN
        └── KYC_WORKSHOP_ROLE  (owns all workshop objects)
              ├── Database: KYC_SUPERHERO_DB
              ├── Warehouse: KYC_WORKSHOP_WH
              ├── Cortex AI: SNOWFLAKE.CORTEX_USER
              └── Integration: kyc_workshop_git_integration
```

### Database Schema Layout

```
KYC_SUPERHERO_DB
  ├── RAW          — Reference data (heroes, watchlists)
  ├── DOCUMENTS    — Stages (ID cards, KYC forms), Git repo
  ├── CURATED      — Extracted data, checker validations, cross-references
  └── ANALYTICS    — Dashboard views, pipeline status, escalations
```

### Pipeline Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────────┐     ┌────────────┐
│  Documents  │────▶│   MAKER     │────▶│    CHECKER       │────▶│  Dashboard │
│ (ID + KYC)  │     │ AI_EXTRACT  │     │  AI_COMPLETE     │     │   Views    │
└─────────────┘     └─────────────┘     └─────────────────┘     └────────────┘
                          │                      │
                          ▼                      ▼
                    ┌───────────┐         ┌───────────────┐
                    │ Cross-Ref │────────▶│ Checker Review │
                    │ + EDD     │         │ + Escalation   │
                    └───────────┘         └───────────────┘
```

## Optional: Git Workspace in Snowsight

You can run these scripts directly from Snowsight by connecting this GitHub repo as a workspace.

### Setup

1. Ensure `00_demo_environment.sql` has been run (creates the integration)
2. In Snowsight, go to **Projects > Workspaces**
3. Click **Create > From Git repository**
4. Enter:
   - **Repository URL**: `https://github.com/sfc-gh-nwindridge/AI_Workshop.git`
   - **API Integration**: `kyc_workshop_git_integration`
5. If prompted for authentication, create a PAT secret:
   ```sql
   USE ROLE KYC_WORKSHOP_ROLE;
   CREATE SECRET KYC_SUPERHERO_DB.PUBLIC.GIT_PAT
     TYPE = PASSWORD
     USERNAME = '<your-github-username>'
     PASSWORD = '<your-github-pat>';
   ```
6. Select the secret and create the workspace

You can now open and execute each SQL file directly from the workspace.

## Cleanup

To completely remove all workshop objects and reset the environment:

```sql
-- Run 99_cleanup.sql as ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;
-- Then execute the script
```

Or simply run `99_cleanup.sql` in a worksheet.

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `Insufficient privileges to operate on account` | Running `CREATE DATABASE` without the grant | Run `00_demo_environment.sql` first as ACCOUNTADMIN |
| `Integration does not allow specified secret` | Secret not permitted by the integration | The integration uses `ALLOWED_AUTHENTICATION_SECRETS = ALL` — ensure you're referencing `kyc_workshop_git_integration` (not an older integration) |
| `Schema does not exist` | Running scripts out of order | Run `01_setup.sql` first to create all schemas |
| `Database role SNOWFLAKE.CORTEX_USER does not exist` | Cortex AI not enabled in your region | Check that your Snowflake region supports Cortex AI functions |
| `User 'CURRENT_USER' does not exist` | Snowflake doesn't resolve `CURRENT_USER` in GRANT statements | Replace with your actual username in `00_demo_environment.sql` |

## Cortex AI Functions Used

- **`AI_EXTRACT`** — Reads images (PNG) and PDFs directly, extracting structured JSON based on natural language questions
- **`AI_COMPLETE`** — Generates text completions for validation prompts, risk assessments, and checker reviews
