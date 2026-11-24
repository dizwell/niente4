#!/usr/bin/env bash
####################################################################
#
# nenreports: This is now the central clearing house for all
# reports, together with the special logic needed to allow for 
# user-defined 'Advanced SQL' queries.
#
####################################################################
function output_report {
source "$CONFDIR/bin/nenoutput.sh" "$REPORT_FILE"
}

function advsql_reports {
rm -f "$CONFDIR/tmp/advsqlreport.html"
REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
local RETURNTOMENU=0
local SQL_INPUT="$CONFDIR/tmp/advsqlreport.txt"
local HTML_OUT="$CONFDIR/tmp/advsqlreport.html"
REPORT_FILE="$HTML_OUT"                                    # The file output_report opens in the browser

[[ -f "$SQL_INPUT" ]] || touch "$SQL_INPUT"

while [[ $RETURNTOMENU -ne 1 ]]; do
  dialog --backtitle "Niente Advanced SQL Reporting" \
         --title " Enter your complete select query below " \
         --extra-button --extra-label "Clear" \
         --editbox "$SQL_INPUT" 12 90 2>"$SQL_INPUT.tmp"
    
  exitStatus=$?
  case $exitStatus in
    1|255) RETURNTOMENU=1; continue ;;
    3) echo "" > "$SQL_INPUT"; continue ;;
    0) mv "$SQL_INPUT.tmp" "$SQL_INPUT" ;;
  esac

  # The query is run exactly as typed, except that semicolons are removed: Niente adds its own to the end, and also
  # counts the rows with "select count(*) from (<query>)", which a typed semicolon would break
  SQLTXT=$(tr '\n' ' ' < "$SQL_INPUT" | sed 's/;//g')
  # sqlite3's own dot commands (.shell, .system and the rest) can run programs on the computer: only SQL is allowed
  LEADTXT="${SQLTXT#"${SQLTXT%%[![:space:]]*}"}"
  if [[ $LEADTXT == .* ]]; then
    dialog --backtitle "Niente Advanced SQL Reporting" --title " Not an SQL Query " --msgbox "\\nOnly SQL queries can be run here: a query cannot begin with a dot (sqlite3's own commands, such as .shell, are not allowed).\\n\\nClick OK to return to your query." 10 80
    continue
  fi

    # The database is opened read-only for this query alone, so nothing typed here can change it: sqlite refuses any
    # write itself, and its error message is shown in place of the report
    sqlite3 -readonly "$CONFDIR/db/$DBNAME.db" <<EOF > "$HTML_OUT" 2>"$CONFDIR/tmp/advsqlerror.txt"
.mode html
.headers on
.print '<html><head><title>Custom Niente Report</title>'
.print '<link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/nienteico.svg">'
.print '<style>'
.print '  body { font-family: serif; margin: 20px; background-color: #fff; }'
.print '  table { border-collapse: collapse; width: 100%; font-size: 13px; table-layout: auto; }'
.print '  th { background-color: #333; color: white; padding: 8px; position: sticky; top: 0; z-index: 10; text-align: left; }'
.print '  th, td { border: 1px solid #aaa; padding: 6px 8px; line-height: 1.2; vertical-align: top; }'
.print '  tr:nth-child(even) { background-color: #e0e0e0; }'
.print '  tr:hover { background-color: #ffffcc; }'
.print '  .footer { font-size: 12px; color: #555; margin-top: 20px; border-top: 1px solid #ccc; padding-top: 10px; }'
.print '  code { background: #eee; padding: 2px 4px; }'
.print '</style></head><body>'

/* Branding Header */
.print '<div style="display: flex; align-items: center; border-bottom: 1px solid #ccc; margin-bottom: 20px;">'
.print '  <a href="https://bbritten.com" target="_blank"><img src="file://$CONFDIR/art/nienteico.png" style="width:80px; height:80px; margin-right:20px;"></a>'
.print '  <div>'
.print '    <h1 style="margin: 0;">Custom Niente Report</h1>'
.print '  </div>'
.print '</div>'

.print '<table>'
$SQLTXT;
.print '</table>'

/* Footer */
.headers off
.mode list
.print '<div class="footer">'

.print '<p><strong>Total rows:</strong> '
SELECT CASE 
  WHEN count(*) = 0 THEN '<span style="color: red; font-weight: bold; font-size: 1.2em;">0 (No results found)</span>'
  ELSE count(*) 
END
FROM ($SQLTXT);
.print '</p>'

.print '</p>'
.print '<p>Generated on: $REPORT_DATE</p>'
.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
.print "<p>Query Code: <code>$SQLTXT</code></p>"
.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
.print '</div></body></html>'
EOF

  if [[ -s "$CONFDIR/tmp/advsqlerror.txt" ]]; then
    {
      echo "<html><head><title>Niente Advanced SQL Error</title>"
      echo "<link rel=\"icon\" type=\"image/svg+xml\" href=\"file://$CONFDIR/art/nienteico.svg\">"
      echo "<style> body { font-family: serif; margin: 20px; } .error { font-family: monospace; font-size: 14px; white-space: pre-wrap; background: #f5f5f5; border: 1px solid #ccc; padding: 12px; } </style></head><body>"
      echo "<div style=\"display: flex; align-items: center; border-bottom: 1px solid #ccc; margin-bottom: 20px;\"><a href=\"https://bbritten.com\" target=\"_blank\"><img src=\"file://$CONFDIR/art/nienteico.png\" style=\"width:80px; height:80px; margin-right:20px;\"></a><h1 style=\"margin: 0;\">Niente Advanced SQL Reporting: Error!</h1></div>"
      echo "<pre class=\"error\">"
      sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "$CONFDIR/tmp/advsqlerror.txt"
      echo "</pre></body></html>"
    } > "$HTML_OUT"
  fi
  rm -f "$CONFDIR/tmp/advsqlerror.txt" >/dev/null 2>&1

  output_report
done
}

if [ -z "$1" ]; then REPORT_TYPE="aggstats"; else REPORT_TYPE=$1; fi

case $REPORT_TYPE in
  aggsts) source "$CONFDIR/bin/nenrptgen.sh" aggsts;;
  phys  ) source "$CONFDIR/bin/nenrptgen.sh" phys;;
  nya   ) source "$CONFDIR/bin/nenrptgen.sh" nya;;
  nulltg) source "$CONFDIR/bin/nenrptgen.sh" nulltg;;

  dates ) source "$CONFDIR/bin/nenrptlog.sh" dates;;
  track ) source "$CONFDIR/bin/nenrptlog.sh" track;;
  comper) source "$CONFDIR/bin/nenrptlog.sh" percom;;
  albper) source "$CONFDIR/bin/nenrptlog.sh" peralb;;
  artcom) source "$CONFDIR/bin/nenrptlog.sh" artcom;;
  bits  ) source "$CONFDIR/bin/nenrptlog.sh" badbit;;
  
  badart) source "$CONFDIR/bin/nenrptother.sh" badart;;
  maxv  ) source "$CONFDIR/bin/nenrptother.sh" maxv;;
  replay) source "$CONFDIR/bin/nenrptother.sh" replay;;
  namebt) source "$CONFDIR/bin/nenrptother.sh" namebt;;
  multtk) source "$CONFDIR/bin/nenrptother.sh" multtk;;
  dupes ) source "$CONFDIR/bin/nenrptother.sh" dupes;;
  ops   ) source "$CONFDIR/bin/nenrptother.sh" ops;;

  advsql) advsql_reports; nsubmenuoptions advsql;;       # Back to the Advanced SQL menu
esac
