"""Write contracts/source_columns.csv: the pinned column contract (name, type, order) for every source.

Run this only deliberately, after reviewing an upstream schema change that a matches_source_contract test
reported:
    uv run python scripts/pin_source_schema.py [path-to-fantasy-season]
The globs and read_csv options must match the external_location entries in models/staging/_sources.yml.
"""
import csv
import os
import sys
from pathlib import Path

import duckdb

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else os.environ.get("FANTASY_SEASON_DIR", "../fantasy-season")).resolve()
ROOT_SQL = ROOT.as_posix().replace("'", "''")  # escape for a SQL string literal
OPTS = "header=true, nullstr='NA', filename=true"
SOURCES: dict[str, str] = {
    "replay_lineups": f"read_csv('{ROOT_SQL}/state/replay/*/w*_lineups.csv', {OPTS}, union_by_name=true)",
    "replay_proj_error": f"read_csv('{ROOT_SQL}/state/replay/*/w*_proj_error.csv', {OPTS}, union_by_name=true)",
    "replay_rank_accuracy": f"read_csv('{ROOT_SQL}/state/replay/*/w*_rank_accuracy.csv', {OPTS}, union_by_name=true)",
    "health_log": f"read_csv('{ROOT_SQL}/state/health/health_log.csv', {OPTS})",
    "snapshot_roster": f"read_csv('{ROOT_SQL}/state/snapshots/*/*/*/*/roster.csv', {OPTS}, union_by_name=true)",
}


def main() -> None:
    con = duckdb.connect()
    rows: list[tuple[str, int, str, str]] = []
    for table, rel in SOURCES.items():
        described = con.sql(f"DESCRIBE SELECT * FROM {rel}").fetchall()
        for ordinal, (name, col_type, *_) in enumerate(described, start=1):
            rows.append((table, ordinal, name, col_type))
    out = Path(__file__).resolve().parent.parent / "contracts" / "source_columns.csv"
    out.parent.mkdir(exist_ok=True)
    with out.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerow(["source_table", "ordinal", "column_name", "column_type"])
        writer.writerows(rows)
    print(f"pinned {len(rows)} columns across {len(SOURCES)} sources -> {out}")


if __name__ == "__main__":
    main()
