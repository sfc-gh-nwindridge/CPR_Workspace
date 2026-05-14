/*=============================================================================
  KYC SUPERHERO WORKSHOP - STEP 3: DOCUMENT EXTRACTION (MAKER)
  ===========================================================================
  The MAKER layer: Extract structured data from documents using Cortex AI.
  
  Two document types are processed:
  1. ID Cards (PNG images) → AI_EXTRACT (supports images natively)
  2. KYC Forms (PDF documents) → AI_EXTRACT for structured field extraction
  
  This demonstrates:
  - AI reading images and PDFs directly (no OCR preprocessing)
  - Structured extraction with natural language questions
  - Batch processing across all documents in a stage
  ===========================================================================*/

USE ROLE KYC_WORKSHOP_ROLE;
USE DATABASE KYC_SUPERHERO_DB;
USE SCHEMA CURATED;
USE WAREHOUSE KYC_WORKSHOP_WH;

-- ============================================================================
-- 3.1 MAKER: EXTRACT DATA FROM ID CARD IMAGES
-- ============================================================================
-- AI_EXTRACT reads the superhero ID card images (PNG) directly.
-- It supports structured extraction from images with no preprocessing needed.
-- We ask natural language questions and get back a clean JSON object.

CREATE OR REPLACE TABLE EXTRACTED_IDS AS
SELECT
  RELATIVE_PATH AS file_name,
  AI_EXTRACT(
    TO_FILE('@KYC_SUPERHERO_DB.DOCUMENTS.ID_DOCUMENTS', RELATIVE_PATH),
    {
      'full_name':         'Full name as printed on the card',
      'hero_alias':        'Superhero name or code name if shown',
      'id_number':         'ID number or badge number',
      'date_of_birth':     'Date of birth',
      'nationality':       'Nationality or citizenship',
      'address':           'Address if visible',
      'affiliation':       'Organisation or team affiliation',
      'classification':    'Security classification or clearance level',
      'issue_date':        'Date the ID was issued',
      'expiry_date':       'Expiry date or valid until date',
      'issuing_authority': 'Issuing authority or organisation',
      'photo_present':     'Is a photo visible on the card (yes/no)'
    }
  ) AS extracted_data,
  CURRENT_TIMESTAMP() AS processed_at
FROM DIRECTORY(@KYC_SUPERHERO_DB.DOCUMENTS.ID_DOCUMENTS);

-- View extracted ID data
-- AI_EXTRACT returns {"error": null, "response": {...}} so access via :response:field
SELECT 
  file_name,
  extracted_data:response:full_name::VARCHAR AS full_name,
  extracted_data:response:hero_alias::VARCHAR AS hero_alias,
  extracted_data:response:id_number::VARCHAR AS id_number,
  extracted_data:response:date_of_birth::VARCHAR AS date_of_birth,
  extracted_data:response:affiliation::VARCHAR AS affiliation,
  extracted_data:response:classification::VARCHAR AS classification
FROM EXTRACTED_IDS
ORDER BY file_name;


-- ============================================================================
-- 3.2 MAKER: EXTRACT DATA FROM KYC APPLICATION FORMS
-- ============================================================================
-- AI_EXTRACT processes the PDF forms and pulls out named fields.
-- This simulates automated KYC onboarding form processing.

CREATE OR REPLACE TABLE EXTRACTED_KYC AS
SELECT
  RELATIVE_PATH AS file_name,
  AI_EXTRACT(
    TO_FILE('@KYC_SUPERHERO_DB.DOCUMENTS.KYC_FORMS', RELATIVE_PATH),
    {
      'applicant_name':     'The full legal name of the applicant',
      'date_of_birth':      'The applicant date of birth',
      'nationality':        'Nationality or citizenship of the applicant',
      'residential_address': 'Full residential or correspondence address',
      'occupation':         'Stated occupation, profession, or job title',
      'employer':           'Name of employer or organisation',
      'source_of_funds':    'Declared source of funds, income, or wealth',
      'purpose_of_account': 'Stated purpose for opening the account or relationship',
      'annual_income':      'Declared annual income or salary range',
      'politically_exposed': 'Is the person a Politically Exposed Person (PEP)? (yes/no/not stated)',
      'associated_entities': 'Any companies, organisations, trusts, or associates mentioned',
      'id_document_type':   'Type of ID document referenced (passport, driving licence, etc.)',
      'id_document_number': 'ID document reference number if provided',
      'signature_present':  'Is the form signed by the applicant (yes/no)',
      'date_signed':        'Date the form was signed'
    }
  ) AS extracted_data,
  CURRENT_TIMESTAMP() AS processed_at
FROM DIRECTORY(@KYC_SUPERHERO_DB.DOCUMENTS.KYC_FORMS);

-- View extracted KYC data
SELECT 
  file_name,
  extracted_data:response:applicant_name::VARCHAR AS applicant_name,
  extracted_data:response:date_of_birth::VARCHAR AS date_of_birth,
  extracted_data:response:nationality::VARCHAR AS nationality,
  extracted_data:response:occupation::VARCHAR AS occupation,
  extracted_data:response:source_of_funds::VARCHAR AS source_of_funds,
  extracted_data:response:politically_exposed::VARCHAR AS pep_status,
  extracted_data:response:associated_entities::VARCHAR AS associated_entities,
  extracted_data:response:signature_present::VARCHAR AS signed
FROM EXTRACTED_KYC
ORDER BY file_name;


-- ============================================================================
-- 3.3 DOCUMENT REGISTRY
-- ============================================================================
-- Track what we've processed for audit/lineage purposes

CREATE OR REPLACE VIEW DOCUMENT_REGISTRY AS
SELECT 
  'ID_CARD' AS document_type,
  file_name,
  extracted_data:response:full_name::VARCHAR AS primary_entity,
  processed_at,
  'AI_EXTRACT' AS extraction_method,
  'MAKER' AS process_stage
FROM EXTRACTED_IDS

UNION ALL

SELECT 
  'KYC_FORM' AS document_type,
  file_name,
  extracted_data:response:applicant_name::VARCHAR AS primary_entity,
  processed_at,
  'AI_EXTRACT' AS extraction_method,
  'MAKER' AS process_stage
FROM EXTRACTED_KYC;

-- View the registry
SELECT * FROM DOCUMENT_REGISTRY ORDER BY document_type, file_name;
