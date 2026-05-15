import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

session = get_active_session()

st.set_page_config(page_title="KYC Pipeline Dashboard", layout="wide")
st.title("KYC Superhero Pipeline Dashboard")
st.caption("Maker/Checker AI-Powered Document Processing Pipeline")

# --- Key Metrics ---
col1, col2, col3, col4 = st.columns(4)

pipeline_df = session.sql("SELECT * FROM KYC_SUPERHERO_DB.ANALYTICS.PIPELINE_STATUS").to_pandas()

with col1:
    st.metric("Applicants Processed", len(pipeline_df))
with col2:
    cleared = len(pipeline_df[pipeline_df["OVERALL_STATUS"] == "CLEARED"])
    st.metric("Cleared", cleared)
with col3:
    escalated = len(pipeline_df[pipeline_df["OVERALL_STATUS"].isin(["ESCALATED", "PENDING_REVIEW"])])
    st.metric("Pending / Escalated", escalated)
with col4:
    blocked = len(pipeline_df[pipeline_df["OVERALL_STATUS"] == "BLOCKED"])
    st.metric("Blocked", blocked)

st.divider()

# --- Tabs ---
tab1, tab2, tab3, tab4 = st.tabs(["Pipeline Overview", "Maker/Checker Agreement", "Escalation Queue", "EDD Deep Dive"])

# ===================== TAB 1: Pipeline Overview =====================
with tab1:
    st.subheader("Pipeline Status by Applicant")

    # Status distribution chart
    status_counts = pipeline_df["OVERALL_STATUS"].value_counts().reset_index()
    status_counts.columns = ["Status", "Count"]
    st.bar_chart(status_counts, x="Status", y="Count", color="Status")

    # Detailed table
    st.subheader("Applicant Detail")
    display_cols = ["APPLICANT_NAME", "OVERALL_STATUS", "KYC_EXTRACTION_STATUS",
                    "KYC_CONFIDENCE", "CROSSREF_STATUS", "EDD_TRIGGER_REASON"]
    available_cols = [c for c in display_cols if c in pipeline_df.columns]
    st.dataframe(pipeline_df[available_cols], use_container_width=True, hide_index=True)

# ===================== TAB 2: Maker/Checker Agreement =====================
with tab2:
    st.subheader("Checker Verdicts by Pipeline Stage")

    agreement_df = session.sql("""
        SELECT pipeline_stage, checker_verdict, confidence, discrepancy_count, entity_name
        FROM KYC_SUPERHERO_DB.ANALYTICS.MAKER_CHECKER_AGREEMENT
        WHERE checker_verdict IS NOT NULL
    """).to_pandas()

    if not agreement_df.empty:
        # Verdict distribution by stage
        verdict_summary = agreement_df.groupby(["PIPELINE_STAGE", "CHECKER_VERDICT"]).size().reset_index(name="COUNT")
        st.bar_chart(verdict_summary, x="PIPELINE_STAGE", y="COUNT", color="CHECKER_VERDICT", stack=False)

        # Confidence scores
        st.subheader("Average Confidence by Stage")
        conf_df = agreement_df.groupby("PIPELINE_STAGE")["CONFIDENCE"].mean().reset_index()
        conf_df.columns = ["Stage", "Avg Confidence"]
        st.bar_chart(conf_df, x="Stage", y="Avg Confidence")

        # Detail table
        st.subheader("All Checker Results")
        st.dataframe(agreement_df, use_container_width=True, hide_index=True)
    else:
        st.info("No checker agreement data available.")

# ===================== TAB 3: Escalation Queue =====================
with tab3:
    st.subheader("Items Requiring Human Review")

    escalation_df = session.sql("""
        SELECT pipeline_stage, entity_name, checker_verdict, confidence,
               discrepancy_count, escalation_priority
        FROM KYC_SUPERHERO_DB.ANALYTICS.ESCALATION_QUEUE
        ORDER BY
            CASE escalation_priority WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,
            confidence ASC
    """).to_pandas()

    if not escalation_df.empty:
        # Priority breakdown
        col1, col2, col3 = st.columns(3)
        with col1:
            high = len(escalation_df[escalation_df["ESCALATION_PRIORITY"] == "HIGH"])
            st.metric("HIGH Priority", high)
        with col2:
            medium = len(escalation_df[escalation_df["ESCALATION_PRIORITY"] == "MEDIUM"])
            st.metric("MEDIUM Priority", medium)
        with col3:
            low = len(escalation_df[escalation_df["ESCALATION_PRIORITY"] == "LOW"])
            st.metric("LOW Priority", low)

        # Priority chart
        priority_counts = escalation_df["ESCALATION_PRIORITY"].value_counts().reset_index()
        priority_counts.columns = ["Priority", "Count"]
        st.bar_chart(priority_counts, x="Priority", y="Count", color="Priority")

        # Queue table
        st.subheader("Escalation Detail")
        st.dataframe(escalation_df, use_container_width=True, hide_index=True)
    else:
        st.success("No items pending escalation - all clear!")

# ===================== TAB 4: EDD Deep Dive =====================
with tab4:
    st.subheader("Enhanced Due Diligence Assessments")

    edd_df = session.sql("""
        SELECT applicant_name, known_risk_level, edd_trigger_reason,
               edd_assessment:risk_score::INT AS risk_score,
               edd_assessment:recommendation::VARCHAR AS recommendation,
               edd_assessment:summary::VARCHAR AS summary,
               edd_assessment:risk_factors AS risk_factors
        FROM KYC_SUPERHERO_DB.ANALYTICS.EDD_ASSESSMENT
        ORDER BY edd_assessment:risk_score::INT DESC
    """).to_pandas()

    if not edd_df.empty:
        for _, row in edd_df.iterrows():
            with st.expander(f"{row['APPLICANT_NAME']} — Risk Score: {row['RISK_SCORE']}/10 | {row['RECOMMENDATION']}"):
                st.write(f"**Trigger:** {row['EDD_TRIGGER_REASON']}")
                st.write(f"**Known Risk Level:** {row['KNOWN_RISK_LEVEL'] or 'Unknown'}")
                st.write(f"**Summary:** {row['SUMMARY']}")
                st.write(f"**Risk Factors:** {row['RISK_FACTORS']}")

        # Senior review comparison
        st.subheader("Senior Review vs Maker Assessment")
        senior_df = session.sql("""
            SELECT applicant_name,
                   maker_assessment:risk_score::INT AS maker_score,
                   senior_review:senior_risk_score::INT AS senior_score,
                   senior_review:final_recommendation::VARCHAR AS senior_recommendation,
                   senior_review:checker_notes::VARCHAR AS senior_notes
            FROM KYC_SUPERHERO_DB.ANALYTICS.CHECKED_EDD
        """).to_pandas()

        if not senior_df.empty:
            st.dataframe(senior_df, use_container_width=True, hide_index=True)
    else:
        st.info("No EDD assessments generated - no high-risk entities detected.")
