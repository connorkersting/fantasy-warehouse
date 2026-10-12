# fantasy-warehouse

dbt-duckdb warehouse that reads the fantasy-season (football) pipeline's CSV outputs in place. README.md
has the problem, layers, results and decisions; read it before changing models. Football only: fantasy
basketball work lives in `C:\dev\fantasy-basketball`, with its own rules.

## Hard rules
- **fantasy-season is read-only from here.** Never edit, commit, pull or fetch in it from a warehouse
  session. Ask Connor to pull if the data looks stale.
- **No upstream data in this repo or outside the machine.** It holds private league payloads and licensed
  rankings: never commit it, never paste rows into PRs/issues, never send it to Codex or any other service.
  Code and the column contract are fine to share.
- **Never re-pin the source contract to make a test pass.** A `matches_source_contract` failure means
  look first: read the failing row (source, file, column, expected, arrived), inspect the upstream change,
  tell Connor, and only then run `scripts/pin_source_schema.py` deliberately, in its own commit that says why.
- `fantasy.duckdb` is git-ignored and holds the reconciliation history (`audit_reconciliation`,
  `full_refresh: false`). Don't delete it or drop that table without asking.

## Commands (run from the repo root; uv manages .venv)
- `uv run dbt build`: the full gate. The reconciliation test only passes inside `dbt build` (it needs
  rows from the current invocation), so a standalone `dbt test` on it fails by design.
- `uv run dbt source freshness`: not part of build. It measures the local fantasy-season checkout, so a
  stale result may mean "not pulled", not "pipeline down": check the upstream's latest commit first.
- `uv run python scripts/profile_sources.py`: grain/enum profile before adding a model or test.
- Read-only contract check without touching the warehouse: DESCRIBE each source in an in-memory DuckDB
  and diff against `contracts/source_columns.csv` plus each file's header (same logic as the macro).
- Upstream location: `FANTASY_SEASON_DIR` (default `../fantasy-season`); warehouse file:
  `FANTASY_WAREHOUSE_DB` (default `fantasy.duckdb`). See `.env.example`.

## Conventions
- Layers: `stg_` = rename/cast only, one per source, grain stated at the top; `dim_`/`fct_` = tables
  with enforced contracts. Tests by layer follow the global data-quality rule.
- New source: add the `read_csv` external_location in `_sources.yml`, a per-source
  `matches_source_contract` test, a grain test, then pin. Globs and read_csv options must stay in sync
  between `_sources.yml` and `scripts/pin_source_schema.py`.
- Projection sources (`espn, cbs, consensus`) and ranking sources (`espn, cbs, blend, ecr, fp`) are
  different enums: don't merge them.
- Generic tests are local macros (`macros/`), not dbt_utils. Keep it that way unless there's a reason.
- DuckDB stays `<2` until dbt-duckdb supports 2.x.
- Error is always `actual - projected` (negative = over-projection).

## README results
The README's numbers are a dated snapshot ("data through week N, snapshot YYYY-MM-DD"). When new weeks
land, re-run `dbt build`, re-query the marts, and update the numbers and the date together, never one
without the other. Keep the sample-size caveats.

## Git
Branch + PR for every change (even solo), plain title, what-and-why body, no Claude attribution.
Push only to origin (connorkersting/fantasy-warehouse).
Merge your own PRs right after opening them: `gh pr merge <n> --merge --delete-branch`, then
`git switch main` and `git pull`. No need to ask first (Connor, 2026-10-12). If the PR has
failing checks or a merge conflict, stop and tell him instead.

## Windows notes
Python can't open paths over 260 chars: keep scratch files at short paths (e.g. `D:\tools\...`) or pipe
scripts via `python - < file`. Write Python/SQL with the Write tool, not heredocs.
