-- Grain: one row per league x season x snapshot slot.
-- How the assistant's recommended lineups compare with the platform's lineup and with the hindsight optimum.
WITH outcomes AS (
    SELECT * FROM {{ ref('fct_lineup_outcome') }}
)

SELECT
    league_key,
    season,
    snapshot_slot,
    COUNT(*) AS n_weeks,
    SUM(recommended_pts) AS total_recommended_pts,
    SUM(platform_pts) AS total_platform_pts,
    SUM(hindsight_pts) AS total_hindsight_pts,
    SUM(vs_platform_pts) AS total_vs_platform_pts,
    AVG(vs_platform_pts) AS avg_vs_platform_pts,
    SUM(recommended_pts) / NULLIF(SUM(hindsight_pts), 0) AS hindsight_capture_rate,
    CAST(COUNT_IF(vs_platform_pts > 0) AS BIGINT) AS n_weeks_beat_platform,  -- COUNT_IF returns HUGEINT
    CAST(COUNT_IF(vs_platform_pts < 0) AS BIGINT) AS n_weeks_trailed_platform,
FROM outcomes
GROUP BY league_key, season, snapshot_slot
