# Patient Flow & Wait Time Analysis

Operational analysis of patient flow data to understand system-wide wait times, General Practice (GP) demand, and their impact on patient satisfaction.

---

## Objective
Analyse patient flow data to identify operational drivers of wait times and assess how waiting duration affects patient experience.

---

## Tools
- **PostgreSQL** — data cleaning, transformation, and KPI logic  
- **Tableau** — exploratory visualisation and dashboarding  

---

## Key Findings
- Wait times are elevated across departments, indicating **system-wide throughput constraints** rather than isolated bottlenecks.
- General Practice accounts for the largest share of visits but does **not consistently experience longer waits** than non-GP departments.
- Patient satisfaction drops sharply once waits exceed **15 minutes**, with limited additional decline thereafter.

These findings suggest that expectation management may be as impactful as reducing absolute wait times.

---

## Dashboard
![Patient Flow Dashboard](dashboard/patient_flow_dashboard.png)

---

## Files
- `/sql/`
  - `01_data_cleaning.sql` — data preparation and sanity checks  
  - `02_exploratory_analysis.sql` — departmental, temporal, and satisfaction analysis  
  - `03_kpi_summary_views.sql` — final KPI views used for visualisation  
- `/dashboard/` — Tableau dashboard export  

The SQL workflow is intentionally split into cleaning, exploration, and summarisation to reflect a typical analytics pipeline.

---

## Data Source
Publicly available **synthetic healthcare operations dataset** from Kaggle:  
https://www.kaggle.com/datasets/hassanjameelahmed/healthcare-analytics-patient-flow-data

The dataset is simulated and anonymised for educational and analytical purposes. All findings are illustrative and do not represent any real healthcare institution or patient population.
