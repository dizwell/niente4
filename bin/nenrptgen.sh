#!/usr/bin/env bash
####################################################################
#
# nenrptgen: routine for producing all the "General Reports", namely:
#
# 1. Aggregate Statistics
# 2. Physical Corruption
# 3. Files not yet analysed
# 4. Files with missing 'compulsory' tags
#
####################################################################
function output_report {
source "$CONFDIR/bin/nenoutput.sh" "$REPORT_FILE"
}

####################################################################
# Report 1: Aggregate Statistics
####################################################################
function report_aggstats {
REPORT_FILE="$CONFDIR/tmp/aggstats.html"
rm -f "$REPORT_FILE" 2>/dev/null
check_database

# Now we can produce the report: if art doesn't have to be square, we don't report on it.
if [[ $SQUAREART -eq 1 ]]; then
  AGGSTATS_SQL="select 'G1' as 'Statistic', 'Total number of recordings: ' as 'Statistic Name',  count(distinct substr(filename, 1, length(filename) - instr(replace(filename, '/', 'x'), '/'))) as 'Count' from tracks union
  select 'G2', 'FLACs with physical integrity problems: ', count(*) as 'Record Count' from (select * from tracks where hash_orig<>hash_new or hash_orig is null or hash_new is null) union
  select 'G3', 'FLACs not yet analysed: ', count(*) from (select * from tracks where (bitdepth IS NULL OR bitdepth='') AND (sample_rate IS NULL OR sample_rate='') AND (hash_orig IS NULL OR hash_orig='') AND (hash_new IS NULL OR hash_new='') AND (album_year IS NULL OR album_year='') AND (date_tag IS NULL OR date_tag='') AND (performer IS NULL OR performer='') AND (comment IS NULL OR comment='') AND (albumname IS NULL OR albumname='') AND (artistname IS NULL OR artistname='') AND (composername IS NULL OR composername='') AND (genrename IS NULL OR genrename='') AND (tracktitle IS NULL OR tracktitle='')) union
  select 'G4', 'Missing Tags of any kind: ', count(*) from
  (SELECT * FROM tracks WHERE ((bitdepth IS NULL OR bitdepth='') OR (sample_rate IS NULL OR sample_rate='') OR (hash_orig IS NULL OR hash_orig='') OR (hash_new IS NULL OR hash_new='') OR (album_year IS NULL OR album_year='') OR (date_tag IS NULL OR date_tag='') OR (performer IS NULL OR performer='') OR (comment IS NULL OR comment='') OR (albumname IS NULL OR albumname='') OR (artistname IS NULL OR artistname='') OR (composername IS NULL OR composername='') OR (genrename IS NULL OR genrename='') OR (tracktitle IS NULL OR tracktitle='')) AND NOT ((bitdepth IS NULL OR bitdepth='') AND (sample_rate IS NULL OR sample_rate='') AND (hash_orig IS NULL OR hash_orig='') AND (hash_new IS NULL OR hash_new='') AND (album_year IS NULL OR album_year='') AND (date_tag IS NULL OR date_tag='') AND (performer IS NULL OR performer='') AND (comment IS NULL OR comment='') AND (albumname IS NULL OR albumname='') AND (artistname IS NULL OR artistname='') AND (composername IS NULL OR composername='') AND (genrename IS NULL OR genrename='') AND (tracktitle IS NULL OR tracktitle=''))) union
  select 'L1', 'Inconsistent YEAR/ALBUM tags: ',count(*) from tracks where album_year<>date_tag and length(DATE_TAG)>0 and length(ALBUM_YEAR)>0 union
  select 'L2', 'Inconsistent TRACKNUMBER tags: ', count(*) from (select  id from tracks t, (select albumname from tracks group by albumname having min(cast(tracknumber as int)) <> 1) b where b.albumname=t.albumname) union
  select 'L3', 'Inconsistent PERFORMER/COMMENT tags: ', count(*) from tracks where not instr(comment, performer) union
  select 'L4', 'Inconsistent PERFORMER/ALBUM tags: ', count(*) from tracks where not instr(performer, substr(albumname,instr(albumname,'(')+1,(length(albumname)-8)-(instr(albumname, '(')))) union
  select 'L5', 'Inconsistent ARTIST/COMPOSER tags: ', count(*) from tracks where artistname<>composername union
  select 'L6', 'Inconsistent Bit Depth/Sample Rates: ', count(*) from (select * from tracks where bitdepth=16 and sample_rate>48000 union select * from tracks where bitdepth=24 and sample_rate<48000) union
  select 'O1','Album Art size issues:', count(*) from (select * from albumart where (albumartheight < $SMALLART or albumartwidth < $SMALLART) or (albumartheight > $LARGEART or albumartwidth > $LARGEART) or (albumartheight <> albumartwidth) or albumartheight is null or albumartheight = '' or albumartwidth is null or albumartwidth = '') union"

  if [[ $REPORTMAXV == "yes" ]]; then AGGSTATS_SQL="$AGGSTATS_SQL select 'O2', 'Potential Volume Boosts:', count(*) from (select filename, min(boost) from maxvolumes group by filename having boost > $VOLUMETHRESHOLD) union"; fi
  if [[ $NAMEBITS == "yes" ]]; then AGGSTATS_SQL="$AGGSTATS_SQL select 'O4', 'Missing audio data in filenames:', count(*) from (select filename, bitdepth, sample_rate, instr(filename, computed_bitdepth||'-'||computed_samplerate) as intest, computed_bitdepth, computed_samplerate from ( select filename, bitdepth, sample_rate, ifnull(bitdepth, 1) as computed_bitdepth, ifnull(sample_rate,1) as computed_samplerate from tracks ) where intest=0) union"; fi

  AGGSTATS_SQL="$AGGSTATS_SQL select 'O5', 'Folders containing multiple physical FLACs:', count(*) from (select rtrim(filename, replace(filename, '/', '')), composername, albumname, count(*) from tracks group by rtrim(filename, replace(filename, '/', '')), composername, albumname having count(*) > 1) union
  select 'O6', 'Possible duplicate recordings:', count(*) from (select hash_orig from tracks where hash_orig in (select hash_orig from tracks group by hash_orig having count(*)>1)) union
  select 'O3', 'Missing ReplayGain information:', count(*) from tracks where replaygain is null or replaygain='' union
  select 'T1', 'Last integrity check done on (y-m-d):', substr(max(operation_date),1,10) from refresh_logs where operation like '%integrity check%'
  order by 1"
else
  AGGSTATS_SQL="select 'G1' as 'Statistic', 'Total number of FLACs: ' as 'Statistic Name', count(distinct substr(filename, 1, length(filename) - instr(replace(filename, '/', 'x'), '/'))) as 'Count' from tracks union
  select 'G2', 'FLACs with physical integrity problems: ', count(*) as 'Record Count' from (select * from tracks where hash_orig<>hash_new or hash_orig is null or hash_new is null) union
  select 'G3', 'FLACs not yet analysed: ', count(*) from (select * from tracks where (bitdepth IS NULL OR bitdepth='') AND (sample_rate IS NULL OR sample_rate='') AND (hash_orig IS NULL OR hash_orig='') AND (hash_new IS NULL OR hash_new='') AND (album_year IS NULL OR album_year='') AND (date_tag IS NULL OR date_tag='') AND (performer IS NULL OR performer='') AND (comment IS NULL OR comment='') AND (albumname IS NULL OR albumname='') AND (artistname IS NULL OR artistname='') AND (composername IS NULL OR composername='') AND (genrename IS NULL OR genrename='') AND (tracktitle IS NULL OR tracktitle='')) union
  select 'G4', 'Missing Tags of any kind: ', count(*) from
  (SELECT * FROM tracks WHERE ((bitdepth IS NULL OR bitdepth='') OR (sample_rate IS NULL OR sample_rate='') OR (hash_orig IS NULL OR hash_orig='') OR (hash_new IS NULL OR hash_new='') OR (album_year IS NULL OR album_year='') OR (date_tag IS NULL OR date_tag='') OR (performer IS NULL OR performer='') OR (comment IS NULL OR comment='') OR (albumname IS NULL OR albumname='') OR (artistname IS NULL OR artistname='') OR (composername IS NULL OR composername='') OR (genrename IS NULL OR genrename='') OR (tracktitle IS NULL OR tracktitle='')) AND NOT ((bitdepth IS NULL OR bitdepth='') AND (sample_rate IS NULL OR sample_rate='') AND (hash_orig IS NULL OR hash_orig='') AND (hash_new IS NULL OR hash_new='') AND (album_year IS NULL OR album_year='') AND (date_tag IS NULL OR date_tag='') AND (performer IS NULL OR performer='') AND (comment IS NULL OR comment='') AND (albumname IS NULL OR albumname='') AND (artistname IS NULL OR artistname='') AND (composername IS NULL OR composername='') AND (genrename IS NULL OR genrename='') AND (tracktitle IS NULL OR tracktitle=''))) union
  select 'L1', 'Inconsistent YEAR/ALBUM tags: ',count(*) from tracks where album_year<>date_tag and length(DATE_TAG)>0 and length(ALBUM_YEAR)>0 union
  select 'L2', 'Inconsistent TRACKNUMBER tags: ',count(*) from (select  id from tracks t, (select albumname from tracks group by albumname having min(cast(tracknumber as int)) <> 1) b where b.albumname=t.albumname) union
  select 'L3', 'Inconsistent PERFORMER/COMMENT tags: ', count(*) from tracks where not instr(comment, performer) union
  select 'L4', 'Inconsistent PERFORMER/ALBUM tags: ', count(*) from tracks where not instr(performer, substr(albumname,instr(albumname,'(')+1,(length(albumname)-8)-(instr(albumname, '(')))) union
  select 'L5', 'Inconsistent ARTIST/COMPOSER tags: ', count(*) from tracks where artistname<>composername union
  select 'L6', 'Inconsistent Bit Depth/Sample Rates: ', count(*) from (select * from tracks where bitdepth=16 and sample_rate>48000 union select * from tracks where bitdepth=24 and sample_rate<48000) union
  select 'O1','Album Art size issues:', count(*) from (select * from albumart where (albumartheight < $SMALLART or albumartwidth < $SMALLART) or (albumartheight > $LARGEART or albumartwidth > $LARGEART) or albumartheight is null or albumartheight = '' or albumartwidth is null or albumartwidth = '') union"

  if [[ $REPORTMAXV == "yes" ]]; then AGGSTATS_SQL="$AGGSTATS_SQL select 'O2', 'Potential Volume Boosts:', count(*) from (select id, filename, min(boost) from maxvolumes group by filename having boost > $VOLUMETHRESHOLD) union"; fi
  if [[ $NAMEBITS == "yes" ]]; then AGGSTATS_SQL="$AGGSTATS_SQL select 'O4', 'Missing audio data in filenames:', count(*) from (select filename, bitdepth, sample_rate, instr(filename, computed_bitdepth||'-'||computed_samplerate) as intest, computed_bitdepth, computed_samplerate from ( select filename, bitdepth, sample_rate, ifnull(bitdepth, 1) as computed_bitdepth, ifnull(sample_rate,1) as computed_samplerate from tracks ) where intest=0) union"; fi

  AGGSTATS_SQL="$AGGSTATS_SQL select 'O5', 'Folders containing multiple physical FLACs:', count(*) from (select rtrim(filename, replace(filename, '/', '')), composername, albumname, count(*) from tracks group by rtrim(filename, replace(filename, '/', '')), composername, albumname having count(*) > 1) union
  select 'O6', 'Possible duplicate recordings:', count(*) from (select hash_orig from tracks where hash_orig in (select hash_orig from tracks group by hash_orig having count(*)>1)) union
  select 'O3', 'Missing ReplayGain information:', count(*) from tracks where replaygain is null or replaygain='' union
  select 'T1', 'Last integrity check done on (y-m-d):', substr(max(operation_date),1,10) from refresh_logs where operation like '%integrity check%'
  order by 1"
fi

REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
REPORT_TITLE="Aggregate Statistics, collected from database <i>$DBNAME</i>"

sqlite3 "$CONFDIR/db/$DBNAME.db" <<EOF > "$REPORT_FILE"
.print '<head><title>Niente Stats Report</title></head>'
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
.print '  th:nth-child(3), td:nth-child(3) { text-align: right; }'
.print '  tr:hover { background-color: #ffffcc; }'
.print '  .footer { font-family: serif; font-size: 12px; color: #555; margin-top: 10px; }'
.print '</style>'
.print '<div style="display: flex; align-items: center; border-bottom: 1px solid #ccc; margin-bottom: 20px;">'
.print '  <a href="https://bbritten.com" target="_blank"><img src="file://$CONFDIR/art/nienteico.png" style="width:80px; height:80px; margin-right:20px;"></a>'
.print '  <h1 style="margin: 0; padding-bottom: 0px;">$REPORT_TITLE</h1>'
.print '</div>'
.print '<div style="clear:both;"></div>'
.print '<table>'
$AGGSTATS_SQL;
.print '</table>'

/* 2. Switch to list mode to clear the "Null Null" ghosting */
.mode list
.headers off

.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
.print '<p class="footer">Total rows: '
SELECT count(*) FROM ($AGGSTATS_SQL);
.print '</p>'

/* 3. Inject the pre-formatted variable without extra shell quotes */
.print '<p class="footer">Generated on: $REPORT_DATE</p>'
.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
EOF

# Open the file based on OS
output_report
}

####################################################################
# Report 2: Physical Corruption, based on mis-matched HASH values
####################################################################
function report_physical {
REPORT_FILE="$CONFDIR/tmp/physicalcorrupt.html"
rm -f "$REPORT_FILE" 2>/dev/null
check_database

# Now we can produce the report
PHYS_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from (select * from tracks where hash_orig<>hash_new or hash_orig is null or hash_new is null)")
PHYS_SQL="select rtrim(filename, replace(filename, '/', '')) as 'Folder Name', replace(filename, rtrim(filename, replace(filename, '/', '')), '') as 'File Name', coalesce(nullif(hash_orig, ''), 'Empty') as 'Original Hash', coalesce(nullif(hash_new, ''), 'Empty') as 'Fresh Hash' from tracks where hash_orig<>hash_new or hash_orig is null or hash_new is null order by 1,2"

REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
REPORT_TITLE="Music files that are possibly internally and physically corrupt"
REPORT_ALLCLEAR="\nAll known music files appear to have no discrepancies between the original and freshly-calculated MD5 hashes of their audio signal: nothing appears to be physically corrupt.\\n\\nPress OK to continue."

if [[ $PHYS_COUNT -eq 0 ]]; then
    dialog --stdout --backtitle "Niente Reporting - Physically Corrupt Music Files" --title " Good News! " --msgbox "$REPORT_ALLCLEAR" 12 80
else
    sqlite3 "$CONFDIR/db/$DBNAME.db" <<EOF > "$REPORT_FILE"
.print '<head><title>Niente Physical Corruption Report</title></head>'
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
.print '<div style="display: flex; align-items: center; border-bottom: 1px solid #ccc; margin-bottom: 20px;">'
.print '  <a href="https://bbritten.com" target="_blank"><img src="file://$CONFDIR/art/nienteico.png" style="width:80px; height:80px; margin-right:20px;"></a>'
.print '  <h1 style="margin: 0; padding-bottom: 0px;">$REPORT_TITLE</h1>'
.print '</div>'
.print '<div style="clear:both;"></div>'
.print '<table>'
$PHYS_SQL;
.print '</table>'

/* 2. Switch to list mode to clear the "Null Null" ghosting */
.mode list
.headers off

.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
.print '<p class="footer">Total rows: '
SELECT count(*) FROM ($PHYS_SQL);
.print '</p>'

/* 3. Inject the pre-formatted variable without extra shell quotes */
.print '<p class="footer">Generated on: $REPORT_DATE</br>
.print '<p class="footer">Records on this report are there (1) because their original MD5 "fingerprint" does not match the one Niente has freshly computed; or (2) because the original MD5 fingerprint is missing entirely; or (3) there is no freshly-computed MD5 with which to compare the original one.</p>'
.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
EOF

    output_report
fi
}

####################################################################
# Report 3: Not Yet Analysed, because all key tags are empty
####################################################################
function report_notanalysed {
REPORT_FILE="$CONFDIR/tmp/nya.html"
rm -f "$REPORT_FILE" 2>/dev/null
check_database

# Now we can produce the report
NYA_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from tracks where (bitdepth IS NULL OR bitdepth='') AND (sample_rate IS NULL OR sample_rate='') AND (hash_orig IS NULL OR hash_orig='') AND (hash_new IS NULL OR hash_new='') AND (album_year IS NULL OR album_year='') AND (date_tag IS NULL OR date_tag='') AND (performer IS NULL OR performer='') AND (comment IS NULL OR comment='') AND (albumname IS NULL OR albumname='') AND (artistname IS NULL OR artistname='') AND (composername IS NULL OR composername='') AND (genrename IS NULL OR genrename='') AND (tracktitle IS NULL OR tracktitle='')")
NYA_SQL="SELECT rtrim(filename, replace(filename, '/', '')) AS 'Folder Name', replace(filename, rtrim(filename, replace(filename, '/', '')), '') AS 'File Name', 'All of them' AS 'Missing Tags' FROM tracks WHERE (bitdepth IS NULL OR bitdepth='') AND (sample_rate IS NULL OR sample_rate='') AND (hash_orig IS NULL OR hash_orig='') AND (hash_new IS NULL OR hash_new='') AND (album_year IS NULL OR album_year='') AND (date_tag IS NULL OR date_tag='') AND (performer IS NULL OR performer='') AND (comment IS NULL OR comment='') AND (albumname IS NULL OR albumname='') AND (artistname IS NULL OR artistname='') AND (composername IS NULL OR composername='') AND (genrename IS NULL OR genrename='') AND (tracktitle IS NULL OR tracktitle='') ORDER BY filename"

REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
REPORT_TITLE="Music files that appear not to have been subject to Integrity Checking"
REPORT_ALLCLEAR="\nAll known music files appear to have been fully checked and are not missing any metadata.\\n\\nPress OK to continue."

if [[ $NYA_COUNT -eq 0 ]]; then
    dialog --stdout --backtitle "Niente Reporting - Physically Corrupt Music Files" --title " Good News! " --msgbox "$REPORT_ALLCLEAR" 12 80
else
    sqlite3 "$CONFDIR/db/$DBNAME.db" <<EOF > "$REPORT_FILE"
.print '<head><title>Niente Not Yet Analysed Report</title></head>'
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
.print '<div style="display: flex; align-items: center; border-bottom: 1px solid #ccc; margin-bottom: 20px;">'
.print '  <a href="https://bbritten.com" target="_blank"><img src="file://$CONFDIR/art/nienteico.png" style="width:80px; height:80px; margin-right:20px;"></a>'
.print '  <h1 style="margin: 0; padding-bottom: 0px;">$REPORT_TITLE</h1>'
.print '</div>'
.print '<div style="clear:both;"></div>'
.print '<table>'
$NYA_SQL;
.print '</table>'

/* 2. Switch to list mode to clear the "Null Null" ghosting */
.mode list
.headers off

.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
.print '<p class="footer">Total rows: '
SELECT count(*) FROM ($NYA_SQL);
.print '</p>'

/* 3. Inject the pre-formatted variable without extra shell quotes */
.print '<p class="footer">Generated on: $REPORT_DATE</br>'
.print '<p class="footer">Records on this report are there because they are missing <u><b>all</b></u> the "compulsory" tags that are meant to be there, according to <a href="https://bbritten.com/articles/axioms" target="_blank">the Axioms of Classical Music</a>, Axiom 1. That implies that they have not yet been subject to an integrity check of any kind.</p>'
.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
EOF

    output_report
fi
}

####################################################################
# Report 4: Metatag issues, because SOME key tags are empty
####################################################################
function report_blanktags {
REPORT_FILE="$CONFDIR/tmp/blanktags.html"
rm -f "$REPORT_FILE" 2>/dev/null
check_database

MISSING_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"SELECT count(*) FROM tracks WHERE ((bitdepth IS NULL OR bitdepth='') OR (sample_rate IS NULL OR sample_rate='') OR (hash_orig IS NULL OR hash_orig='') OR (hash_new IS NULL OR hash_new='') OR (album_year IS NULL OR album_year='') OR (date_tag IS NULL OR date_tag='') OR (performer IS NULL OR performer='') OR (comment IS NULL OR comment='') OR (albumname IS NULL OR albumname='') OR (artistname IS NULL OR artistname='') OR (composername IS NULL OR composername='') OR (genrename IS NULL OR genrename='') OR (tracktitle IS NULL OR tracktitle='')) AND NOT ((bitdepth IS NULL OR bitdepth='') AND (sample_rate IS NULL OR sample_rate='') AND (hash_orig IS NULL OR hash_orig='') AND (hash_new IS NULL OR hash_new='') AND (album_year IS NULL OR album_year='') AND (date_tag IS NULL OR date_tag='') AND (performer IS NULL OR performer='') AND (comment IS NULL OR comment='') AND (albumname IS NULL OR albumname='') AND (artistname IS NULL OR artistname='') AND (composername IS NULL OR composername='') AND (genrename IS NULL OR genrename='') AND (tracktitle IS NULL OR tracktitle=''))")

MISSING_SQL="SELECT rtrim(filename, replace(filename, '/', '')) AS 'Folder Name', replace(filename, rtrim(filename, replace(filename, '/', '')), '') AS 'File Name', ltrim(CASE WHEN (bitdepth IS NULL OR bitdepth='') THEN ', Bit-depth' ELSE '' END || CASE WHEN (sample_rate IS NULL OR sample_rate='') THEN ', Sample rate' ELSE '' END || CASE WHEN (hash_orig IS NULL OR hash_orig='') THEN ', Original MD5 Hash' ELSE '' END || CASE WHEN (hash_new IS NULL OR hash_new='') THEN ', Fresh MD5 Hash' ELSE '' END || CASE WHEN (album_year IS NULL OR album_year='') THEN ', Recording Year' ELSE '' END || CASE WHEN (date_tag IS NULL OR date_tag='') THEN ', Date' ELSE '' END || CASE WHEN (performer IS NULL OR performer='') THEN ', Distinguishing Artist' ELSE '' END || CASE WHEN (comment IS NULL OR comment='') THEN ', Comment' ELSE '' END || CASE WHEN (albumname IS NULL OR albumname='') THEN ', Album' ELSE '' END || CASE WHEN (artistname IS NULL OR artistname='') THEN ', Artist' ELSE '' END || CASE WHEN (composername IS NULL OR composername='') THEN ', Composer' ELSE '' END || CASE WHEN (genrename IS NULL OR genrename='') THEN ', Genre' ELSE '' END || CASE WHEN (tracktitle IS NULL OR tracktitle='') THEN ', Title' ELSE '' END, ', ') AS 'Missing Tags' FROM tracks WHERE ((bitdepth IS NULL OR bitdepth='') OR (sample_rate IS NULL OR sample_rate='') OR (hash_orig IS NULL OR hash_orig='') OR (hash_new IS NULL OR hash_new='') OR (album_year IS NULL OR album_year='') OR (date_tag IS NULL OR date_tag='') OR (performer IS NULL OR performer='') OR (comment IS NULL OR comment='') OR (albumname IS NULL OR albumname='') OR (artistname IS NULL OR artistname='') OR (composername IS NULL OR composername='') OR (genrename IS NULL OR genrename='') OR (tracktitle IS NULL OR tracktitle='')) AND NOT ((bitdepth IS NULL OR bitdepth='') AND (sample_rate IS NULL OR sample_rate='') AND (hash_orig IS NULL OR hash_orig='') AND (hash_new IS NULL OR hash_new='') AND (album_year IS NULL OR album_year='') AND (date_tag IS NULL OR date_tag='') AND (performer IS NULL OR performer='') AND (comment IS NULL OR comment='') AND (albumname IS NULL OR albumname='') AND (artistname IS NULL OR artistname='') AND (composername IS NULL OR composername='') AND (genrename IS NULL OR genrename='') AND (tracktitle IS NULL OR tracktitle='') ) ORDER BY filename"

REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
REPORT_TITLE="Music files that appear to be missing one or more important tags"
REPORT_ALLCLEAR="\nAll known music files appear to have a complete complement of metadata tags.\\n\\nPress OK to continue."

if [[ $MISSING_COUNT -eq 0 ]]; then
    dialog --stdout --backtitle "Niente Reporting - Physically Corrupt Music Files" --title " Good News! " --msgbox "$REPORT_ALLCLEAR" 12 80
else
    sqlite3 "$CONFDIR/db/$DBNAME.db" <<EOF > "$REPORT_FILE"
.print '<head><title>Niente Not Yet Analysed Report</title></head>'
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
.print '<div style="display: flex; align-items: center; border-bottom: 1px solid #ccc; margin-bottom: 20px;">'
.print '  <a href="https://bbritten.com" target="_blank"><img src="file://$CONFDIR/art/nienteico.png" style="width:80px; height:80px; margin-right:20px;"></a>'
.print '  <h1 style="margin: 0; padding-bottom: 0px;">$REPORT_TITLE</h1>'
.print '</div>'
.print '<div style="clear:both;"></div>'
.print '<table>'
$MISSING_SQL;
.print '</table>'

/* 2. Switch to list mode to clear the "Null Null" ghosting */
.mode list
.headers off

.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
.print '<p class="footer">Total rows: '
SELECT count(*) FROM ($MISSING_SQL);
.print '</p>'

/* 3. Inject the pre-formatted variable without extra shell quotes */
.print '<p class="footer">Generated on: $REPORT_DATE</br>'
.print '<p class="footer">Records on this report are there because they are missing one or more of the "compulsory" tags that are meant to be there, according to <a href="https://bbritten.com/articles/axioms" target="_blank">the Axioms of Classical Music</a>. That implies that though they have been subject to an integrity check, the metaddata tags Niente expects to be there were probably never added during your tagging process.</p>'
.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
EOF

    output_report
fi
}

function main {
REPORT_TYPE=$1
case $REPORT_TYPE in
  aggsts) report_aggstats; nsubmenuoptions general;;
  phys  ) report_physical; nsubmenuoptions general;;
  nya   ) report_notanalysed; nsubmenuoptions general;;
  nulltg) report_blanktags; nsubmenuoptions general;;
esac
 }

main "$@"
