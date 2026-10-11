{#- Grain test without a package dependency: fails on any duplicate combination of the listed columns. -#}
{% test unique_combination_of_columns(model, combination_of_columns) %}

SELECT
    {{ combination_of_columns | join(',\n    ') }},
    COUNT(*) AS n_rows,
FROM {{ model }}
GROUP BY ALL
HAVING COUNT(*) > 1

{% endtest %}
