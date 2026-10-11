-- Grain: one row per league x season x week x snapshot slot (one replayed lineup decision).
WITH source AS (
    SELECT * FROM {{ source('fantasy_season', 'replay_lineups') }}
),

renamed AS (
    SELECT
        CAST(season AS INTEGER) AS season,
        CAST(week AS INTEGER) AS week,
        league AS league_key,
        slot AS snapshot_slot,
        CAST(recommended_pts AS DOUBLE) AS recommended_pts,
        CAST(platform_pts AS DOUBLE) AS platform_pts,
        CAST(hindsight_pts AS DOUBLE) AS hindsight_pts,
        CAST(baseline_pts AS DOUBLE) AS baseline_pts,
        CAST(points_left_on_bench AS DOUBLE) AS points_left_on_bench,
        CAST(vs_platform AS DOUBLE) AS vs_platform_pts,
        CAST(baseline_gap AS DOUBLE) AS baseline_gap_pts,
        CAST(n_missing AS INTEGER) AS n_missing,
        CAST(n_platform_missing AS INTEGER) AS n_platform_missing,
        CAST(n_illegal AS INTEGER) AS n_illegal,
    FROM source
)

SELECT * FROM renamed
