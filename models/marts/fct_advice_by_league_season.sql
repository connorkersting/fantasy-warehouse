-- Grain: one row per league x season x snapshot slot.
-- How the assistant's recommended lineups compare with the platform's lineup and with the hindsight optimum.
-- Every total and rate uses only "evaluable" weeks, where recommended, platform and hindsight points are
-- all known, so numerators and denominators come from the same weeks.
WITH outcomes AS (
    SELECT
        *,
        recommended_pts IS NOT NULL
            AND platform_pts IS NOT NULL
            AND hindsight_pts IS NOT NULL AS is_evaluable,
    FROM {{ ref('fct_lineup_outcome') }}
)

SELECT
    league_key,
    season,
    snapshot_slot,
    COUNT(*) AS n_weeks,
    CAST(COUNT_IF(is_evaluable) AS BIGINT) AS n_weeks_evaluable,  -- COUNT_IF returns HUGEINT
    SUM(recommended_pts) FILTER (WHERE is_evaluable) AS total_recommended_pts,
    SUM(platform_pts) FILTER (WHERE is_evaluable) AS total_platform_pts,
    SUM(hindsight_pts) FILTER (WHERE is_evaluable) AS total_hindsight_pts,
    SUM(recommended_pts - platform_pts) FILTER (WHERE is_evaluable) AS total_vs_platform_pts,
    AVG(recommended_pts - platform_pts) FILTER (WHERE is_evaluable) AS avg_vs_platform_pts,
    SUM(recommended_pts) FILTER (WHERE is_evaluable)
        / NULLIF(SUM(hindsight_pts) FILTER (WHERE is_evaluable), 0) AS hindsight_capture_rate,
    CAST(COUNT_IF(is_evaluable AND recommended_pts > platform_pts) AS BIGINT) AS n_weeks_beat_platform,
    CAST(COUNT_IF(is_evaluable AND recommended_pts < platform_pts) AS BIGINT) AS n_weeks_trailed_platform,
FROM outcomes
GROUP BY league_key, season, snapshot_slot
