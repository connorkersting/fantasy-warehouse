-- Upstream error must equal actual - projected wherever both points are known (and must not be missing
-- there). Catches an upstream sign flip, a stale error column, or a NULL error on a scoreable row.
SELECT
    league_key,
    season,
    week,
    snapshot_slot,
    player_key,
    projection_source,
    projected_pts,
    actual_pts,
    error_pts,
    actual_pts - projected_pts AS derived_error_pts,
FROM {{ ref('stg_replay__proj_error') }}
WHERE actual_pts IS NOT NULL
    AND projected_pts IS NOT NULL
    AND (error_pts IS NULL OR ABS(error_pts - (actual_pts - projected_pts)) > 1e-6)
