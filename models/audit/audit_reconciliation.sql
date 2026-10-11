{{ config(unique_key=['invocation_id', 'table_name']) }}
-- Grain: one row per dbt invocation x reconciled table. Incremental with a unique key, so every run
-- appends its numbers (a rerun of the same invocation replaces its own rows) and the history stays
-- queryable. Compares the raw source with the mart on row count and on a summed measure: counts can
-- match while values are wrong.
WITH lineups_src AS (
    SELECT
        COUNT(*) AS n_rows,
        SUM(CAST(recommended_pts AS DOUBLE)) AS total,
    FROM {{ source('fantasy_season', 'replay_lineups') }}
),

lineups_mart AS (
    SELECT
        COUNT(*) AS n_rows,
        SUM(recommended_pts) AS total,
    FROM {{ ref('fct_lineup_outcome') }}
),

errors_src AS (
    SELECT
        COUNT(*) AS n_rows,
        SUM(CAST(error AS DOUBLE)) AS total,
    FROM {{ source('fantasy_season', 'replay_proj_error') }}
),

errors_mart AS (
    SELECT
        COUNT(*) AS n_rows,
        SUM(error_pts) AS total,
    FROM {{ ref('fct_projection_error') }}
),

ranks_src AS (
    SELECT
        COUNT(*) AS n_rows,
        SUM(CAST(n AS DOUBLE)) AS total,
    FROM {{ source('fantasy_season', 'replay_rank_accuracy') }}
),

ranks_mart AS (
    SELECT
        COUNT(*) AS n_rows,
        SUM(n_players) AS total,
    FROM {{ ref('fct_source_rank_accuracy') }}
),

health_src AS (
    SELECT
        COUNT(*) AS n_rows,
        SUM(CAST(rows AS DOUBLE)) AS total,
    FROM {{ source('fantasy_season', 'health_log') }}
),

health_mart AS (
    SELECT
        COUNT(*) AS n_rows,
        SUM(rows_fetched) AS total,
    FROM {{ ref('fct_fetch_health') }}
),

checks AS (
    SELECT 'fct_lineup_outcome' AS table_name, 'recommended_pts' AS summed_column, s.n_rows AS source_rows,
        m.n_rows AS mart_rows, s.total AS source_sum, m.total AS mart_sum,
    FROM lineups_src AS s CROSS JOIN lineups_mart AS m
    UNION ALL
    SELECT 'fct_projection_error', 'error_pts', s.n_rows, m.n_rows, s.total, m.total,
    FROM errors_src AS s CROSS JOIN errors_mart AS m
    UNION ALL
    SELECT 'fct_source_rank_accuracy', 'n_players', s.n_rows, m.n_rows, s.total, m.total,
    FROM ranks_src AS s CROSS JOIN ranks_mart AS m
    UNION ALL
    SELECT 'fct_fetch_health', 'rows_fetched', s.n_rows, m.n_rows, s.total, m.total,
    FROM health_src AS s CROSS JOIN health_mart AS m
)

SELECT
    '{{ invocation_id }}' AS invocation_id,
    CAST('{{ run_started_at }}' AS TIMESTAMPTZ) AS checked_at,
    table_name,
    summed_column,
    source_rows,
    mart_rows,
    mart_rows - source_rows AS row_delta,
    source_sum,
    mart_sum,
    CAST(mart_sum AS DOUBLE) - CAST(source_sum AS DOUBLE) AS sum_delta,
FROM checks
