-- Schema contract for sources we don't control. Fails, and stops downstream models in `dbt build`,
-- on any upstream drift: a new column, a dropped column, or a changed type. Each failing row names
-- the source, the column, what was expected and what arrived. After reviewing a real change,
-- re-pin deliberately with scripts/pin_source_schema.py.
WITH expected AS (
    SELECT
        source_table,
        column_name,
        column_type,
    FROM {{ ref('expected_source_columns') }}
),

actual AS (
    {% for table in ['replay_lineups', 'replay_proj_error', 'replay_rank_accuracy', 'health_log', 'snapshot_roster'] %}
    SELECT
        '{{ table }}' AS source_table,
        column_name,
        column_type,
    FROM (DESCRIBE SELECT * FROM {{ source('fantasy_season', table) }})
    {% if not loop.last %}UNION ALL{% endif %}
    {% endfor %}
),

drift AS (
    SELECT
        COALESCE(e.source_table, a.source_table) AS source_table,
        COALESCE(e.column_name, a.column_name) AS column_name,
        e.column_type AS expected_type,
        a.column_type AS arrived_type,
        CASE
            WHEN a.column_name IS NULL THEN 'dropped column'
            WHEN e.column_name IS NULL THEN 'new column'
            ELSE 'type changed'
        END AS drift_kind,
    FROM expected AS e
    FULL OUTER JOIN actual AS a
        ON e.source_table = a.source_table
        AND e.column_name = a.column_name
    WHERE e.column_name IS NULL
        OR a.column_name IS NULL
        OR e.column_type <> a.column_type
)

SELECT * FROM drift
