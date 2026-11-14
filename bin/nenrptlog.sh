#!/usr/bin/env bash
####################################################################
#
# nenrptlog: routine for producing all the "Logical Issues Reports", namely:
#
# 1. DATE v. ALBUM tag discrepancies
# 2. TRACKNUMBER tags not starting at 1 in a folder
# 3. PERFORMER v. COMMENT tag discrepancies
# 4. PERFORMER v. ALBUM tag discrepancies
# 5. ARTIST v. COMPOSER tag differences
# 6. Bit Depth v. Sample Rates incongruities
#
####################################################################
function output_report {
if ! [[ -f $CONFDIR/bin/aboutput.sh ]]; then
  REMOTESOURCE="https://software.bbritten.com/giocoso/bin"
  wget -q "$REMOTESOURCE/aboutput.sh" -O "$CONFDIR/bin/aboutput.sh"
  source "$CONFDIR/bin/aboutput.sh" "$REPORT_FILE"
else
  source "$CONFDIR/bin/aboutput.sh" "$REPORT_FILE"
fi
}

####################################################################
# Report 1: DATE v. ALBUM tag issues
####################################################################
function report_baddates {
REPORT_FILE="$CONFDIR/tmp/baddates.html"
rm -f "$REPORT_FILE" 2>/dev/null
check_database

# Now we can produce the report
ALBDATE_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from tracks where album_year<>date_tag")
ALBDATE_SQL="select rtrim(filename, replace(filename, '/', '')) as 'Folder Name', replace(filename, rtrim(filename, replace(filename, '/', '')), '') as 'File Name', albumname, album_year, date_tag from tracks where album_year<>date_tag order by 1,2"

REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
REPORT_TITLE="Music files exhibiting inconsistent ALBUM and DATE tags"
REPORT_ALLCLEAR="\nAll known music files appear to have no discrepancies between their ALBUM and DATE tags.\\n\\nPress OK to continue."

if [[ $ALBDATE_COUNT -eq 0 ]]; then
    dialog --stdout --backtitle "Niente Reporting - Inconsistent ALBUM and DATE tags" --title " Good News! " --msgbox "$REPORT_ALLCLEAR" 12 80
else
    sqlite3 "$CONFDIR/db/$DBNAME.db" <<EOF > "$REPORT_FILE"
.print '<head><title>Niente Report on inconsistent ALBUM & DATE tags</title></head>'
.print '  <link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/nienteico.svg">'
.mode html
.headers on
.print '<style>'
.print '  table { border-collapse: collapse; width: 100%; font-family: serif; font-size: 13px; }'
.print '  th { background-color: #333; color: white; padding: 6px 8px; position: sticky; top: 0; }'
.print '  th, td { border: 1px solid #aaa; padding: 4px 8px; text-align: left; line-height: 1.2; vertical-align: top; }'
/* target the first column (date/time) specifically */
.print '  th:first-child, td:first-child { width: 6%; white-space: nowrap; }'
/* ensure other columns don't force it to shrink or expand weirdly */
.print '  td:not(:first-child) { white-space: normal; }'
.print '  tr:nth-child(even) { background-color: #e0e0e0; }'
.print '  tr:hover { background-color: #ffffcc; }'
.print '  .footer { font-family: serif; font-size: 12px; color: #555; margin-top: 10px; }'
.print '</style>'
.print '<div style="display: flex; align-items: center; margin-bottom: 20px;">'
.print '  <img src="file://$CONFDIR/art/nienteico.png" style="width:80px; height:80px; margin-right:20px;">'
.print '  <h1 style="margin: 0; padding-bottom: 0px;">$REPORT_TITLE</h1>'
.print '</div>'
.print '<div style="clear:both;"></div>'
.print '<table>'
$ALBDATE_SQL;
.print '</table>'

/* 2. Switch to list mode to clear the "Null Null" ghosting */
.mode list
.headers off

.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
.print '<p class="footer">Total rows: '
SELECT count(*) FROM ($ALBDATE_SQL);
.print '</p>'

/* 3. Inject the pre-formatted variable without extra shell quotes */
.print '<p class="footer">Generated on: $REPORT_DATE</p>'
.print '<p class="footer">Records on this report are there because you tagged a recording with one year in its ALBUM tag (e.g., Symphony No. 5 (Karajan - <b>1972</b>)) and then tagged it with a different year in the DATE tag (e.g., <b>1976</b>). The date in the ALBUM tag should always exactly <b>duplicate</b> that found in the DATE tag, so failing to do that is regarded as a logical error (and breach of Axiom 7 of the <a href="https://bbritten.com/articles/axioms" target="_blank">Axioms of Classical Music Tagging!</a>)</p>'
.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
EOF

    output_report
fi
}

####################################################################
# Report 2: TRACKNUMBERS not starting at 1
####################################################################
function report_badtracks {
REPORT_FILE="$CONFDIR/tmp/badtracks.html"
rm -f "$REPORT_FILE" 2>/dev/null
check_database

# Now we can produce the report
BADTRACK_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from (select id from tracks t, (select albumname from tracks group by albumname having min(cast(tracknumber as int)) <> 1) b where b.albumname=t.albumname)")
BADTRACK_SQL="select rtrim(filename, replace(filename, '/', '')) as 'Folder Name', replace(filename, rtrim(filename, replace(filename, '/', '')), '') as 'File Name', tracknumber as 'First Track No.' from tracks t, (select albumname from tracks group by albumname having min(cast(tracknumber as int)) <> 1) b where b.albumname=t.albumname order by 1,2"

REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
REPORT_TITLE="Folders whose first FLAC does not have a TRACKNUMBER=1 tag"
REPORT_ALLCLEAR="\nThere are no known examples of folders where the first FLAC has a TRACKNUMBER tag other than '1'.\\n\\nPress OK to continue."

if [[ $BADTRACK_COUNT -eq 0 ]]; then
    dialog --stdout --backtitle "Niente Reporting - TRACKNUMBER not starting at 1" --title " Good News! " --msgbox "$REPORT_ALLCLEAR" 12 80
else
    sqlite3 "$CONFDIR/db/$DBNAME.db" <<EOF > "$REPORT_FILE"
.print '<head><title>Niente Report on inconsistent ALBUM & DATE tags</title></head>'
.print '  <link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/nienteico.svg">'
.mode html
.headers on
.print '<style>'
.print '  table { border-collapse: collapse; width: 100%; font-family: serif; font-size: 13px; }'
.print '  th { background-color: #333; color: white; padding: 6px 8px; position: sticky; top: 0; }'
.print '  th, td { border: 1px solid #aaa; padding: 4px 8px; text-align: left; line-height: 1.2; vertical-align: top; }'
/* target the first column (date/time) specifically */
.print '  th:first-child, td:first-child { width: 6%; white-space: nowrap; }'
/* ensure other columns don't force it to shrink or expand weirdly */
.print '  td:not(:first-child) { white-space: normal; }'
.print '  tr:nth-child(even) { background-color: #e0e0e0; }'
.print '  tr:hover { background-color: #ffffcc; }'
.print '  .footer { font-family: serif; font-size: 12px; color: #555; margin-top: 10px; }'
.print '</style>'
.print '<div style="display: flex; align-items: center; margin-bottom: 20px;">'
.print '  <img src="file://$CONFDIR/art/nienteico.png" style="width:80px; height:80px; margin-right:20px;">'
.print '  <h1 style="margin: 0; padding-bottom: 0px;">$REPORT_TITLE</h1>'
.print '</div>'
.print '<div style="clear:both;"></div>'
.print '<table>'
$BADTRACK_SQL;
.print '</table>'

/* 2. Switch to list mode to clear the "Null Null" ghosting */
.mode list
.headers off

.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
.print '<p class="footer">Total rows: '
SELECT count(*) FROM ($BADTRACK_SQL);
.print '</p>'

/* 3. Inject the pre-formatted variable without extra shell quotes */
.print '<p class="footer">Generated on: $REPORT_DATE</p>'
.print '<p class="footer">Records on this report are there because the first FLAC found in the folder does not have a TRACKNUMBER of 1. This is considered a violation of <a href="https://bbritten.com/articles/axioms" target=_blank>Axiom 9!</a></p>'
.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
EOF

    output_report
fi
}

####################################################################
# Report 3: PERFORMER v. COMMENT tags
####################################################################
function report_percomm {
REPORT_FILE="$CONFDIR/tmp/percomm.html"
rm -f "$REPORT_FILE" 2>/dev/null
check_database

# Now we can produce the report
BADPERCOM_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from tracks where not instr(comment, performer)")
BADPERCOM_SQL="select rtrim(filename, replace(filename, '/', '')) as 'Folder Name', replace(filename, rtrim(filename, replace(filename, '/', '')), '') as 'File Name', comment, performer from tracks where not instr(comment, performer) order by 1,2"

REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
REPORT_TITLE="FLACs whose COMMENT tag doesn't contain their PERFORMER tag"
REPORT_ALLCLEAR="\nThere are no known examples of FLACs whose COMMENT tag doesn't include a mention of the PERFORMER tag value somewhere within itself.\\n\\nPress OK to continue."

if [[ $BADPERCOM_COUNT -eq 0 ]]; then
    dialog --stdout --backtitle "Niente Reporting - COMMENT tag doesn't mention PERFORMER tag" --title " Good News! " --msgbox "$REPORT_ALLCLEAR" 12 80
else
    sqlite3 "$CONFDIR/db/$DBNAME.db" <<EOF > "$REPORT_FILE"
.print '<head><title>Niente Report on inconsistent ALBUM & DATE tags</title></head>'
.print '  <link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/nienteico.svg">'
.mode html
.headers on
.print '<style>'
.print '  table { border-collapse: collapse; width: 100%; font-family: serif; font-size: 13px; }'
.print '  th { background-color: #333; color: white; padding: 6px 8px; position: sticky; top: 0; }'
.print '  th, td { border: 1px solid #aaa; padding: 4px 8px; text-align: left; line-height: 1.2; vertical-align: top; }'
/* target the first column (date/time) specifically */
.print '  th:first-child, td:first-child { width: 6%; white-space: nowrap; }'
/* ensure other columns don't force it to shrink or expand weirdly */
.print '  td:not(:first-child) { white-space: normal; }'
.print '  tr:nth-child(even) { background-color: #e0e0e0; }'
.print '  tr:hover { background-color: #ffffcc; }'
.print '  .footer { font-family: serif; font-size: 12px; color: #555; margin-top: 10px; }'
.print '</style>'
.print '<div style="display: flex; align-items: center; margin-bottom: 20px;">'
.print '  <img src="file://$CONFDIR/art/nienteico.png" style="width:80px; height:80px; margin-right:20px;">'
.print '  <h1 style="margin: 0; padding-bottom: 0px;">$REPORT_TITLE</h1>'
.print '</div>'
.print '<div style="clear:both;"></div>'
.print '<table>'
$BADPERCOM_SQL;
.print '</table>'

/* 2. Switch to list mode to clear the "Null Null" ghosting */
.mode list
.headers off

.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
.print '<p class="footer">Total rows: '
SELECT count(*) FROM ($BADPERCOM_SQL);
.print '</p>'

/* 3. Inject the pre-formatted variable without extra shell quotes */
.print '<p class="footer">Generated on: $REPORT_DATE</p>'
.print '<p class="footer">Records on this report are there because your COMMENT tag does not mention the name of the "distinguishing artist" you have mentioned in the PERFORMER tag. If you have said, for example, that <b>Michael Collins</b> is the distinguishing artist for a recording (and thus set PERFORMER=Michael Collins) then it is expected that your COMMENT tag will mention the words "Michael Collins" </i>somewhere</i>. The records here break that "rule", which is a violation of <a href="https://bbritten.com/articles/axioms" target="_blank">Axiom 6!</a></p>'
.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
EOF

    output_report
fi
}

####################################################################
# Report 4: PERFORMER v. ALBUM tags
####################################################################
function report_peralb {
REPORT_FILE="$CONFDIR/tmp/peralb.html"
rm -f "$REPORT_FILE" 2>/dev/null
check_database

# Now we can produce the report
BADPERCOM_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from tracks where comment not like '%' || (select substr(bracket_content, 1, instr(bracket_content, ' ') - 1) from (select substr(albumname, instr(albumname, '(') + 1) as bracket_content)) || '%' and albumname like '%(% - %)'")
BADPERCOM_SQL="select rtrim(filename, replace(filename, '/', '')) as 'Folder Name', replace(filename, rtrim(filename, replace(filename, '/', '')), '') as 'File Name', albumname as 'Album Tag', COMMENT as 'Comment Tag', substr(albumname,instr(albumname,'(')+1,(length(albumname)-8)-(instr(albumname, '('))) as 'Expected Name' from tracks where comment not like '%' || (select substr(bracket_content, 1, instr(bracket_content, ' ') - 1) from (select substr(albumname, INSTR(albumname, '(') + 1) as bracket_content)) || '%' and albumname like '%(% - %)' order by 1,2"

REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
REPORT_TITLE="FLACs whose COMMENT and ALBUM tag disagree on the distinguishing artist"
REPORT_ALLCLEAR="\nThere are no known examples of FLACs whose COMMENT and ALBUM tags don't agree on the distinguishing artist name to some extent.\\n\\nPress OK to continue."

if [[ $BADPERCOM_COUNT -eq 0 ]]; then
    dialog --stdout --backtitle "Niente Reporting - inconsistent COMMENT and ALBUM tags" --title " Good News! " --msgbox "$REPORT_ALLCLEAR" 12 80
else
    sqlite3 "$CONFDIR/db/$DBNAME.db" <<EOF > "$REPORT_FILE"
.print '<head><title>Niente Report on inconsistent ALBUM & DATE tags</title></head>'
.print '  <link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/nienteico.svg">'
.mode html
.headers on
.print '<style>'
.print '  table { border-collapse: collapse; width: 100%; font-family: serif; font-size: 13px; }'
.print '  th { background-color: #333; color: white; padding: 6px 8px; position: sticky; top: 0; }'
.print '  th, td { border: 1px solid #aaa; padding: 4px 8px; text-align: left; line-height: 1.2; vertical-align: top; }'
/* target the first column (date/time) specifically */
.print '  th:first-child, td:first-child { width: 6%; white-space: nowrap; }'
/* ensure other columns don't force it to shrink or expand weirdly */
.print '  td:not(:first-child) { white-space: normal; }'
.print '  tr:nth-child(even) { background-color: #e0e0e0; }'
.print '  tr:hover { background-color: #ffffcc; }'
.print '  .footer { font-family: serif; font-size: 12px; color: #555; margin-top: 10px; }'
.print '</style>'
.print '<div style="display: flex; align-items: center; margin-bottom: 20px;">'
.print '  <img src="file://$CONFDIR/art/nienteico.png" style="width:80px; height:80px; margin-right:20px;">'
.print '  <h1 style="margin: 0; padding-bottom: 0px;">$REPORT_TITLE</h1>'
.print '</div>'
.print '<div style="clear:both;"></div>'
.print '<table>'
$BADPERCOM_SQL;
.print '</table>'

/* 2. Switch to list mode to clear the "Null Null" ghosting */
.mode list
.headers off

.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
.print '<p class="footer">Total rows: '
SELECT count(*) FROM ($BADPERCOM_SQL);
.print '</p>'

/* 3. Inject the pre-formatted variable without extra shell quotes */
.print '<p class="footer">Generated on: $REPORT_DATE</p>'
.print '<p class="footer">Records on this report are there because their COMMENT tag and your ALBUM tag do not appear to agree on who the distinguishing artist on a recording happens to be. If you have said that a recording is by "Leonard Bernstein, New York Philharmonic" in the COMMENT tag, for example, then it is expected that the ALBUM tag would mention Leonard Bernstein somewhere, even if only partially: for example, "Symphony No. 1 (Bernstein - 1961)". Conversely, if the ALBUM tag mentions "Peter Grimes (Britten - 1958)", that sets up the expectation that the word "Britten" will appear in the COMMENT tag somewhere. These dependencies flow from <a href="https://bbritten.com/articles/axioms" target="_blank">Axiom 5</a> and records are listed here when they do not follow that logic. The report cannot know whether it is your ALBUM or COMMENT tag that is correct: it can only tell that they are not consistent with each other. The "Expected Name" column only displays what would be expected to be in the COMMENT tag <i><b>if</b></i> the ALBUM tag is correct: it may well not be the ALBUM tag that is right, however!</p>'
.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
EOF

    output_report
fi
}

####################################################################
# Report 5: ARTIST v. COMPOSER tags
####################################################################
function report_artcom {
REPORT_FILE="$CONFDIR/tmp/artcom.html"
rm -f "$REPORT_FILE" 2>/dev/null
check_database

# Now we can produce the report
ARTCOM_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from tracks where artistname<>composername")
ARTCOM_SQL="select rtrim(filename, replace(filename, '/', '')) as 'Folder Name', replace(filename, rtrim(filename, replace(filename, '/', '')), '') as 'File Name' , artistname as 'ARTIST tag', composername as 'COMPOSER tag' from tracks where artistname<>composername order by 1,2"

REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
REPORT_TITLE="FLACs whose ARTIST and COMPOSER tags are different"
REPORT_ALLCLEAR="\nThere are no known examples of FLACs whose ARTIST and COMPOSER tags differ from each other.\\n\\nPress OK to continue."

if [[ $BADPERCOM_COUNT -eq 0 ]]; then
    dialog --stdout --backtitle "Niente Reporting - inconsistent ARTIST and COMPOSER tags" --title " Good News! " --msgbox "$REPORT_ALLCLEAR" 12 80
else
    sqlite3 "$CONFDIR/db/$DBNAME.db" <<EOF > "$REPORT_FILE"
.print '<head><title>Niente Report on inconsistent ALBUM & DATE tags</title></head>'
.print '  <link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/nienteico.svg">'
.mode html
.headers on
.print '<style>'
.print '  table { border-collapse: collapse; width: 100%; font-family: serif; font-size: 13px; }'
.print '  th { background-color: #333; color: white; padding: 6px 8px; position: sticky; top: 0; }'
.print '  th, td { border: 1px solid #aaa; padding: 4px 8px; text-align: left; line-height: 1.2; vertical-align: top; }'
/* target the first column (date/time) specifically */
.print '  th:first-child, td:first-child { width: 6%; white-space: nowrap; }'
/* ensure other columns don't force it to shrink or expand weirdly */
.print '  td:not(:first-child) { white-space: normal; }'
.print '  tr:nth-child(even) { background-color: #e0e0e0; }'
.print '  tr:hover { background-color: #ffffcc; }'
.print '  .footer { font-family: serif; font-size: 12px; color: #555; margin-top: 10px; }'
.print '</style>'
.print '<div style="display: flex; align-items: center; margin-bottom: 20px;">'
.print '  <img src="file://$CONFDIR/art/nienteico.png" style="width:80px; height:80px; margin-right:20px;">'
.print '  <h1 style="margin: 0; padding-bottom: 0px;">$REPORT_TITLE</h1>'
.print '</div>'
.print '<div style="clear:both;"></div>'
.print '<table>'
$ARTCOM_SQL;
.print '</table>'

/* 2. Switch to list mode to clear the "Null Null" ghosting */
.mode list
.headers off

.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
.print '<p class="footer">Total rows: '
SELECT count(*) FROM ($ARTCOM_SQL);
.print '</p>'

/* 3. Inject the pre-formatted variable without extra shell quotes */
.print '<p class="footer">Generated on: $REPORT_DATE</p>'
.print '<p class="footer">Records on this report are there because their COMPOSER and ARTIST tags are not identical. According to <a href="https://bbritten.com/articles/axioms" target="_blank">Axiom 2</a>, they should be <b>precisely</b> the same. These records are shown because they violate that rule.</p>'
.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
EOF

    output_report
fi
}

####################################################################
# Report 6: Bitdepth and Sample Rates that seem incongruous
####################################################################
function report_badbits {
REPORT_FILE="$CONFDIR/tmp/badbits.html"
rm -f "$REPORT_FILE" 2>/dev/null
check_database

# Now we can produce the report
BADBIT_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from tracks where (bitdepth=16 and sample_rate>48000) or (bitdepth=24 and sample_rate<48000)")
BADBIT_SQL="select rtrim(filename, replace(filename, '/', '')) as 'Folder Name', replace(filename, rtrim(filename, replace(filename, '/', '')), '') as 'File Name', bitdepth as 'Bit Depth', sample_rate as 'Sample Rate' from (select * from tracks where (bitdepth=16 and sample_rate>48000) or (bitdepth=24 and sample_rate<48000)) order by 1,2"

REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
REPORT_TITLE="FLACs whose bit-depth and sample rate seem incongruous"
REPORT_ALLCLEAR="\nThere are no known examples of FLACs with apparently inappropriate bit depth & sample rate combinations.\\n\\nPress OK to continue."

if [[ $BADPERCOM_COUNT -eq 0 ]]; then
    dialog --stdout --backtitle "Niente Reporting - incongrous bit-depth and sample rates" --title " Good News! " --msgbox "$REPORT_ALLCLEAR" 12 80
else
    sqlite3 "$CONFDIR/db/$DBNAME.db" <<EOF > "$REPORT_FILE"
.print '<head><title>Niente Report on inconsistent ALBUM & DATE tags</title></head>'
.print '  <link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/nienteico.svg">'
.mode html
.headers on
.print '<style>'
.print '  table { border-collapse: collapse; width: 100%; font-family: serif; font-size: 13px; }'
.print '  th { background-color: #333; color: white; padding: 6px 8px; position: sticky; top: 0; }'
.print '  th, td { border: 1px solid #aaa; padding: 4px 8px; text-align: left; line-height: 1.2; vertical-align: top; }'
/* target the first column (date/time) specifically */
.print '  th:first-child, td:first-child { width: 6%; white-space: nowrap; }'
/* ensure other columns don't force it to shrink or expand weirdly */
.print '  td:not(:first-child) { white-space: normal; }'
.print '  tr:nth-child(even) { background-color: #e0e0e0; }'
.print '  tr:hover { background-color: #ffffcc; }'
.print '  .footer { font-family: serif; font-size: 12px; color: #555; margin-top: 10px; }'
.print '</style>'
.print '<div style="display: flex; align-items: center; margin-bottom: 20px;">'
.print '  <img src="file://$CONFDIR/art/nienteico.png" style="width:80px; height:80px; margin-right:20px;">'
.print '  <h1 style="margin: 0; padding-bottom: 0px;">$REPORT_TITLE</h1>'
.print '</div>'
.print '<div style="clear:both;"></div>'
.print '<table>'
$BADBIT_SQL;
.print '</table>'

/* 2. Switch to list mode to clear the "Null Null" ghosting */
.mode list
.headers off

.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
.print '<p class="footer">Total rows: '
SELECT count(*) FROM ($BADBIT_SQL);
.print '</p>'

/* 3. Inject the pre-formatted variable without extra shell quotes */
.print '<p class="footer">Generated on: $REPORT_DATE</p>'
.print '<p class="footer">Records on this report are there because their bit-depth (usually 16 or 24 bit) and their sample rate do not seem to make sense. If a recording is 16-bit, it is unusual for it to have a sample rate over 48,000Hz; conversely, a 192,000Hz sample rate recording is unlikely to be made with only 16-bit samples. This report flags any recording where 16-bit recordings exceeed 48,000Hz or where 24-bit recordings have a sampling frequency lower that 48,000Hz: such combinations would just not seem to be sensible.</p>'
.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
EOF

    output_report
fi
}

function main {
REPORT_TYPE=$1
case $REPORT_TYPE in
  dates ) report_baddates; nsubmenuoptions logical;;
  track ) report_badtracks; nsubmenuoptions logical;;
  percom) report_percomm; nsubmenuoptions logical;;
  peralb) report_peralb; nsubmenuoptions logical;;
  artcom) report_artcom; nsubmenuoptions logical;;
  badbit) report_badbits; nsubmenuoptions logical;;
esac
 }

main "$@"