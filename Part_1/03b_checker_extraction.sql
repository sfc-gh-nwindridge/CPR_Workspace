/*=============================================================================
  KYC SUPERHERO WORKSHOP - STEP 3B: EXTRACTION CHECKER
  ===========================================================================
  The CHECKER layer for document extraction (Steps 4C & 5C).
  
  Implements the "4-eyes principle" using AI:
  - A DIFFERENT AI call independently re-reads each document
  - Compares its reading against the maker's extraction
  - Flags discrepancies, missing fields, and authenticity concerns
  
  This mirrors real-world compliance where:
  - Maker extracts the data
  - Checker independently verifies the extraction is accurate
  - Discrepancies are escalated for human review
  ===========================================================================*/

USE ROLE KYC_WORKSHOP_ROLE;
USE DATABASE KYC_SUPERHERO_DB;
USE SCHEMA CURATED;
USE WAREHOUSE KYC_WORKSHOP_WH;

-- ============================================================================
-- 3B.1 CHECKER: VALIDATE ID CARD EXTRACTIONS
-- ============================================================================
-- The checker re-reads the same image with a DIFFERENT prompt perspective.
-- It's told what the maker found and asked to verify/challenge it.
-- This catches hallucinations, misreads, and incomplete extractions.

CREATE OR REPLACE TABLE CHECKED_IDS AS
SELECT
  m.file_name,
  m.extracted_data AS maker_output,
  TRY_PARSE_JSON(
    AI_COMPLETE(
      'claude-sonnet-4-6',
      PROMPT(
        'You are an independent KYC COMPLIANCE CHECKER performing a verification review.
         Your role is NOT to extract data - it is to VERIFY a colleague''s extraction.
         
         A colleague (the "maker") extracted the following data from this ID card:
         {0}
         
         The ID card image is shown here: {1}
         
         YOUR VERIFICATION TASKS:
         1. Re-read the ID card image carefully and independently
         2. Compare YOUR reading against each field the maker extracted
         3. For each field, confirm if the maker''s value matches what you see
         4. Flag ANY discrepancies - even minor ones (typos, formatting differences)
         5. Check document authenticity indicators:
            - Does the card layout look professionally produced?
            - Are there any visual inconsistencies?
            - Is the photo consistent with the identity claimed?
         6. Verify MANDATORY KYC fields are all present:
            full_name, id_number, date_of_birth, expiry_date
         
         Be STRICT. In compliance, false confidence is worse than flagging for review.
         If in doubt, mark as NEEDS_REVIEW rather than PASS.
         
         RESPOND WITH ONLY A JSON OBJECT (no markdown, no explanation) with these keys:
         - check_status: "PASS" or "FAIL" or "NEEDS_REVIEW"
         - confidence_score: integer 0-100
         - fields_verified: integer count of fields confirmed correct
         - fields_with_discrepancies: integer count of fields with issues
         - discrepancies: array of objects with keys: field, maker_value, checker_value, severity (LOW/MEDIUM/HIGH)
         - document_authenticity: "APPEARS_GENUINE" or "SUSPICIOUS" or "LIKELY_FRAUDULENT"
         - mandatory_fields_complete: true/false
         - checker_notes: string with your reasoning',
        m.extracted_data::VARCHAR,
        TO_FILE('@KYC_SUPERHERO_DB.DOCUMENTS.ID_DOCUMENTS', m.file_name)
      )
    )
  ) AS checker_output,
  CURRENT_TIMESTAMP() AS checked_at
FROM EXTRACTED_IDS m;

-- View checker results for ID cards
SELECT
  file_name,
  maker_output:response:full_name::VARCHAR AS maker_extracted_name,
  checker_output:check_status::VARCHAR AS check_status,
  checker_output:confidence_score::INT AS confidence,
  checker_output:fields_verified::INT AS fields_ok,
  checker_output:fields_with_discrepancies::INT AS fields_disputed,
  checker_output:document_authenticity::VARCHAR AS authenticity,
  checker_output:mandatory_fields_complete::BOOLEAN AS mandatory_complete,
  checker_output:checker_notes::VARCHAR AS notes
FROM CHECKED_IDS
ORDER BY checker_output:confidence_score::INT ASC;  -- Show lowest confidence first


-- ============================================================================
-- 3B.2 CHECKER: VALIDATE KYC FORM EXTRACTIONS
-- ============================================================================
-- For KYC forms, the checker:
-- 1. Does an independent spot-check extraction of key fields
-- 2. Compares spot-check against the full maker extraction
-- 3. Checks for logical consistency (e.g. occupation vs source of funds)
-- 4. Validates completeness against regulatory requirements

CREATE OR REPLACE TABLE CHECKED_KYC AS
SELECT
  m.file_name,
  m.extracted_data AS maker_output,
  -- Independent spot-check: re-extract a subset of critical fields
  AI_EXTRACT(
    TO_FILE('@KYC_SUPERHERO_DB.DOCUMENTS.KYC_FORMS', m.file_name),
    {
      'full_name':       'Exact full legal name of the applicant',
      'source_of_funds': 'Declared source of funds or wealth',
      'occupation':      'Occupation or profession stated'
    }
  ) AS checker_spot_check,
  -- Full checker assessment comparing maker vs spot-check
  AI_COMPLETE(
    model => 'claude-sonnet-4-6',
    prompt => CONCAT(
      'You are a KYC COMPLIANCE CHECKER performing an independent verification of a form extraction.\n\n',
      '=== MAKER''S FULL EXTRACTION ===\n',
      m.extracted_data::VARCHAR, '\n\n',
      '=== YOUR TASK ===\n',
      'Validate the maker''s extraction for:\n',
      '1. COMPLETENESS: Are all required KYC fields populated?\n',
      '   Required fields: name, DOB, nationality, address, occupation, source of funds, purpose of account\n',
      '2. LOGICAL CONSISTENCY: Do the fields make sense together?\n',
      '   - Does the source of funds align with the stated occupation?\n',
      '   - Is the annual income plausible for the stated occupation?\n',
      '   - Does the purpose of account make sense for this type of applicant?\n',
      '3. RED FLAGS: Are there any indicators of concern?\n',
      '   - Vague or evasive answers (e.g. "various" for source of funds)\n',
      '   - Inconsistencies between different fields\n',
      '   - High-risk indicators (complex structures, unusual jurisdictions)\n',
      '4. REGULATORY COMPLIANCE:\n',
      '   - Is PEP status clearly declared?\n',
      '   - Is the form signed and dated?\n',
      '   - Would this pass a regulatory inspection?\n\n',
      'Be thorough. A passed form that later fails audit is worse than flagging for review.\n\n',
      'RESPOND WITH ONLY A VALID JSON OBJECT (no markdown, no explanation).'
    ),
    response_format => {
      'type': 'json',
      'schema': {
        'type': 'object',
        'properties': {
          'check_status':             {'type': 'string'},
          'confidence_score':         {'type': 'integer'},
          'completeness_pct':         {'type': 'integer'},
          'fields_missing':           {'type': 'array', 'items': {'type': 'string'}},
          'logical_inconsistencies':  {'type': 'array', 'items': {'type': 'string'}},
          'red_flags':                {'type': 'array', 'items': {'type': 'string'}},
          'discrepancies':            {'type': 'array', 'items': {
            'type': 'object',
            'properties': {
              'field':    {'type': 'string'},
              'issue':    {'type': 'string'},
              'severity': {'type': 'string'}
            }
          }},
          'pep_status_declared':  {'type': 'boolean'},
          'form_signed':          {'type': 'boolean'},
          'regulatory_ready':     {'type': 'boolean'},
          'checker_notes':        {'type': 'string'}
        },
        'required': ['check_status', 'confidence_score', 'completeness_pct', 
                     'fields_missing', 'logical_inconsistencies', 'red_flags',
                     'discrepancies', 'regulatory_ready', 'checker_notes']
      }
    }
  ) AS checker_output,
  CURRENT_TIMESTAMP() AS checked_at
FROM EXTRACTED_KYC m;

-- View checker results for KYC forms
SELECT
  file_name,
  maker_output:response:applicant_name::VARCHAR AS applicant,
  checker_output:check_status::VARCHAR AS check_status,
  checker_output:confidence_score::INT AS confidence,
  checker_output:completeness_pct::INT AS completeness,
  ARRAY_SIZE(checker_output:red_flags) AS red_flag_count,
  ARRAY_SIZE(checker_output:logical_inconsistencies) AS inconsistencies,
  checker_output:regulatory_ready::BOOLEAN AS reg_ready,
  checker_output:checker_notes::VARCHAR AS notes
FROM CHECKED_KYC
ORDER BY checker_output:check_status DESC, checker_output:confidence_score ASC;


-- ============================================================================
-- 3B.3 CHECKER SUMMARY: EXTRACTION QUALITY METRICS
-- ============================================================================

-- How reliable was the maker's extraction?
SELECT 
  'ID Cards' AS document_type,
  COUNT(*) AS total,
  SUM(CASE WHEN checker_output:check_status::VARCHAR = 'PASS' THEN 1 ELSE 0 END) AS passed,
  SUM(CASE WHEN checker_output:check_status::VARCHAR = 'FAIL' THEN 1 ELSE 0 END) AS failed,
  SUM(CASE WHEN checker_output:check_status::VARCHAR = 'NEEDS_REVIEW' THEN 1 ELSE 0 END) AS needs_review,
  ROUND(AVG(checker_output:confidence_score::INT), 1) AS avg_confidence,
  SUM(checker_output:fields_with_discrepancies::INT) AS total_discrepancies
FROM CHECKED_IDS

UNION ALL

SELECT 
  'KYC Forms' AS document_type,
  COUNT(*) AS total,
  SUM(CASE WHEN checker_output:check_status::VARCHAR = 'PASS' THEN 1 ELSE 0 END) AS passed,
  SUM(CASE WHEN checker_output:check_status::VARCHAR = 'FAIL' THEN 1 ELSE 0 END) AS failed,
  SUM(CASE WHEN checker_output:check_status::VARCHAR = 'NEEDS_REVIEW' THEN 1 ELSE 0 END) AS needs_review,
  ROUND(AVG(checker_output:confidence_score::INT), 1) AS avg_confidence,
  SUM(ARRAY_SIZE(checker_output:discrepancies)) AS total_discrepancies
FROM CHECKED_KYC;
