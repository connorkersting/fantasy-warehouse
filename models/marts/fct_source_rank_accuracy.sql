-- Grain: one row per league x season x week x snapshot slot x position x projection source.
WITH rank_accuracy AS (
    SELECT * FROM {{ ref('stg_replay__rank_accuracy') }}
)

SELECT
    league_key,
    season,
    week,
    snapshot_slot,
    position,
    projection_source,
    spearman_rho,
    n_players,
FROM rank_accuracy
