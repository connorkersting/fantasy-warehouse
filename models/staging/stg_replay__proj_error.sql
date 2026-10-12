-- Grain: one row per league x season x week x snapshot slot x player x projection source.
WITH source AS (
    SELECT * FROM {{ source('fantasy_football', 'replay_proj_error') }}
),

renamed AS (
    SELECT
        CAST(season AS INTEGER) AS season,
        CAST(week AS INTEGER) AS week,
        league AS league_key,
        slot AS snapshot_slot,
        player_key,
        pos AS position,
        source AS projection_source,
        CAST(proj AS DOUBLE) AS projected_pts,
        CAST(actual AS DOUBLE) AS actual_pts,
        CAST(error AS DOUBLE) AS error_pts,
        CAST(n_missing AS INTEGER) AS n_missing,
        CAST(n_no_actual AS INTEGER) AS n_no_actual,
    FROM source
)

SELECT * FROM renamed
