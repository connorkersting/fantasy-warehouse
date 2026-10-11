"""Write seeds/expected_source_columns.csv: the pinned column contract for every fantasy-season source.

Run this only deliberately, after reviewing an upstream schema change that the contract test reported:
    uv run python scripts/pin_source_schema.py [path-to-fantasy-season]
The globs must match the external_location entries in models/staging/_sources.yml.
"""
import csv
import os
import sys
from pathlib import Path

import duckdb

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else os.environ.get("FANTASY_SEASON_DIR", "../fantasy-season")).resolve()
OPTS = "header=true, nullstr='NA', filename=true"
SOURCES: dict[str, str] = {
    "replay_lineups": f"read_csv('{ROOT.as_posix()}/state/replay/*/w*_lineups.csv', {OPTS}, union_by_name=true)",
    "replay_proj_error": f"read_csv('{ROOT.as_posix()}/state/replay/*/w*_proj_error.csv', {OPTS}, union_by_name=true)",
    "replay_rank_accuracy": f"read_csv('{ROOT.as_posix()}/state/replay/*/w*_rank_accuracy.csv', {OPTS}, union_by_name=true)",
    "health_log": f"read_csv('{ROOT.as_posix()}/state/health/health_log.csv', {OPTS})",
    "snapshot_roster": f"read_csv('{ROOT.as_posix()}/state/snapshots/*/*/*/*/roster.csv', {OPTS}, union_by_name=true)",
}


def main() -> None:
    con = duckdb.connect()
    rows: list[tuple[str, str, str]] = []
    for table, rel in SOURCES.items():
        for name, col_type, *_ in con.sql(f"DESCRIBE SELECT * FROM {rel}").fetchall():
            rows.append((table, name, col_type))
    out = Path(__file__).resolve().parent.parent / "seeds" / "expected_source_columns.csv"
    with out.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerow(["source_table", "column_name", "column_type"])
        writer.writerows(rows)
    print(f"pinned {len(rows)} columns across {len(SOURCES)} sources -> {out}")


if __name__ == "__main__":
    main()
