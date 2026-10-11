-- Grain: one row per projection source x position (all leagues and weeks pooled).
-- Which projection source is most accurate, measured on players whose games finished.
WITH errors AS (
    SELECT * FROM {{ ref('fct_projection_error') }}
    WHERE actual_pts IS NOT NULL
      AND projected_pts IS NOT NULL
)

SELECT
    projection_source,
    position,
    COUNT(*) AS n_projections,
    COUNT(DISTINCT player_key) AS n_players,
    COUNT(DISTINCT (season, week)) AS n_weeks,
    AVG(abs_error_pts) AS mae_pts,
    AVG(error_pts) AS mean_error_pts,
    SQRT(AVG(error_pts * error_pts)) AS rmse_pts,
FROM errors
GROUP BY projection_source, position
