-- Grain: one row per pipeline run x fetched source x league ('global' for league-independent sources).
WITH fetch_log AS (
    SELECT * FROM {{ ref('stg_health__fetch_log') }}
)

SELECT
    run_id,
    source_name,
    league_key,
    run_slot,
    fetched_at,
    CAST(fetched_at AS DATE) AS fetch_date,
    is_ok,
    is_schema_ok,
    health_level,
    http_status,
    rows_fetched,
    rows_previous,
    row_delta_pct,
    upstream_age_hours,
    elapsed_seconds,
FROM fetch_log
