# fantasy-warehouse

A tested DuckDB + dbt warehouse over the outputs of a scheduled fantasy-football assistant, answering two
questions the assistant's own reports can't: **which projection source is actually most accurate**, and
**does the assistant's lineup advice beat the platform's default lineup**.

## Problem

The upstream project (fantasy-season, an R pipeline on a GitHub Actions schedule, 4 leagues, ~11 runs a
week) writes its results as hundreds of CSV and JSON files: decision snapshots, replayed lineups scored after
the games, projection errors, rank accuracy, and a fetch health log. Each run overwrites `latest.*` files, so
there was no queryable history, no cross-week accuracy view, and no check that the files keep the shape the
code expects. Schema contracts existed for only one of its sources.

## Approach

- **Read in place, never copy.** dbt-duckdb reads the CSVs straight from the upstream repo through
  `read_csv` sources (`FANTASY_SEASON_DIR`). The upstream data includes private league payloads and licensed
  rankings, so none of it is committed here.
- **Layers:** 5 `stg_` views (rename and cast only, grain stated in each file), then 2 `dim_` and 6 `fct_`
  tables. Two of the facts are aggregates that answer the questions above.
- **Data-quality rules, enforced in the build:**
  - Every model declares its grain and tests it (unique + not_null). Marts also test every foreign key
    (`relationships`) and every enum column (`accepted_values`).
  - **Enforced dbt contracts** pin each mart's output columns and types.
  - **Source schema contract:** every upstream column and type is pinned in
    `seeds/expected_source_columns.csv` (72 columns, 5 sources). `tests/assert_source_columns_match_contract.sql`
    fails on a new, dropped or retyped column, names the source, the column, what was expected and what
    arrived, and `dbt build` then skips everything downstream.
  - **Reconciliation:** `audit_reconciliation` (incremental, unique key = invocation x table) logs source vs
    mart row counts and a summed measure on every run; a test fails on any delta.
  - **Freshness** on the health log (warn after 26 h, error after 72 h; the pipeline runs daily).
- **Idempotent:** marts are full rebuilds; the only incremental model has a real `unique_key`.

## Results (data through week 4 of 2026, snapshot 2026-10-11)

`dbt build`: **113 nodes, all pass**. Rerun on the same data: byte-identical marts.

**Guard rails, tested by breaking the data on purpose** (a copy with an extra upstream column and one
duplicated row): the build failed on the contract test (`health_log.new_col: expected none, arrived VARCHAR,
new column`) and on the source grain test, and skipped all 27 downstream nodes.

**Projection accuracy** (`fct_projection_accuracy_by_source`, 553 player-weeks with finished games):

| Source | Projections | MAE (pts) | Mean error (pts) |
|---|---|---|---|
| ESPN | 192 | **5.59** | -0.61 |
| Consensus blend | 193 | 5.69 | -0.71 |
| CBS | 168 | 6.02 | -0.66 |

ESPN is the most accurate source overall and at WR and TE, but **CBS is best at QB and RB** (QB MAE 7.58 vs
ESPN 8.23). Every source over-projects on average (negative mean error). For *ranking* players, the blend
is best (mean Spearman rho 0.58, vs ECR 0.54, ESPN 0.53 and CBS 0.49; 26 position-weeks each).

**Lineup advice vs the platform** (`fct_advice_by_league_season`): across 13 replayed decisions the
recommended lineup **never beat** the platform's default lineup. It tied in 11 and trailed in 2
(-19.4 pts in one league over 3 early-slot weeks, -10.5 in one week of a disbanded league). It captured 86–96%
of the hindsight-optimal points. That's a useful negative result: so far the advice adds no measurable edge
over the platform default, which points work at the projections rather than the optimizer.

**Pipeline health** (`fct_fetch_health`, 2,865 fetches): 92.3% green, 7.6% yellow, 1 red.

## Limits

- Small samples: 4 weeks, 13 lineup decisions, 12–73 projections per position. Treat the accuracy ranking as
  provisional, especially at QB, K and DST.
- `.json.gz` and `.rds` caches (league payloads, nflverse tables) aren't modeled yet; this version covers
  the CSV outputs.
- Upstream types are auto-detected by DuckDB. If a column is all-missing in a future week, its detected type
  can change and trip the contract test: that's intended (look, then re-pin deliberately).

## Run it

Requires [uv](https://docs.astral.sh/uv/) and a checkout of fantasy-season next to this repo (or set
`FANTASY_SEASON_DIR`).

```bash
uv sync
uv run dbt build                  # seeds, sources tests, models, contracts, reconciliation
uv run dbt source freshness       # health-log freshness
uv run python scripts/profile_sources.py    # grain and enum profile of the sources
uv run python scripts/pin_source_schema.py  # re-pin the source contract (deliberately, after review)
```

The warehouse file is `fantasy.duckdb` (git-ignored; override with `FANTASY_WAREHOUSE_DB`).

## Decisions

- **A separate repo that only reads**, rather than changes inside the live pipeline mid-season: nothing here
  can break the weekly reports.
- **A local generic grain test** (`macros/unique_combination_of_columns.sql`) instead of the dbt_utils
  package: one fewer dependency.
- **The contract test reads `DESCRIBE` on the live source** instead of pinning types in `read_csv`: explicit
  column lists in `read_csv` map by position, so a renamed column would load silently into the wrong field.
- **Ranking and projection sources are separate enums** (`espn, cbs, blend, ecr, fp` vs
  `espn, cbs, consensus`). The accepted-values test caught that on the first build.
- **DuckDB pinned below 2.0** until dbt-duckdb supports it.
