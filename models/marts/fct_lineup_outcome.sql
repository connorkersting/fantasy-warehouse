-- Grain: one row per league x season x week x snapshot slot (one lineup decision, scored after the games).
WITH lineups AS (
    SELECT * FROM {{ ref('stg_replay__lineups') }}
)

SELECT
    league_key,
    season,
    week,
    snapshot_slot,
    recommended_pts,
    platform_pts,
    hindsight_pts,
    baseline_pts,
    points_left_on_bench,
    vs_platform_pts,
    baseline_gap_pts,
    recommended_pts / NULLIF(hindsight_pts, 0) AS hindsight_capture_rate,
    n_missing,
    n_platform_missing,
    n_illegal,
FROM lineups
