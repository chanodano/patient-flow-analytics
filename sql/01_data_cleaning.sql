SELECT schemaname, tablename
FROM pg_tables
WHERE schemaname IN ('public')
ORDER BY tablename;

select count(*) 
from public.healthcare_analytics_patient_flow_data

ALTER TABLE public.healthcare_analytics_patient_flow_data
RENAME TO patient_flow;

select *
from patient_flow
limit 10;

select column_name, data_type
from information_schema."columns" c
where table_name = 'patient_flow'
order by ordinal_position;
