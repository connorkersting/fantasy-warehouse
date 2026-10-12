{#- Root of the upstream checkout, with apostrophes escaped for use inside a SQL string literal. -#}
{% macro fantasy_season_root() -%}
{{ env_var('FANTASY_SEASON_DIR', '../fantasy-season') | replace("'", "''") }}
{%- endmacro %}


{#-
Schema contract for one upstream source. Attached to each source separately, so the source is the test's
only dbt parent and a failure skips that source's descendants in `dbt build`. The contract is read from
contracts/source_columns.csv with read_csv, not ref(), which would add a second parent.

Fails, naming the source, file, column, what was expected and what arrived, on:
  - a new, dropped or retyped column in the combined read;
  - any single file whose header (names and order) differs from the contract, which union_by_name would
    otherwise hide by filling the missing column with NULLs;
  - no files matching the glob.
Re-pin deliberately with scripts/pin_source_schema.py after reviewing a real upstream change.
-#}
{% test matches_source_contract(model, contract_name, file_glob) %}

WITH contract AS (
    SELECT
        CAST(ordinal AS INTEGER) AS ordinal,
        column_name,
        column_type,
    FROM read_csv('contracts/source_columns.csv', header=true, all_varchar=true)
    WHERE source_table = '{{ contract_name }}'
),

actual AS (
    SELECT
        column_name,
        column_type,
    FROM (DESCRIBE SELECT * FROM {{ model }})
),

column_drift AS (
    SELECT
        '{{ contract_name }}' AS source_table,
        CAST(NULL AS VARCHAR) AS file_name,
        COALESCE(c.column_name, a.column_name) AS column_name,
        c.column_type AS expected,
        a.column_type AS arrived,
        CASE
            WHEN a.column_name IS NULL THEN 'dropped column'
            WHEN c.column_name IS NULL THEN 'new column'
            ELSE 'type changed'
        END AS drift_kind,
    FROM contract AS c
    FULL OUTER JOIN actual AS a
        ON c.column_name = a.column_name
    WHERE c.column_name IS NULL
        OR a.column_name IS NULL
        OR c.column_type <> a.column_type
),

expected_header AS (
    SELECT
        string_agg(column_name, ',' ORDER BY ordinal) AS header,
    FROM contract
    WHERE column_name <> 'filename'
),

file_headers AS (
    SELECT
        filename AS file_name,
        replace(replace(split_part(content, chr(10), 1), chr(13), ''), '"', '') AS header,
    FROM read_text('{{ fantasy_season_root() }}/{{ file_glob }}')
),

header_drift AS (
    SELECT
        '{{ contract_name }}' AS source_table,
        f.file_name,
        CAST(NULL AS VARCHAR) AS column_name,
        e.header AS expected,
        f.header AS arrived,
        'file header differs' AS drift_kind,
    FROM file_headers AS f
    CROSS JOIN expected_header AS e
    WHERE f.header <> e.header
),

no_files AS (
    SELECT
        '{{ contract_name }}' AS source_table,
        CAST(NULL AS VARCHAR) AS file_name,
        CAST(NULL AS VARCHAR) AS column_name,
        'at least one file' AS expected,
        '0 files' AS arrived,
        'no files matched' AS drift_kind,
    WHERE NOT EXISTS (SELECT 1 FROM file_headers)
)

SELECT * FROM column_drift
UNION ALL
SELECT * FROM header_drift
UNION ALL
SELECT * FROM no_files

{% endtest %}
