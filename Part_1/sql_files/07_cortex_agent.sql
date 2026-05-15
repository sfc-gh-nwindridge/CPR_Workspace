/*=============================================================================
  PART 2 - STEP 7: CORTEX AGENT DEFINITION
  ===========================================================================
  Creates a Cortex Agent that combines:
    - Structured queries via Cortex Analyst (semantic views)
    - Unstructured search via Cortex Search
    - Deterministic compliance workflows via stored procedures
  
  Prerequisites: Run scripts 01-06 first.
  Run as: CPR_WORKSHOP_ROLE
  ===========================================================================*/

-- ============================================================================
-- 7.1 ROLE & WAREHOUSE
-- ============================================================================

USE ROLE CPR_WORKSHOP_ROLE;
USE DATABASE GENERIC_DB;
USE SCHEMA ANALYTICS;
USE WAREHOUSE CPR_WORKSHOP_WH;

-- ============================================================================
-- 7.2 CREATE THE COMPLIANCE AGENT
-- ============================================================================
-- The agent combines three tool types:
--   1. cortex_analyst_text_to_sql  → Semantic Views (structured data queries)
--   2. cortex_search               → Cortex Search Service (unstructured notes)
--   3. generic (procedure)         → Stored Procedures (deterministic actions)

CREATE OR REPLACE AGENT GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT
FROM SPECIFICATION $$
{
  "models": {
    "orchestration": "auto"
  },
  "orchestration": {
    "budget": {
      "seconds": 900,
      "tokens": 400000
    }
  },
  "instructions": {
    "orchestration": "You are a Senior Compliance Analyst AI assistant for a financial institution.\n\nYour role is to help compliance officers with:\n- Answering questions about parties, contacts, and their relationships\n- Running screening checks against watchlists\n- Initiating and managing Enhanced Due Diligence (EDD) reviews\n- Monitoring Periodic Due Diligence (PDD) schedules\n- Updating risk ratings with proper justification\n- Searching compliance notes and historical records\n\nTool selection guidance:\n- For analytical questions about parties, contacts, risk distributions, or compliance metrics, use the semantic view tools (query_party_contacts or query_compliance).\n- For historical context, analyst notes, or narrative information, use the Cortex Search tool (search_compliance_notes).\n- For actions like running screening, initiating EDD, completing reviews, or updating risk ratings, use the stored procedure tools.\n- For a comprehensive party overview, use the party_360 tool.\n\nAlways be precise about party identifiers. When referencing a party, include both the party key and party name for clarity.",
    "response": "Format responses clearly with structured output where appropriate. When reporting screening results, use bullet points for each match. When showing party information, organize by category (identity, risk, contacts, compliance history). Always include party keys alongside names for traceability.",
    "sample_questions": [
      {"question": "Which parties are overdue for their periodic due diligence review?"},
      {"question": "Run a screening check on PTY-000012"},
      {"question": "Show me the full 360 view of Meridian Capital Partners"},
      {"question": "What are the compliance notes for high-risk parties in Singapore?"},
      {"question": "How many parties have a CRITICAL risk rating?"},
      {"question": "Initiate an EDD review for PTY-000007 due to unusual activity"},
      {"question": "What is the current distribution of risk ratings across all parties?"}
    ]
  },
  "tools": [
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "query_party_contacts",
        "description": "Query structured data about parties, contacts, locations, emails, and relationships. Use for questions like: How many parties are in each jurisdiction? Show me all contacts for a party. Which parties have the most contacts? What is the status distribution?"
      }
    },
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "query_compliance",
        "description": "Query compliance data including screening results, EDD reviews, PDD schedules, risk ratings, and review queues. Use for questions like: How many parties are HIGH risk? What is the screening hit rate? Which reviews are pending? Show risk rating distribution."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "search_compliance_notes",
        "description": "Search unstructured compliance notes, analyst memos, EDD narratives, and SAR summaries. Use for questions about historical context, qualitative assessments, site visit reports, or specific compliance events mentioned in free-text records."
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "run_screening",
        "description": "Run a watchlist/sanctions screening check on a specific party. Returns match summary including any hits against global watchlists. Use when asked to screen a party or check for sanctions matches.",
        "input_schema": {
          "type": "object",
          "properties": {
            "PARTY_KEY": {
              "type": "string",
              "description": "The party key to screen (e.g. PTY-000012)"
            }
          },
          "required": ["PARTY_KEY"]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "initiate_edd",
        "description": "Initiate an Enhanced Due Diligence (EDD) review for a party. Creates a new review case and places the party under enhanced monitoring. Use when escalation or deeper investigation is needed.",
        "input_schema": {
          "type": "object",
          "properties": {
            "PARTY_KEY": {
              "type": "string",
              "description": "The party key to initiate EDD for (e.g. PTY-000007)"
            },
            "TRIGGER_REASON": {
              "type": "string",
              "description": "The reason for initiating EDD (e.g. unusual activity, complex corporate structure)"
            }
          },
          "required": ["PARTY_KEY", "TRIGGER_REASON"]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "complete_review",
        "description": "Complete a compliance review by recording a decision and notes. Marks the review as finished and updates the party risk rating accordingly.",
        "input_schema": {
          "type": "object",
          "properties": {
            "REVIEW_ID": {
              "type": "string",
              "description": "The review ID to complete (e.g. EDD-000001)"
            },
            "DECISION": {
              "type": "string",
              "description": "The review decision: APPROVED, REJECTED, or ESCALATE"
            },
            "NOTES": {
              "type": "string",
              "description": "Analyst notes documenting the rationale for the decision"
            }
          },
          "required": ["REVIEW_ID", "DECISION", "NOTES"]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "get_pdd_overdue",
        "description": "Retrieve all parties that are overdue for their Periodic Due Diligence (PDD) review. Returns party details and how many days overdue each review is. No parameters needed.",
        "input_schema": {
          "type": "object",
          "properties": {},
          "required": []
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "update_risk_rating",
        "description": "Update the risk rating for a party with a documented reason. Creates a full audit trail of the change. Valid ratings: LOW, MEDIUM, HIGH, CRITICAL.",
        "input_schema": {
          "type": "object",
          "properties": {
            "PARTY_KEY": {
              "type": "string",
              "description": "The party key to update (e.g. PTY-000042)"
            },
            "NEW_RATING": {
              "type": "string",
              "description": "The new risk rating: LOW, MEDIUM, HIGH, or CRITICAL"
            },
            "REASON": {
              "type": "string",
              "description": "Justification for the rating change (e.g. new adverse media discovered)"
            }
          },
          "required": ["PARTY_KEY", "NEW_RATING", "REASON"]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "party_360",
        "description": "Get a comprehensive 360-degree view of a party including: identity details, contacts, locations, screening history, risk rating, open reviews, and compliance notes. Use for holistic party assessments.",
        "input_schema": {
          "type": "object",
          "properties": {
            "PARTY_KEY": {
              "type": "string",
              "description": "The party key to look up (e.g. PTY-000007)"
            }
          },
          "required": ["PARTY_KEY"]
        }
      }
    }
  ],
  "tool_resources": {
    "query_party_contacts": {
      "execution_environment": {
        "query_timeout": 299,
        "type": "warehouse",
        "warehouse": ""
      },
      "semantic_view": "GENERIC_DB.ANALYTICS.PARTY_CONTACTS_SV"
    },
    "query_compliance": {
      "execution_environment": {
        "query_timeout": 299,
        "type": "warehouse",
        "warehouse": ""
      },
      "semantic_view": "GENERIC_DB.ANALYTICS.COMPLIANCE_SV"
    },
    "search_compliance_notes": {
      "execution_environment": {
        "query_timeout": 299,
        "type": "warehouse",
        "warehouse": ""
      },
      "search_service": "GENERIC_DB.DOCUMENTS.COMPLIANCE_SEARCH"
    },
    "run_screening": {
      "type": "procedure",
      "identifier": "GENERIC_DB.COMPLIANCE.SP_RUN_SCREENING",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "CPR_WORKSHOP_WH",
        "query_timeout": 300
      }
    },
    "initiate_edd": {
      "type": "procedure",
      "identifier": "GENERIC_DB.COMPLIANCE.SP_INITIATE_EDD",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "CPR_WORKSHOP_WH",
        "query_timeout": 300
      }
    },
    "complete_review": {
      "type": "procedure",
      "identifier": "GENERIC_DB.COMPLIANCE.SP_COMPLETE_REVIEW",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "CPR_WORKSHOP_WH",
        "query_timeout": 300
      }
    },
    "get_pdd_overdue": {
      "type": "procedure",
      "identifier": "GENERIC_DB.COMPLIANCE.SP_GET_PDD_OVERDUE",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "CPR_WORKSHOP_WH",
        "query_timeout": 300
      }
    },
    "update_risk_rating": {
      "type": "procedure",
      "identifier": "GENERIC_DB.COMPLIANCE.SP_UPDATE_RISK_RATING",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "CPR_WORKSHOP_WH",
        "query_timeout": 300
      }
    },
    "party_360": {
      "type": "procedure",
      "identifier": "GENERIC_DB.COMPLIANCE.SP_PARTY_360",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "CPR_WORKSHOP_WH",
        "query_timeout": 300
      }
    }
  }
}
$$;

-- ============================================================================
-- 7.3 GRANT ACCESS TO THE AGENT
-- ============================================================================

GRANT USAGE ON AGENT GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT 
  TO ROLE CPR_WORKSHOP_ROLE;

-- ============================================================================
-- 7.4 VERIFY AGENT CREATION
-- ============================================================================

-- Check agent exists
SHOW AGENTS LIKE 'COMPLIANCE_AGENT' IN SCHEMA GENERIC_DB.ANALYTICS;

-- View full configuration
DESCRIBE AGENT GENERIC_DB.ANALYTICS.COMPLIANCE_AGENT;
