-- Grain: one row per player_key (gsis:, espn:, sleeper:, name: or dst: prefix).
-- Name, position and team come from the most recent roster snapshot that contains the player;
-- players seen only in replay projection errors (not on my roster snapshots) keep their position, no name.
WITH roster AS (
    SELECT * FROM {{ ref('stg_snapshots__roster') }}
),

proj_error AS (
    SELECT * FROM {{ ref('stg_replay__proj_error') }}
),

latest_roster_row AS (
    SELECT
        player_key,
        player_name,
        position,
        pro_team,
        season,
        week,
    FROM roster
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY player_key
        ORDER BY season DESC, week DESC, snapshot_slot
    ) = 1
),

replay_only_players AS (
    SELECT
        player_key,
        ANY_VALUE(position) AS position,
    FROM proj_error
    WHERE player_key NOT IN (SELECT player_key FROM latest_roster_row)
    GROUP BY player_key
),

players AS (
    SELECT
        player_key,
        player_name,
        position,
        pro_team,
        season AS last_seen_season,
        week AS last_seen_week,
        TRUE AS is_on_roster_snapshot,
    FROM latest_roster_row
    UNION ALL
    SELECT
        player_key,
        NULL AS player_name,
        position,
        NULL AS pro_team,
        NULL AS last_seen_season,
        NULL AS last_seen_week,
        FALSE AS is_on_roster_snapshot,
    FROM replay_only_players
)

SELECT
    player_key,
    split_part(player_key, ':', 1) AS player_key_type,
    player_name,
    position,
    pro_team,
    CAST(last_seen_season AS INTEGER) AS last_seen_season,
    CAST(last_seen_week AS INTEGER) AS last_seen_week,
    is_on_roster_snapshot,
FROM players
