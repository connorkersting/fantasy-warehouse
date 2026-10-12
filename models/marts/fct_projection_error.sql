-- Grain: one row per league x season x week x snapshot slot x player x projection source.
WITH proj_error AS (
    SELECT * FROM {{ ref('stg_replay__proj_error') }}
)

SELECT
    league_key,
    season,
    week,
    snapshot_slot,
    player_key,
    projection_source,
    position,
    projected_pts,
    actual_pts,
    error_pts,
    ABS(error_pts) AS abs_error_pts,
    n_missing,
    n_no_actual,
FROM proj_error
