/*=============================================================================
  KYC SUPERHERO WORKSHOP - STEP 6: STREAMLIT DASHBOARD
  ===========================================================================
  Creates a Streamlit in Snowflake app to visualise the pipeline results.
  
  Prerequisites: Run scripts 01-05 first.
  Run as: KYC_WORKSHOP_ROLE
  
  NOTE: This script creates the stage and Streamlit object. You must also
  upload the dashboard.py file to the stage. From a Snowflake worksheet:
  
    PUT file:///<path-to>/dashboard.py @KYC_SUPERHERO_DB.ANALYTICS.DASHBOARD_STAGE/ 
        AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
  
  Or use the Snowflake CLI:
    snow stage copy dashboard.py @KYC_SUPERHERO_DB.ANALYTICS.DASHBOARD_STAGE/
  ===========================================================================*/

USE ROLE KYC_WORKSHOP_ROLE;
USE DATABASE KYC_SUPERHERO_DB;
USE SCHEMA ANALYTICS;
USE WAREHOUSE KYC_WORKSHOP_WH;

-- ============================================================================
-- 6.1 CREATE STAGE FOR STREAMLIT FILES
-- ============================================================================

CREATE OR REPLACE STAGE DASHBOARD_STAGE
  COMMENT = 'Stage for KYC Pipeline Dashboard Streamlit app';

-- ============================================================================
-- 6.2 UPLOAD THE DASHBOARD FILE
-- ============================================================================
-- Run this line after placing dashboard.py in your local directory:

PUT file://dashboard.py @KYC_SUPERHERO_DB.ANALYTICS.DASHBOARD_STAGE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- ============================================================================
-- 6.3 CREATE THE STREAMLIT APP
-- ============================================================================

CREATE OR REPLACE STREAMLIT KYC_PIPELINE_DASHBOARD
  ROOT_LOCATION = '@KYC_SUPERHERO_DB.ANALYTICS.DASHBOARD_STAGE'
  MAIN_FILE = 'dashboard.py'
  QUERY_WAREHOUSE = 'KYC_WORKSHOP_WH'
  TITLE = 'KYC Superhero Pipeline Dashboard'
  COMMENT = 'Maker/Checker pipeline dashboard for KYC document processing';

-- ============================================================================
-- 6.4 ACCESS THE DASHBOARD
-- ============================================================================
-- The dashboard is now available in Snowsight under:
--   Projects > Streamlit > KYC_PIPELINE_DASHBOARD
--
-- Or describe it to get the URL:
DESCRIBE STREAMLIT KYC_PIPELINE_DASHBOARD;
