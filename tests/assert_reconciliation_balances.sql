-- Fails when the latest reconciliation shows a dropped or duplicated row, or a changed total,
-- between a source and its mart.
WITH latest AS (
    SELECT * FROM {{ ref('audit_reconciliation') }}
    WHERE checked_at = (SELECT MAX(checked_at) FROM {{ ref('audit_reconciliation') }})
)

SELECT
    table_name,
    source_rows,
    mart_rows,
    row_delta,
    source_sum,
    mart_sum,
    sum_delta,
FROM latest
WHERE row_delta <> 0
    OR ABS(COALESCE(sum_delta, 0)) > 1e-6
    OR (source_sum IS NULL) <> (mart_sum IS NULL)
