-- Grain: one row per pipeline run x fetched source x league. Global sources have league_key = 'global'.
WITH source AS (
    SELECT * FROM {{ source('fantasy_football', 'health_log') }}
),

renamed AS (
    SELECT
        run_id,
        slot AS run_slot,
        CAST(ts_utc AS TIMESTAMPTZ) AS fetched_at,
        source AS source_name,
        COALESCE(league_key, 'global') AS league_key,
        CAST(ok AS BOOLEAN) AS is_ok,
        CAST(http_status AS INTEGER) AS http_status,
        CAST(rows AS INTEGER) AS rows_fetched,
        CAST(rows_prev AS INTEGER) AS rows_previous,
        CAST(row_delta_pct AS DOUBLE) AS row_delta_pct,
        CAST(schema_ok AS BOOLEAN) AS is_schema_ok,
        level AS health_level,
        CAST(age_hours AS DOUBLE) AS upstream_age_hours,
        CAST(elapsed_s AS DOUBLE) AS elapsed_seconds,
        message,
    FROM source
)

SELECT * FROM renamed
