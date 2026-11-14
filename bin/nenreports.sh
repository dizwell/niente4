#!/usr/bin/env bash
####################################################################
#
# nenreports: This is now the central clearing house for all
# reports, together with the special logic needed to allow for 
# user-defined 'Advanced SQL' queries.
#
####################################################################
function output_report {
if ! [[ -f $CONFDIR/bin/nenoutput.sh ]]; then
  REMOTESOURCE="https://raw.githubusercontent.com/dizwell/niente4/beta/bin"
  wget -q "$REMOTESOURCE/nenoutput.sh" -O "$CONFDIR/bin/nenoutput.sh"
  source "$CONFDIR/bin/nenoutput.sh" "$REPORT_FILE"
else
  source "$CONFDIR/bin/nenoutput.sh" "$REPORT_FILE"
fi
}

function advsql_reports {
rm "$CONFDIR/tmp/advsqlreport.html"
REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
local RETURNTOMENU=0
local SQL_INPUT="$CONFDIR/tmp/advsqlreport.txt"
local HTML_OUT="$CONFDIR/tmp/advsqlreport.html"

[[ -f "$SQL_INPUT" ]] || touch "$SQL_INPUT"

while [[ $RETURNTOMENU -ne 1 ]]; do
  dialog --backtitle "Niente Advanced SQL Reporting - $SQLDEST" \
         --title " Enter your complete select query below " \
         --extra-button --extra-label "Clear" \
         --editbox "$SQL_INPUT" 12 90 2>"$SQL_INPUT.tmp"
    
  exitStatus=$?
  case $exitStatus in
    1|255) RETURNTOMENU=1; continue ;;
    3) echo "" > "$SQL_INPUT"; continue ;;
    0) mv "$SQL_INPUT.tmp" "$SQL_INPUT" ;;
  esac

  SQLTXT=$(tr '\n' ' ' < "$SQL_INPUT" | sed 's/;//g; s/delete//gi; s/update//gi')
    
    sqlite3 "$CONFDIR/db/$DBNAME.db" <<EOF > "$HTML_OUT"
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
.print '<div style="display: flex; align-items: center; margin-bottom: 20px;">'
.print '  <img src="file://$CONFDIR/art/nienteico.png" style="width:80px; height:80px; margin-right:20px;">'
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

  output_report
done
}

function other_reports {
REMOTESOURCE="https://raw.githubusercontent.com/dizwell/niente4/beta/bin"
if ! [[ -f $CONFDIR/bin/nenrptgen.sh ]]; then
  wget -q "$REMOTESOURCE/nenrptgen.sh" -O "$CONFDIR/bin/nenrptgen.sh"
fi
if ! [[ -f $CONFDIR/bin/nenrptlog.sh ]]; then
  wget -q "$REMOTESOURCE/nenrptlog.sh" -O "$CONFDIR/bin/nenrptlog.sh"
fi
if ! [[ -f $CONFDIR/bin/nenrptother.sh ]]; then
  wget -q "$REMOTESOURCE/nenrptother.sh" -O "$CONFDIR/bin/nenrptother.sh"
fi
}

other_reports
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

  advsql) advsql_reports; nmenuoptions reporting;;
esac
