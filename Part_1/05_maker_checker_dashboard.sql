/*=============================================================================
  KYC SUPERHERO WORKSHOP - STEP 5: MAKER/CHECKER DASHBOARD
  ===========================================================================
  Final dashboard combining all maker and checker results.
  
  Provides:
  - End-to-end pipeline status for each applicant
  - Maker/checker agreement rates
  - Discrepancy analysis
  - Items requiring human escalation
  - Regulatory readiness summary
  ===========================================================================*/

USE ROLE KYC_WORKSHOP_ROLE;
USE DATABASE KYC_SUPERHERO_DB;
USE SCHEMA ANALYTICS;
USE WAREHOUSE KYC_WORKSHOP_WH;

-- ============================================================================
-- 5.1 PIPELINE STATUS: COMPLETE VIEW PER APPLICANT
-- ============================================================================
-- Shows each applicant's journey through the entire maker/checker pipeline

CREATE OR REPLACE VIEW PIPELINE_STATUS AS
SELECT
  -- Applicant identity
  k.file_name,
  k.extracted_data:response:applicant_name::VARCHAR AS applicant_name,
  
  -- Stage 1: ID Card extraction status
  id_check.checker_output:check_status::VARCHAR AS id_extraction_status,
  id_check.checker_output:confidence_score::INT AS id_confidence,
  id_check.checker_output:document_authenticity::VARCHAR AS id_authenticity,
  
  -- Stage 2: KYC Form extraction status
  kyc_check.checker_output:check_status::VARCHAR AS kyc_extraction_status,
  kyc_check.checker_output:confidence_score::INT AS kyc_confidence,
  kyc_check.checker_output:completeness_pct::INT AS kyc_completeness,
  kyc_check.checker_output:regulatory_ready::BOOLEAN AS kyc_reg_ready,
  
  -- Stage 3: Entity cross-reference status
  xref_check.checker_output:check_status::VARCHAR AS crossref_status,
  xref_check.checker_output:confidence_score::INT AS crossref_confidence,
  xref_check.checker_output:recommended_action::VARCHAR AS crossref_recommendation,
  
  -- Stage 4: EDD assessment (if applicable)
  edd.edd_trigger_reason,
  edd_review.senior_review:check_status::VARCHAR AS edd_senior_decision,
  edd_review.senior_review:senior_risk_score::INT AS edd_risk_score,
  edd_review.senior_review:regulatory_compliance::VARCHAR AS edd_reg_compliance,
  
  -- Overall pipeline result
  CASE
    -- Any FAIL at any stage = BLOCKED
    WHEN id_check.checker_output:check_status::VARCHAR = 'FAIL' THEN 'BLOCKED'
    WHEN kyc_check.checker_output:check_status::VARCHAR = 'FAIL' THEN 'BLOCKED'
    WHEN xref_check.checker_output:check_status::VARCHAR = 'FAIL' THEN 'BLOCKED'
    WHEN edd_review.senior_review:check_status::VARCHAR = 'REJECTED' THEN 'BLOCKED'
    -- Any ESCALATE = needs human
    WHEN edd_review.senior_review:check_status::VARCHAR = 'ESCALATE_TO_MLRO' THEN 'ESCALATED'
    -- Any NEEDS_REVIEW = pending
    WHEN id_check.checker_output:check_status::VARCHAR = 'NEEDS_REVIEW' THEN 'PENDING_REVIEW'
    WHEN kyc_check.checker_output:check_status::VARCHAR = 'NEEDS_REVIEW' THEN 'PENDING_REVIEW'
    WHEN xref_check.checker_output:check_status::VARCHAR = 'NEEDS_REVIEW' THEN 'PENDING_REVIEW'
    -- All passed = cleared
    ELSE 'CLEARED'
  END AS overall_status

FROM KYC_SUPERHERO_DB.CURATED.EXTRACTED_KYC k

LEFT JOIN KYC_SUPERHERO_DB.CURATED.CHECKED_IDS id_check
  ON REPLACE(k.file_name, 'KYC_Form', 'ID') = REPLACE(id_check.file_name, '.png', '.pdf')
  -- Note: adjust join logic based on actual filename patterns

LEFT JOIN KYC_SUPERHERO_DB.CURATED.CHECKED_KYC kyc_check
  ON k.file_name = kyc_check.file_name

LEFT JOIN KYC_SUPERHERO_DB.CURATED.CHECKED_CROSSREF xref_check
  ON k.file_name = xref_check.file_name

LEFT JOIN KYC_SUPERHERO_DB.ANALYTICS.EDD_ASSESSMENT edd
  ON k.file_name = edd.file_name

LEFT JOIN KYC_SUPERHERO_DB.ANALYTICS.CHECKED_EDD edd_review
  ON k.file_name = edd_review.file_name;


-- ============================================================================
-- 5.2 MAKER/CHECKER AGREEMENT DASHBOARD
-- ============================================================================

CREATE OR REPLACE VIEW MAKER_CHECKER_AGREEMENT AS

-- ID Card extraction agreement
SELECT 
  'ID Card Extraction' AS pipeline_stage,
  file_name,
  maker_output:response:full_name::VARCHAR AS entity_name,
  checker_output:check_status::VARCHAR AS checker_verdict,
  checker_output:confidence_score::INT AS confidence,
  checker_output:fields_with_discrepancies::INT AS discrepancy_count,
  checker_output:document_authenticity::VARCHAR AS quality_indicator,
  checker_output:checker_notes::VARCHAR AS checker_reasoning
FROM KYC_SUPERHERO_DB.CURATED.CHECKED_IDS

UNION ALL

-- KYC Form extraction agreement
SELECT 
  'KYC Form Extraction' AS pipeline_stage,
  file_name,
  maker_output:response:applicant_name::VARCHAR AS entity_name,
  checker_output:check_status::VARCHAR AS checker_verdict,
  checker_output:confidence_score::INT AS confidence,
  ARRAY_SIZE(checker_output:discrepancies) AS discrepancy_count,
  CASE WHEN checker_output:regulatory_ready::BOOLEAN THEN 'REG_READY' ELSE 'NOT_READY' END AS quality_indicator,
  checker_output:checker_notes::VARCHAR AS checker_reasoning
FROM KYC_SUPERHERO_DB.CURATED.CHECKED_KYC

UNION ALL

-- Entity cross-reference agreement
SELECT 
  'Entity Screening' AS pipeline_stage,
  file_name,
  applicant_name AS entity_name,
  checker_output:check_status::VARCHAR AS checker_verdict,
  checker_output:confidence_score::INT AS confidence,
  ARRAY_SIZE(checker_output:potential_missed_matches) AS discrepancy_count,
  checker_output:recommended_action::VARCHAR AS quality_indicator,
  checker_output:checker_notes::VARCHAR AS checker_reasoning
FROM KYC_SUPERHERO_DB.CURATED.CHECKED_CROSSREF

UNION ALL

-- EDD assessment agreement
SELECT 
  'EDD Assessment' AS pipeline_stage,
  file_name,
  applicant_name AS entity_name,
  senior_review:check_status::VARCHAR AS checker_verdict,
  (100 - ABS(senior_review:score_variance::INT) * 10) AS confidence,
  ARRAY_SIZE(senior_review:missing_risk_factors) + ARRAY_SIZE(senior_review:additional_actions_required) AS discrepancy_count,
  senior_review:regulatory_compliance::VARCHAR AS quality_indicator,
  senior_review:final_recommendation::VARCHAR AS checker_reasoning
FROM KYC_SUPERHERO_DB.ANALYTICS.CHECKED_EDD;


-- ============================================================================
-- 5.3 SUMMARY STATISTICS
-- ============================================================================

-- Overall pass rates by pipeline stage
SELECT
  pipeline_stage,
  COUNT(*) AS total_checks,
  SUM(CASE WHEN checker_verdict IN ('PASS', 'APPROVED') THEN 1 ELSE 0 END) AS passed,
  SUM(CASE WHEN checker_verdict IN ('FAIL', 'REJECTED') THEN 1 ELSE 0 END) AS failed,
  SUM(CASE WHEN checker_verdict IN ('NEEDS_REVIEW', 'ESCALATE_TO_MLRO') THEN 1 ELSE 0 END) AS needs_review,
  ROUND(AVG(confidence), 1) AS avg_confidence,
  SUM(discrepancy_count) AS total_discrepancies,
  ROUND(
    SUM(CASE WHEN checker_verdict IN ('PASS', 'APPROVED') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 
    1
  ) AS pass_rate_pct
FROM MAKER_CHECKER_AGREEMENT
GROUP BY pipeline_stage
ORDER BY pass_rate_pct ASC;  -- Show weakest stage first


-- ============================================================================
-- 5.4 ITEMS REQUIRING HUMAN ESCALATION
-- ============================================================================

CREATE OR REPLACE VIEW ESCALATION_QUEUE AS
SELECT
  pipeline_stage,
  entity_name,
  file_name,
  checker_verdict,
  confidence,
  discrepancy_count,
  quality_indicator,
  checker_reasoning,
  CASE
    WHEN checker_verdict = 'FAIL' THEN 'HIGH'
    WHEN checker_verdict IN ('REJECTED', 'ESCALATE_TO_MLRO') THEN 'HIGH'
    WHEN checker_verdict = 'NEEDS_REVIEW' AND confidence < 50 THEN 'HIGH'
    WHEN checker_verdict = 'NEEDS_REVIEW' THEN 'MEDIUM'
    ELSE 'LOW'
  END AS escalation_priority
FROM MAKER_CHECKER_AGREEMENT
WHERE checker_verdict NOT IN ('PASS', 'APPROVED')
ORDER BY 
  CASE 
    WHEN checker_verdict IN ('FAIL', 'REJECTED') THEN 1
    WHEN checker_verdict = 'ESCALATE_TO_MLRO' THEN 2
    WHEN checker_verdict = 'NEEDS_REVIEW' THEN 3
    ELSE 4
  END,
  confidence ASC;

-- View the escalation queue
SELECT * FROM ESCALATION_QUEUE;


-- ============================================================================
-- 5.5 EXECUTIVE SUMMARY
-- ============================================================================
-- A single query that tells the story - perfect for the workshop "wow moment"

SELECT
  '🦸 KYC SUPERHERO PIPELINE - EXECUTIVE SUMMARY' AS report_title,
  CURRENT_TIMESTAMP() AS report_generated,
  (SELECT COUNT(*) FROM KYC_SUPERHERO_DB.CURATED.EXTRACTED_IDS) AS documents_processed_ids,
  (SELECT COUNT(*) FROM KYC_SUPERHERO_DB.CURATED.EXTRACTED_KYC) AS documents_processed_kyc,
  (SELECT COUNT(*) FROM KYC_SUPERHERO_DB.CURATED.ENTITY_CROSSREF WHERE edd_required) AS edd_cases_flagged,
  (SELECT COUNT(*) FROM CHECKED_EDD WHERE senior_review:check_status::VARCHAR = 'APPROVED') AS edd_approved,
  (SELECT COUNT(*) FROM CHECKED_EDD WHERE senior_review:check_status::VARCHAR = 'REJECTED') AS edd_rejected,
  (SELECT COUNT(*) FROM CHECKED_EDD WHERE senior_review:check_status::VARCHAR = 'ESCALATE_TO_MLRO') AS edd_escalated,
  (SELECT ROUND(AVG(checker_output:confidence_score::INT), 0) FROM KYC_SUPERHERO_DB.CURATED.CHECKED_IDS) AS avg_id_confidence,
  (SELECT ROUND(AVG(checker_output:confidence_score::INT), 0) FROM KYC_SUPERHERO_DB.CURATED.CHECKED_KYC) AS avg_kyc_confidence;


-- ============================================================================
-- 5.6 RED FLAGS DETAIL
-- ============================================================================
-- Deep dive into KYC red flags identified by the checker

SELECT
  file_name,
  maker_output:response:applicant_name::VARCHAR AS applicant,
  f.VALUE::VARCHAR AS red_flag
FROM KYC_SUPERHERO_DB.CURATED.CHECKED_KYC,
  LATERAL FLATTEN(input => checker_output:red_flags) f
ORDER BY applicant;

-- Logical inconsistencies found
SELECT
  file_name,
  maker_output:response:applicant_name::VARCHAR AS applicant,
  f.VALUE::VARCHAR AS inconsistency
FROM KYC_SUPERHERO_DB.CURATED.CHECKED_KYC,
  LATERAL FLATTEN(input => checker_output:logical_inconsistencies) f
ORDER BY applicant;
