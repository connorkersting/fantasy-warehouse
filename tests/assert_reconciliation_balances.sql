-- Fails unless THIS invocation logged a balanced reconciliation for all four marts: a row/sum delta, a
-- missing table, or no rows at all for this run (e.g. the audit model failed or was skipped) all fail.
-- Run it through `dbt build`: a standalone `dbt test` has a new invocation id with no audit rows, so it
-- fails by design rather than passing on an older run's evidence.
WITH expected_tables AS (
    SELECT table_name
    FROM (VALUES
        ('fct_lineup_outcome'),
        ('fct_projection_error'),
        ('fct_source_rank_accuracy'),
        ('fct_fetch_health')
    ) AS t (table_name)
),

this_run AS (
    SELECT * FROM {{ ref('audit_reconciliation') }}
    WHERE invocation_id = '{{ invocation_id }}'
)

SELECT
    e.table_name,
    r.source_rows,
    r.mart_rows,
    r.row_delta,
    r.source_sum,
    r.mart_sum,
    r.sum_delta,
    CASE
        WHEN r.table_name IS NULL THEN 'no reconciliation row for this invocation'
        WHEN r.row_delta <> 0 THEN 'row count mismatch'
        WHEN (r.source_sum IS NULL) <> (r.mart_sum IS NULL) THEN 'sum missing on one side'
        ELSE 'sum mismatch'
    END AS failure_reason,
FROM expected_tables AS e
LEFT JOIN this_run AS r
    ON e.table_name = r.table_name
WHERE r.table_name IS NULL
    OR r.row_delta <> 0
    OR (r.source_sum IS NULL) <> (r.mart_sum IS NULL)
    OR ABS(COALESCE(r.sum_delta, 0)) > 1e-6
