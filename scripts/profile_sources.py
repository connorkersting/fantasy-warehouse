"""Profile fantasy-football's CSV outputs before modeling: row counts, candidate grains, enum values."""
import sys
from pathlib import Path

import duckdb

root = Path(sys.argv[1] if len(sys.argv) > 1 else "../fantasy-football").resolve().as_posix().replace("'", "''")  # escape for SQL
con = duckdb.connect()

SOURCES = {
    "lineups": (f"{root}/state/replay/*/w*_lineups.csv", "season, week, league, slot"),
    "proj_error": (f"{root}/state/replay/*/w*_proj_error.csv", "season, week, league, slot, player_key, source"),
    "rank_accuracy": (f"{root}/state/replay/*/w*_rank_accuracy.csv", "season, week, league, slot, pos, source"),
    "health": (f"{root}/state/health/health_log.csv", "run_id, source, league_key"),
}
for name, (glob, grain) in SOURCES.items():
    rel = f"read_csv('{glob}', header=true, nullstr='NA', union_by_name=true)"
    total, distinct = con.sql(f"select count(*), count(distinct ({grain})) from {rel}").fetchone()
    print(f"{name:14s} rows={total:6d} distinct({grain})={distinct}{'  <-- NOT UNIQUE' if total != distinct else ''}")

roster = (f"read_csv('{root}/state/snapshots/*/*/*/*/roster.csv', header=true, nullstr='NA', "
          "filename=true, union_by_name=true)")
parsed = (f"select *, regexp_extract(replace(filename, '\\', '/'), 'snapshots/(\\d+)/w(\\d+)/([^/]+)/([^/]+)/', "
          f"['season','week','snap_slot','league']) as p from {roster}")
total, distinct = con.sql(
    f"select count(*), count(distinct (p.season, p.week, p.snap_slot, p.league, player_key)) from ({parsed})"
).fetchone()
print(f"{'roster':14s} rows={total:6d} distinct(season, week, snap_slot, league, player_key)={distinct}")

print("\nenums:")
enum_queries = {
    "lineups.league": f"select distinct league from read_csv('{root}/state/replay/*/w*_lineups.csv', nullstr='NA')",
    "lineups.slot": f"select distinct slot from read_csv('{root}/state/replay/*/w*_lineups.csv', nullstr='NA')",
    "proj_error.source": f"select distinct source from read_csv('{root}/state/replay/*/w*_proj_error.csv', nullstr='NA')",
    "proj_error.pos": f"select distinct pos from read_csv('{root}/state/replay/*/w*_proj_error.csv', nullstr='NA')",
    "health.level": f"select distinct level from read_csv('{root}/state/health/health_log.csv', nullstr='NA')",
    "health.slot": f"select distinct slot from read_csv('{root}/state/health/health_log.csv', nullstr='NA')",
    "health.source": f"select distinct source from read_csv('{root}/state/health/health_log.csv', nullstr='NA')",
    "health.league_key": f"select distinct league_key from read_csv('{root}/state/health/health_log.csv', nullstr='NA')",
    "roster.snap_slot": f"select distinct p.snap_slot from ({parsed})",
    "roster.pos": f"select distinct pos from {roster}",
    "roster.status": f"select distinct status from {roster}",
}
for label, q in enum_queries.items():
    vals = sorted(str(r[0]) for r in con.sql(q).fetchall())
    print(f"  {label}: {vals}")
