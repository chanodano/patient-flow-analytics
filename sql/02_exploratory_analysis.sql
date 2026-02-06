#basic sanity checks

create or replace view public.v_patient_flow_clean as 
select   "Patient Id"                       AS patient_id,
  "Patient Admission Date"           AS admission_date_raw,
  "Patient Admission Time"           AS admission_time_raw,
  "Merged"                           AS merged,
  "Patient Gender"                   AS gender,
  "Patient Age"                      AS age,
  "Patient Race"                     AS race,
  "Department Referral"              AS department_referral,
  "Patient Admission Flag"           AS admission_flag,
  "Patient Satisfaction Score"       AS satisfaction_score,
  "Patient Waittime"                 AS wait_time_min
FROM public.patient_flow;

select * from public.v_patient_flow_clean
limit 10;

-- TASK 1 identify which department and times of day has the longest waiting time

select 
	count(*) as visits,
	round(avg(wait_time_min),1) as avg_wait_min,
	percentile_cont(0.5) within group (order by wait_time_min) as median_wait_min,
	max (wait_time_min) as max_wait_min
from public.v_patient_flow_kpi;

-- total 9216 visits, average wait time 35.3, median wait time 35m max wait time 60 min. This is the baseline.

-- so which departments are the bottlenecks?

select 
	department_referral,
	count(*) as visits,
	round(avg(wait_time_min),1) as avg_wait_min,
	percentile_cont(0.5) within group (order by wait_time_min) as median_wait_min,
	max (wait_time_min) as max_wait_min
FROM public.v_patient_flow_kpi
GROUP BY department_referral
ORDER BY avg_wait_min DESC;

---- no particular departments have high wait times and volume

-- What about time of day?
SELECT
  admission_hour,
  COUNT(*) AS visits,
  ROUND(AVG(wait_time_min), 1) AS avg_wait_min
FROM public.v_patient_flow_kpi
GROUP BY admission_hour
ORDER BY admission_hour;

-- no observable pattern

-- combine both

-- Department x hour heatmap-style table
SELECT
  department_referral,
  admission_hour,
  COUNT(*) AS visits,
  ROUND(AVG(wait_time_min), 1) AS avg_wait_min
FROM public.v_patient_flow_kpi
GROUP BY department_referral, admission_hour
ORDER BY department_referral, admission_hour;

--- department x hour breach SLA table. assume SLA 40 mins
SELECT
  department_referral,
  COUNT(*) AS visits,
  SUM(CASE WHEN wait_time_min > 30 THEN 1 ELSE 0 END) AS breaches,
  ROUND(
    100.0 * SUM(CASE WHEN wait_time_min > 40 THEN 1 ELSE 0 END) / COUNT(*),
    1
  ) AS breach_rate_pct
FROM public.v_patient_flow_kpi
GROUP BY department_referral
ORDER BY breach_rate_pct DESC;

-- Insight: neurology & physiotherapy has less visits but breaches 40 mins
-- GP has overhwleming number of referalls

-- layer in satisfactions scores & wait time in buckets

SELECT
  CASE
    WHEN wait_time_min <= 15 THEN '0–15 min'
    WHEN wait_time_min <= 30 THEN '16–30 min'
    WHEN wait_time_min <= 45 THEN '31–45 min'
    when wait_time_min <= 60 then '45-60 min'
    ELSE '60+ min'
  END AS wait_bucket,
  COUNT(*) AS visits,
  ROUND(AVG(satisfaction_score), 2) AS avg_satisfaction
FROM public.v_patient_flow_kpi
GROUP BY wait_bucket
ORDER BY wait_bucket;

-- Does longer waiting actually correlate with poorer patient experience? Not in this case
-- However, PS drops significantly once wait times >15 mins, but not with longer waits. Hence, hops should manage expectations after that critical weight threshold
-- which could be as important as reducing wait duration as well.

SELECT
  department_referral,
  CASE
    WHEN wait_time_min <= 15 THEN '0–15'
    WHEN wait_time_min <= 30 THEN '16–30'
    WHEN wait_time_min <= 45 THEN '31–45'
    ELSE '45–60'
  END AS wait_bucket,
  COUNT(*) AS visits,
  ROUND(AVG(satisfaction_score), 2) AS avg_satisfaction
FROM public.v_patient_flow_kpi
GROUP BY department_referral, wait_bucket
ORDER BY department_referral, wait_bucket;

-- Gasto has extremely low PS for short waits (<15 mins) but PS increases with time --> better explanations? higher value?
-- Renal has extremely high PS for short waits (<15 mins). Perhaps Gastro can cross learn from Renal on client referal process. (Small sample size though)
-- Neurology PS drops sharply after 45 mins

select admission_time_raw, count (*)
from public.v_patient_flow_clean
group by admission_time_raw
order by count(*) desc
limit 5;

SELECT admission_date_raw, COUNT(*) 
FROM public.v_patient_flow_clean
GROUP BY admission_date_raw
ORDER BY COUNT(*) DESC
LIMIT 5;


-- data stores dates and times as text, so parse  them into proper timestamps
CREATE OR REPLACE VIEW public.v_patient_flow_ts AS
SELECT
  *,
  to_date(admission_date_raw, 'DD/MM/YYYY') AS admission_date,
  (
    to_date(admission_date_raw, 'DD/MM/YYYY')
    + to_timestamp(admission_time_raw, 'HH12:MI:SS AM')::time
  )::timestamp AS admission_ts
FROM public.v_patient_flow_clean;

CREATE OR REPLACE VIEW public.v_patient_flow_kpi AS
SELECT
  *,
  date_trunc('day', admission_ts) AS admission_day,
  EXTRACT(HOUR FROM admission_ts) AS admission_hour,  -- 0–23
  to_char(admission_ts, 'Dy') AS admission_dow
FROM public.v_patient_flow_ts;


select * from public.v_patient_flow_ts
limit 10;


SELECT
  department_referral,
  ROUND(AVG(wait_time_min), 1) AS avg_wait,
  ROUND(STDDEV(wait_time_min), 1) AS wait_variability
FROM public.v_patient_flow_kpi
GROUP BY department_referral
ORDER BY wait_variability DESC;

-- Pretty consistent variability across departments


SELECT
  CASE
    WHEN age < 30 THEN '<30'
    WHEN age < 50 THEN '30–49'
    WHEN age < 70 THEN '50–69'
    ELSE '70+'
  END AS age_group,
  COUNT(*) AS visits,
  ROUND(AVG(wait_time_min), 1) AS avg_wait
FROM public.v_patient_flow_kpi
GROUP BY age_group
ORDER BY age_group;

-- no difference in wait time by age

-- to explore when do the GP cases (more than 50%) put pressure on the system
-- GP arrivals by hour
SELECT
  admission_hour,
  COUNT(*) AS visits,
  ROUND(AVG(wait_time_min), 1) AS avg_wait_min,
  PERCENTILE_CONT(0.5) 
    WITHIN GROUP (ORDER BY wait_time_min) AS median_wait_min
FROM public.v_patient_flow_kpi
WHERE department_referral = 'General Practice'
GROUP BY admission_hour
ORDER BY admission_hour;

-- no evidence that peak volume causes peak waits
-- modest increases during late night/early morning and late evening --> issue is not demand dependent
-- next, compare GP vs non-GP by hour to see if GP causes the main issue

SELECT
  admission_hour,
  COUNT(*) FILTER (WHERE department_referral = 'General Practice') AS gp_visits,
  ROUND(AVG(wait_time_min) FILTER (WHERE department_referral = 'General Practice'), 1) AS gp_avg_wait,
  ROUND(AVG(wait_time_min) FILTER (WHERE department_referral <> 'General Practice'), 1) AS non_gp_avg_wait,
  Round(AVG(wait_time_min) FILTER (WHERE department_referral = 'General Practice') - AVG(wait_time_min) FILTER (WHERE department_referral <> 'General Practice'), 1 ) as gp_difference
FROM public.v_patient_flow_kpi
GROUP BY admission_hour
ORDER BY admission_hour;


-- gp wait tends to be broadly similar to non-gp, with exception of certain hours (10-12pm, 3-4 am and 11-13, perhaps during their lunch breaks?) 
-- There are also times where GPs are faster
-- hence GP, despite being the most number of cases, is not the main bottleneck
-- rather, there are system limitations





