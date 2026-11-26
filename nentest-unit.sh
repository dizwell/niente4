#!/usr/bin/env bash
# ====================================================================================================
# nentest-unit.sh: Layer 2 test harness for Niente. Unit tests of the self-contained helper functions,
# and of key report SQL run against a scratch database.
#
# It never starts Niente, never touches your databases or configuration, never scans any music. Each
# function is lifted out of the real script that defines it (from "function name {" to the first "}" in
# column 1), and each piece of report SQL is the real line from the real script, so the tests exercise the
# code you actually run. Everything is written in a temporary folder that is removed afterwards.
#
# Usage:  nentest-unit.sh [ROOT]      (same ROOT convention as nentest-static.sh)
#
# Exit status: 0 if there are no FAILs, 1 otherwise.
# ====================================================================================================
ROOT="${1:-$HOME/.local/share/niente4}"
ROOT="${ROOT%/}"
FAILS=0; PASSES=0; SKIPS=0

if [[ ! -d $ROOT ]]; then echo "No such folder: $ROOT"; exit 2; fi
if [[ -d $ROOT/bin ]]; then BIN="$ROOT/bin"; else BIN="$ROOT"; fi
MAIN="$ROOT/niente4.sh"

# GNU tools if installed (MacOS), plain ones otherwise; the scripts themselves use these names.
GREPPROG=$(command -v ggrep || command -v grep)
SEDPROG=$(command -v gsed || command -v sed)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/nenunit.XXXXXX"); trap 'rm -rf "$TMP"' EXIT
HAVESQLITE=0; command -v sqlite3 >/dev/null 2>&1 && HAVESQLITE=1

function heading { echo; echo "== $1"; }
function pass { PASSES=$((PASSES + 1)); echo "  PASS  $1"; }
function skip { SKIPS=$((SKIPS + 1)); echo "  SKIP  $1"; }
function fail {
  FAILS=$((FAILS + 1)); echo "  FAIL  $1"
  shift; for line in "$@"; do echo "          $line"; done
}

# check "description" "expected" "actual"
function check {
  if [[ $2 == "$3" ]]; then
    pass "$1"
  else
    fail "$1" "expected: [$2]" "     got: [$3]"
  fi
}

# load_fn NAME FILE: define function NAME from FILE (niente4.sh, or a script in bin) in this shell.
# Returns 1 if it can't be found.
function load_fn {
  local name="$1" file body
  if [[ $2 == niente4.sh ]]; then file="$MAIN"; else file="$BIN/$2"; fi
  if [[ ! -f $file ]]; then fail "$name: $2 not found"; return 1; fi
  body=$($SEDPROG -n "/^function $name {/,/^}/p" "$file")
  if [[ -z $body ]]; then fail "$name: not found in $2 (as 'function $name {' with its closing } in column 1)"; return 1; fi
  eval "$body" 2>"$TMP/evalerr" || { fail "$name: could not be defined" "$(cat "$TMP/evalerr")"; return 1; }
}

# real_line FILE REGEX: the first line of FILE (niente4.sh, or a script in bin) matching REGEX, exactly as written
function real_line {
  local file
  if [[ $1 == niente4.sh ]]; then file="$MAIN"; else file="$BIN/$1"; fi
  $GREPPROG -m1 -E -- "$2" "$file" 2>/dev/null
}

# new_db: a fresh scratch database built from the table definitions in Niente's own nencreatedb.sh
function new_db {
  rm -f "$CONFDIR/db/$DBNAME.db"
  $SEDPROG -n '/^  sqlite3 "\$CONFDIR\/db\/\$DBNAME.db" << EOF$/,/^EOF$/p' "$BIN/nencreatedb.sh" | $SEDPROG '1d;$d' > "$TMP/schema.sql"
  [[ -s $TMP/schema.sql ]] || return 1
  sqlite3 "$CONFDIR/db/$DBNAME.db" < "$TMP/schema.sql"
}

# add_track FILENAME PERFORMER ALBUM ARTIST COMPOSER: one row in the tracks table (other columns left empty)
function add_track {
  local q="'" qq="''"
  sqlite3 "$CONFDIR/db/$DBNAME.db" "insert into tracks (filename, performer, albumname, artistname, composername) values ('${1//$q/$qq}', '${2//$q/$qq}', '${3//$q/$qq}', '${4//$q/$qq}', '${5//$q/$qq}');"
}

CONFDIR="$TMP/conf"; mkdir -p "$CONFDIR/txt" "$CONFDIR/tmp" "$CONFDIR/db"
DBNAME="unittest"

# ----------------------------------------------------------------------------------------------------
heading "1. thousands (niente4.sh)"
if load_fn thousands niente4.sh; then
  check "thousands 0"          "0"         "$(thousands 0)"
  check "thousands 999"        "999"       "$(thousands 999)"
  check "thousands 1000"       "1,000"     "$(thousands 1000)"
  check "thousands 17597"      "17,597"    "$(thousands 17597)"
  check "thousands 1234567"    "1,234,567" "$(thousands 1234567)"
  check "thousands 100000"     "100,000"   "$(thousands 100000)"
fi

# ----------------------------------------------------------------------------------------------------
heading "2. clean_dbname (niente4.sh)"
if load_fn clean_dbname niente4.sh; then
  check "a plain name is unchanged"            "Music_Master" "$(clean_dbname Music_Master)"
  check "spaces inside become _"               "Music_Master" "$(clean_dbname "Music Master")"
  check "leading and trailing spaces go"       "Music"        "$(clean_dbname "   Music  ")"
  check "hyphens are kept"                     "Music-2026"   "$(clean_dbname "Music-2026")"
  # Which letters count as letters depends on the terminal's language setting, as it does when Niente runs
  if [[ $(locale charmap 2>/dev/null) == "UTF-8" ]]; then
    check "accented letters are kept"          "Musique_Fauré" "$(clean_dbname "Musique Fauré")"
  else
    skip "accented letters: this terminal's language setting isn't UTF-8 (Niente's own terminal is)"
  fi
  check "slash, asterisk and quotes become _"  "a_b_c_d_e"    "$(clean_dbname "a/b*c'd\"e")"
  check "a dot becomes _ (no hidden or extension-like names)" "my_db" "$(clean_dbname "my.db")"
  check "an empty name stays empty"            ""             "$(clean_dbname "   ")"
fi

# ----------------------------------------------------------------------------------------------------
heading "3. take_lock and release_lock (niente4.sh)"
if load_fn take_lock niente4.sh && load_fn release_lock niente4.sh; then
  LOCK="$CONFDIR/tmp/nientelock"
  SAVEDDB="$DBNAME"; DBNAME=""                                     # No database: take_lock then logs nothing

  rm -f "$LOCK"
  take_lock; rc=$?
  check "no lock: the lock is taken"                      "0"  "$rc"
  check "no lock: the lock holds this session's number"   "$$" "$(head -n 1 "$LOCK" 2>/dev/null)"
  take_lock; rc=$?
  check "this session's own lock: taken again"            "0"  "$rc"
  release_lock
  [[ ! -e $LOCK ]] && pass "release_lock removes this session's own lock" || fail "release_lock left this session's own lock behind"

  # A leftover: a number that is not a running process
  GONE=999999; while kill -0 "$GONE" 2>/dev/null; do GONE=$((GONE - 1)); done
  echo "$GONE" > "$LOCK"
  take_lock; rc=$?
  check "leftover lock (its process has gone): replaced" "0"  "$rc"
  check "leftover lock: now holds this session's number"  "$$" "$(head -n 1 "$LOCK" 2>/dev/null)"
  release_lock

  # A live lock: a running process whose command line names Niente
  ( exec -a niente-unittest-holder sleep 30 ) & HOLDER=$!
  sleep 0.3
  echo "$HOLDER" > "$LOCK"
  take_lock; rc=$?
  check "live lock held by another Niente session: refused" "1" "$rc"
  check "live lock: left exactly as it was"            "$HOLDER" "$(head -n 1 "$LOCK" 2>/dev/null)"
  release_lock
  check "release_lock never removes another session's lock" "$HOLDER" "$(head -n 1 "$LOCK" 2>/dev/null)"
  kill "$HOLDER" 2>/dev/null; wait "$HOLDER" 2>/dev/null

  # A running process that is not Niente: its lock is a leftover
  sleep 30 & OTHER=$!
  echo "$OTHER" > "$LOCK"
  take_lock; rc=$?
  check "lock naming a running process that isn't Niente: replaced" "0" "$rc"
  kill "$OTHER" 2>/dev/null; wait "$OTHER" 2>/dev/null
  release_lock; rm -f "$LOCK"
  DBNAME="$SAVEDDB"
fi

# ----------------------------------------------------------------------------------------------------
heading "4. conf_text (nenconf.sh)"
if load_fn conf_text nenconf.sh; then
  CONFFILE="$CONFDIR/txt/niente.conf"
  cat > "$CONFFILE" <<'EOF'
# A test configuration
HOTKEY=11
BROWSER="firefox"
MUSICDIR="/Volumes/Music Master/classical"
WEZTHEME="Wild Cherry (Gogh)"
DBNAME="Music_Master"
OPENER="open -a Firefox --args a=b"
VOLUMETHRESHOLD=2
EOF
  check "a quoted value comes back without its quotes"    "firefox"                         "$(conf_text BROWSER)"
  check "a value with spaces comes back whole"            "/Volumes/Music Master/classical" "$(conf_text MUSICDIR)"
  check "a value with brackets comes back whole"          "Wild Cherry (Gogh)"              "$(conf_text WEZTHEME)"
  check "an unquoted number"                              "2"                               "$(conf_text VOLUMETHRESHOLD)"
  check "'=' inside a value is kept"                      "open -a Firefox --args a=b"      "$(conf_text OPENER)"
  check "the key is matched whatever its case"            "11"                              "$(conf_text hotkey)"
  check "a missing key gives nothing"                     ""                                "$(conf_text NO_SUCH_KEY)"
  check "a key is only matched at the start of a line"    ""                                "$(conf_text CONFIGURATION)"
  # The file must also source cleanly, as nenparse.sh reads it that way
  ( source "$CONFFILE" ) 2>"$TMP/err"; rc=$?
  check "the configuration sources without error"         "0" "$rc"
  check "sourcing gives the same value as conf_text"      "/Volumes/Music Master/classical" "$(source "$CONFFILE"; printf '%s' "$MUSICDIR")"
fi

# ----------------------------------------------------------------------------------------------------
heading "5. check_data_loss (niente4.sh), on a scratch database"
if [[ $HAVESQLITE -eq 0 ]]; then
  skip "check_data_loss: sqlite3 is not installed"
elif load_fn check_data_loss niente4.sh && load_fn thousands niente4.sh; then
  if new_db; then
    check_data_loss; rc=$?
    check "an empty database never refuses"                    "0" "$rc"

    for n in 1 2 3 4 5 6 7 8 9 10; do add_track "/m/Album/$n.flac" "" "" "" ""; done
    for n in 1 2 3 4 5 6 7 8 9 10; do sqlite3 "$CONFDIR/db/$DBNAME.db" "insert into loadfiles values ('/m/Album/$n.flac');"; done
    check_data_loss; rc=$?
    check "every track still present: carries on"              "0" "$rc"

    sqlite3 "$CONFDIR/db/$DBNAME.db" "delete from loadfiles where filename in ('/m/Album/1.flac','/m/Album/2.flac');"
    check_data_loss; rc=$?
    check "exactly a fifth missing (2 of 10): carries on"      "0" "$rc"

    sqlite3 "$CONFDIR/db/$DBNAME.db" "delete from loadfiles where filename='/m/Album/3.flac';"
    check_data_loss; rc=$?
    check "more than a fifth missing (3 of 10): refuses"       "1" "$rc"
    check "the counts are left for the warning"                "10/3" "$DBTRACKS/$LOSTTRACKS"

    sqlite3 "$CONFDIR/db/$DBNAME.db" "delete from loadfiles;"
    check_data_loss; rc=$?
    check "the music folder empty (an unmounted share): refuses" "1" "$rc"
  else
    fail "could not build a scratch database from nencreatedb.sh's table definitions"
  fi
fi

# ----------------------------------------------------------------------------------------------------
heading "6. Report SQL, run against a scratch database"
if [[ $HAVESQLITE -eq 0 ]]; then
  skip "report SQL: sqlite3 is not installed"
elif ! new_db; then
  fail "could not build a scratch database from nencreatedb.sh's table definitions"
else
  # 6a. PERFORMER & ALBUM (Logical Issues option 4): the real line from nenrptlog.sh, which must be the same test as L4
  line=$(real_line nenrptlog.sh '^BADPERCOM_COUNT=.*not instr\(performer, substr\(albumname')
  l4=$($GREPPROG -m1 "select 'L4'" "$BIN/nenrptgen.sh" 2>/dev/null | $GREPPROG -oE "where not instr\(performer, .*\)\)\)\)")
  if [[ -z $line ]]; then
    fail "PERFORMER & ALBUM: the report's count line (testing PERFORMER) was not found in nenrptlog.sh"
  else
    # The album's bracketed artist must appear in PERFORMER: right, right, wrong (another cellist), right
    add_track "/m/Bach - Cello Suites (Fournier - 1960)/1.flac"  "Pierre Fournier"                  "Cello Suites (Fournier - 1960)"  "Bach"  "Bach"
    add_track "/m/Bach - Cello Suites (Casals - 1939)/1.flac"    "Pau Casals"                       "Cello Suites (Casals - 1939)"    "Bach"  "Bach"
    add_track "/m/Bach - Cello Suites (Tortelier - 1983)/1.flac" "Mstislav Rostropovich"            "Cello Suites (Tortelier - 1983)" "Bach"  "Bach"
    add_track "/m/Elgar - Concerto (Isserlis - 1988)/1.flac"     "Steven Isserlis; LSO; Hickox"     "Concerto (Isserlis - 1988)"      "Elgar" "Elgar"
    eval "$line"
    check "PERFORMER & ALBUM: flags only the file whose PERFORMER lacks the album's artist" "1" "$BADPERCOM_COUNT"
    [[ -n $l4 && $line == *"$l4"* ]] && pass "PERFORMER & ALBUM: the report uses exactly the L4 statistic's test" \
      || fail "PERFORMER & ALBUM: the report's test differs from the L4 statistic's" "report: ${line:0:160}..." "L4: $l4"
  fi

  # 6b. Volume boosts are judged per folder: a folder counts only if every file in it could be boosted
  new_db
  folder=$(real_line niente4.sh '^FOLDERSQL=')
  line=$(real_line nenrptother.sh '^MAXV_COUNT=')
  if [[ -z $folder || -z $line ]]; then
    fail "volume boosts: FOLDERSQL (niente4.sh) or MAXV_COUNT (nenrptother.sh) was not found"
  else
    eval "$folder"; VOLUMETHRESHOLD=2
    for b in 3 4 5; do sqlite3 "$CONFDIR/db/$DBNAME.db" "insert into maxvolumes (filename, boost) values ('/m/Quiet Album/$b.flac', $b);"; done
    for b in 3 1 5; do sqlite3 "$CONFDIR/db/$DBNAME.db" "insert into maxvolumes (filename, boost) values ('/m/Mixed Album/$b.flac', $b);"; done
    for b in 0 1;   do sqlite3 "$CONFDIR/db/$DBNAME.db" "insert into maxvolumes (filename, boost) values ('/m/Loud Album/$b.flac', $b);"; done
    eval "$line"
    check "volume boosts: only the folder whose every file exceeds the threshold counts" "1" "$MAXV_COUNT"
    VOLUMETHRESHOLD=0
    eval "$line"
    check "volume boosts: a lower threshold takes in the folder with one quieter file" "2" "$MAXV_COUNT"
  fi

  # 6c. Multiple FLACs in one folder: grouped by ARTIST and ALBUM, so a recital of several composers is one album
  new_db
  line=$(real_line nenrptother.sh '^MULTI_COUNT=')
  if [[ -z $line ]]; then
    fail "multiple FLACs: MULTI_COUNT was not found in nenrptother.sh"
  else
    add_track "/m/Recital (Hough - 2020)/1.flac" "Stephen Hough" "Recital (Hough - 2020)" "Stephen Hough" "Chopin"
    add_track "/m/Recital (Hough - 2020)/2.flac" "Stephen Hough" "Recital (Hough - 2020)" "Stephen Hough" "Liszt"
    add_track "/m/Recital (Hough - 2020)/3.flac" "Stephen Hough" "Recital (Hough - 2020)" "Stephen Hough" "Debussy"
    add_track "/m/Symphony 5 (Karajan - 1963)/1.flac" "BPO; Karajan" "Symphony 5 (Karajan - 1963)" "Beethoven" "Beethoven"
    eval "$line"
    check "multiple FLACs: a multi-composer recital in one folder counts as one album" "1" "$MULTI_COUNT"
    add_track "/m/Symphony 5 (Karajan - 1963)/2.flac" "BPO; Karajan" "Symphony 5 (Karajan - 1963)" "Beethoven" "Beethoven"
    eval "$line"
    check "multiple FLACs: a second folder holding more than one FLAC is counted too" "2" "$MULTI_COUNT"
  fi
fi

# ----------------------------------------------------------------------------------------------------
echo
echo "=============================================================================================="
echo "  $PASSES passed, $SKIPS skipped, $FAILS failed"
echo "=============================================================================================="
[[ $FAILS -eq 0 ]]
