-- Grain: one row per league x season x week x snapshot slot x player (my roster at decision time).
-- Season, week, slot and league are parsed from the file path:
-- state/snapshots/<season>/w<week>/<slot>/<league>/roster.csv
WITH source AS (
    SELECT * FROM {{ source('fantasy_football', 'snapshot_roster') }}
),

with_path AS (
    SELECT
        *,
        regexp_extract(
            replace(filename, '\', '/'),
            'snapshots/(\d+)/w(\d+)/([^/]+)/([^/]+)/roster\.csv$',
            ['season', 'week', 'snapshot_slot', 'league_key']
        ) AS path_parts,
    FROM source
),

renamed AS (
    SELECT
        CAST(path_parts.season AS INTEGER) AS season,
        CAST(path_parts.week AS INTEGER) AS week,
        path_parts.league_key AS league_key,
        path_parts.snapshot_slot AS snapshot_slot,
        player_key,
        player_name,
        pos AS position,
        pro_team,
        current_slot AS lineup_slot,
        CAST(proj AS DOUBLE) AS projected_pts,
        CAST(proj_ros AS DOUBLE) AS projected_ros_pts,
        CAST(p_play AS DOUBLE) AS play_probability,
        status AS injury_status,
        CAST(exp AS DOUBLE) AS expected_pts,
        CAST(kickoff AS TIMESTAMP) AS kickoff_at,
        CAST(proj_cbs AS DOUBLE) AS projected_pts_cbs,
        CAST(proj_espn AS DOUBLE) AS projected_pts_espn,
        CAST(ecr_rank AS DOUBLE) AS ecr_rank,
        CAST(ecr_std AS DOUBLE) AS ecr_rank_std,
    FROM with_path
)

SELECT * FROM renamed
