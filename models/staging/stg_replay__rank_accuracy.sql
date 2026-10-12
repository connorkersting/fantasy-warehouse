-- Grain: one row per league x season x week x snapshot slot x position x projection source.
WITH source AS (
    SELECT * FROM {{ source('fantasy_football', 'replay_rank_accuracy') }}
),

renamed AS (
    SELECT
        CAST(season AS INTEGER) AS season,
        CAST(week AS INTEGER) AS week,
        league AS league_key,
        slot AS snapshot_slot,
        pos AS position,
        source AS projection_source,
        CAST(rho AS DOUBLE) AS spearman_rho,
        CAST(n AS INTEGER) AS n_players,
    FROM source
)

SELECT * FROM renamed
