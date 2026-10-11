-- Grain: one row per league. From the leagues seed (mirrors fantasy-season config/leagues.yml).
WITH leagues AS (
    SELECT * FROM {{ ref('leagues') }}
)

SELECT
    league_key,
    league_name,
    platform,
    is_enabled,
FROM leagues
