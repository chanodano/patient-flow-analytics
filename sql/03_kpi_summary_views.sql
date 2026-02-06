CREATE OR REPLACE VIEW public.v_department_wait_summary AS
SELECT
  department_referral,
  COUNT(*) AS visits,
  ROUND(AVG(wait_time_min), 1) AS avg_wait_min,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY wait_time_min) AS median_wait_min,
  ROUND(
    100.0 * SUM(CASE WHEN wait_time_min > 15 THEN 1 ELSE 0 END) / COUNT(*),
    1
  ) AS pct_over_15_min
FROM public.v_patient_flow_kpi
GROUP BY department_referral;

