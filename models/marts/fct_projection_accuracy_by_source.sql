-- Grain: one row per projection source x position (all leagues and weeks pooled).
-- Which projection source is most accurate, measured on players whose games finished. Error is derived
-- here as actual - projected, so every counted row also feeds MAE and RMSE; the upstream error column is
-- checked against it by tests/assert_upstream_error_matches_derived.sql.
WITH errors AS (
    SELECT
        projection_source,
        position,
        player_key,
        season,
        week,
        actual_pts - projected_pts AS derived_error_pts,
    FROM {{ ref('fct_projection_error') }}
    WHERE actual_pts IS NOT NULL
        AND projected_pts IS NOT NULL
)

SELECT
    projection_source,
    position,
    COUNT(*) AS n_projections,
    COUNT(DISTINCT player_key) AS n_players,
    COUNT(DISTINCT (season, week)) AS n_weeks,
    AVG(ABS(derived_error_pts)) AS mae_pts,
    AVG(derived_error_pts) AS mean_error_pts,
    SQRT(AVG(derived_error_pts * derived_error_pts)) AS rmse_pts,
FROM errors
GROUP BY projection_source, position
