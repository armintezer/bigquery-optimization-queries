-- This query will show the count of concurrent jobs broken down by seconds
DECLARE interval_in_days INT64 DEFAULT 7;

BEGIN
WITH src AS
(
SELECT
      protopayload_auditlog.authenticationInfo.principalEmail AS user_email,
        protopayload_auditlog.servicedata_v1_bigquery.jobCompletedEvent.job.jobName.jobId,
        DATETIME_TRUNC(protopayload_auditlog.servicedata_v1_bigquery.jobCompletedEvent.job.jobStatistics.startTime, SECOND) AS startTime,
        DATETIME_TRUNC(protopayload_auditlog.servicedata_v1_bigquery.jobCompletedEvent.job.jobStatistics.endTime, SECOND) AS endTime,
        TIMESTAMP_DIFF(protopayload_auditlog.servicedata_v1_bigquery.jobCompletedEvent.job.jobStatistics.endTime,
                       protopayload_auditlog.servicedata_v1_bigquery.jobCompletedEvent.job.jobStatistics.startTime,
                       MINUTE) AS diff
    FROM
      `<project>.<dataset>.cloudaudit_googleapis_com_data_access`
    WHERE
      protopayload_auditlog.servicedata_v1_bigquery.jobCompletedEvent.job.jobName.jobId IS NOT NULL
      AND protopayload_auditlog.servicedata_v1_bigquery.jobCompletedEvent.job.jobName.jobId NOT LIKE 'script_job_%' -- filter BQ script child jobs
      AND protopayload_auditlog.servicedata_v1_bigquery.jobCompletedEvent.eventName LIKE 'query_job_completed'
      AND protopayload_auditlog.authenticationInfo.principalEmail IS NOT NULL
      AND protopayload_auditlog.authenticationInfo.principalEmail != ""
      AND DATE(protopayload_auditlog.servicedata_v1_bigquery.jobCompletedEvent.job.jobStatistics.startTime) >= DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
      AND protopayload_auditlog.servicedata_v1_bigquery.jobCompletedEvent.job.jobConfiguration.dryRun IS NULL
      AND protopayload_auditlog.servicedata_v1_bigquery.jobCompletedEvent.job.jobName.projectId IS NOT NULL
      AND DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL interval_in_days DAY)
),
differences AS
(
  SELECT *,
  generate_timestamp_array(startTime, endTime, INTERVAL 1 SECOND) AS int
  FROM src
),
bySeconds AS
(
  SELECT *
  FROM differences,
    UNNEST(int) AS second
)

SELECT COUNT(*) AS jobCounter, second
FROM bySeconds
GROUP BY second
ORDER BY second ASC;
END