#!/usr/bin/env bash
#
# codeops-roadmap-sync.sh — deterministic roadmap counter/cascade recomputation.
#
# CodeOps Skills Version: 3.2.0
#
# The roadmap skill owns stage JUDGMENT; this script owns the ARITHMETIC (the PF-003
# prose-vs-script division, same as codeops-migrate.sh). It recomputes, from disk:
#   - each roadmap's header `> **Progress**: D / T (P%)` (top-level rows at ✅ Done / total
#     top-level rows — `↳ DEF-n` sub-rows are excluded);
#   - nested layout only: each feature's portfolio row `Progress` (`D/T RDs`) and rolled-up
#     `Status` (any ⛔ → ⛔, else all done → ✅, else any 🔄 → 🔄, else ⬜), and the portfolio
#     header `> **Features**: X / Y done`.
# It never infers or changes a Stage cell (stages are judgment + never-regress, owned by the
# skill), never touches Notes or prose, and never executes repo data.
#
# Usage:
#   codeops-roadmap-sync.sh            # rewrite the computed values in place
#   codeops-roadmap-sync.sh --check    # report drift, change nothing; exit 1 on drift
#   codeops-roadmap-sync.sh --dry-run  # print the would-be updates, change nothing
# Exit: 0 = in sync / updated; 1 = drift found (--check) or write failure; 2 = bad usage;
#       3 = python3 unavailable.

set -uo pipefail

MODE="write"
for arg in "$@"; do
  case "$arg" in
    --check)   MODE="check" ;;
    --dry-run) MODE="dry" ;;
    -h|--help) grep -E '^# ' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'ERROR: unknown argument: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

command -v python3 >/dev/null 2>&1 || {
  printf 'ERROR: python3 is required for roadmap parsing.\n' >&2
  exit 3
}

# Layout detection — the canonical grep from _shared/layout-convention.md.
layout="flat"
if [[ -f codeops/.codeops.yml ]] && grep -Eq '^codeopsLayout:[[:space:]]*nested[[:space:]]*$' codeops/.codeops.yml; then
  layout="nested"
fi

today="$(date '+%Y-%m-%d')"

MODE="$MODE" LAYOUT="$layout" TODAY="$today" python3 - <<'PY'
import glob, os, re, sys

mode = os.environ["MODE"]          # write | check | dry
layout = os.environ["LAYOUT"]      # flat | nested
today = os.environ["TODAY"]

drift = []      # human-readable drift lines
changed = []    # files rewritten (write mode)

def parse_rows(text):
    """Top-level tracker rows as (id, stage, status) — skips header/separator/`↳` sub-rows."""
    rows = []
    in_table = False
    for line in text.splitlines():
        if re.match(r'\|\s*ID\s*\|', line):
            in_table = True
            continue
        if in_table:
            if not line.startswith('|'):
                in_table = False
                continue
            cells = [c.strip() for c in line.strip().strip('|').split('|')]
            if not cells or set(cells[0]) <= {'-', ' '}:
                continue
            rid = cells[0]
            if rid.startswith('↳') or rid in ('—', '-', ''):
                continue
            stage = cells[4] if len(cells) > 4 else ''
            status = cells[5] if len(cells) > 5 else ''
            rows.append((rid, stage, status))
    return rows

def progress_of(text):
    rows = parse_rows(text)
    total = len(rows)
    done = sum(1 for _, stage, status in rows if '✅' in status or stage.startswith('Done'))
    pct = round(done / total * 100) if total else 0
    return done, total, pct, rows

def sub_header(text, key, new_value_line, path):
    """Replace a `> **Key**: ...` header line; record drift if it differs."""
    pat = re.compile(r'(?m)^> \*\*' + key + r'\*\*:.*$')
    m = pat.search(text)
    if not m:
        drift.append(f"{path}: header line '> **{key}**:' not found (malformed — skipped)")
        return text, False
    if m.group(0) == new_value_line:
        return text, False
    drift.append(f"{path}: {key} is '{m.group(0)}' — computed '{new_value_line}'")
    return pat.sub(new_value_line, text, count=1), True

def sync_feature_roadmap(path):
    """Sync one flat/per-feature roadmap header; return (done, total, rows) for cascading."""
    text = open(path, encoding='utf-8').read()
    done, total, pct, rows = progress_of(text)
    new_line = f"> **Progress**: {done} / {total} ({pct}%)"
    text2, did = sub_header(text, 'Progress', new_line, path)
    if did and mode == 'write':
        text2, _ = sub_header(text2, 'Last Updated', f"> **Last Updated**: {today}", path)
        try:
            open(path, 'w', encoding='utf-8').write(text2)
            changed.append(path)
        except OSError as e:
            print(f"ERROR: failed to write {path}: {e}", file=sys.stderr)
            sys.exit(1)
    return done, total, rows

if layout == 'flat':
    path = 'plans/00-roadmap.md'
    if not os.path.isfile(path):
        print('codeops-roadmap-sync: no roadmap found (flat layout) — nothing to sync.')
        sys.exit(0)
    sync_feature_roadmap(path)
else:
    features = {}
    for path in sorted(glob.glob('codeops/features/*/00-roadmap.md')):
        feat = path.split('/')[2]
        features[feat] = sync_feature_roadmap(path)
    # Portfolio cascade.
    ppath = 'codeops/00-roadmap.md'
    if os.path.isfile(ppath):
        text = open(ppath, encoding='utf-8').read()
        lines = text.splitlines()
        out, in_features, feature_rows_total, feature_rows_done = [], False, 0, 0
        for line in lines:
            if line.startswith('## Features'):
                in_features = True
            elif line.startswith('## ') and in_features:
                in_features = False
            if in_features and line.startswith('|'):
                cells = [c.strip() for c in line.strip().strip('|').split('|')]
                feat = cells[0] if cells else ''
                if feat in features:
                    done, total, rows = features[feat]
                    statuses = [s for _, _, s in rows]
                    if any('⛔' in s for s in statuses):
                        roll = '⛔'
                    elif total and done == total:
                        roll = '✅'
                    elif any('🔄' in s for s in statuses):
                        roll = '🔄'
                    else:
                        roll = '⬜'
                    new_prog = f"{done}/{total} RDs"
                    if len(cells) >= 6 and (cells[3] != new_prog or cells[4] != roll):
                        drift.append(f"{ppath}: row '{feat}' Progress/Status is "
                                     f"'{cells[3]}'/'{cells[4]}' — computed '{new_prog}'/'{roll}'")
                        cells[3], cells[4] = new_prog, roll
                        cells[5] = today if mode == 'write' else cells[5]
                        line = '| ' + ' | '.join(cells) + ' |'
                    feature_rows_total += 1
                    feature_rows_done += 1 if roll == '✅' else 0
            out.append(line)
        text2 = '\n'.join(out) + ('\n' if text.endswith('\n') else '')
        new_feat_line = f"> **Features**: {feature_rows_done} / {feature_rows_total} done"
        text2, _ = sub_header(text2, 'Features', new_feat_line, ppath)
        if mode == 'write' and text2 != text:
            text2, _ = sub_header(text2, 'Last Updated', f"> **Last Updated**: {today}", ppath)
            try:
                open(ppath, 'w', encoding='utf-8').write(text2)
                changed.append(ppath)
            except OSError as e:
                print(f"ERROR: failed to write {ppath}: {e}", file=sys.stderr)
                sys.exit(1)
    else:
        drift.append(f"{ppath}: portfolio roadmap missing in nested layout")

if drift:
    print('codeops-roadmap-sync: drift detected:')
    for d in drift:
        print(f'  DRIFT {d}')
    if mode == 'check':
        sys.exit(1)
    if mode == 'dry':
        print('(dry-run: nothing written)')
        sys.exit(0)
    print(f'codeops-roadmap-sync: updated {len(changed)} file(s): ' + ', '.join(changed))
    sys.exit(0)
else:
    print('codeops-roadmap-sync: all counters in sync — nothing to do.')
    sys.exit(0)
PY
