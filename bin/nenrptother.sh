#!/usr/bin/env bash
####################################################################
#
# nenrptother: routine for producing all the "Other Reports", namely:
#
# 1. Album Art issues
# 2. Volume Boosts
# 3. Missing ReplayGains
# 4. Files with bit/sample rate missing from physical names
# 5. Multiple files per album
# 6. Possible duplicates
# 7. Display the Operations Log
#
####################################################################
function output_report {
source "$CONFDIR/bin/nenoutput.sh" "$REPORT_FILE"
}

####################################################################
# Report 1: Files with assorted Album Art issues
####################################################################
function report_art {
REPORT_FILE="$CONFDIR/tmp/badart.html"
rm -f "$REPORT_FILE" 2>/dev/null
check_database

# Now we can produce the report
if [[ $SQUAREART -eq 1 ]]; then
  ART_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from albumart where (albumartheight < $SMALLART or albumartwidth < $SMALLART) or (albumartheight > $LARGEART or albumartwidth > $LARGEART) or (albumartheight <> albumartwidth) or albumartheight is null or albumartheight = '' or albumartwidth is null or albumartwidth = '';")
  ART_SQL="select rtrim(filename, replace(filename, '/', '')) as 'Folder Name', replace(filename, rtrim(filename, replace(filename, '/', '')), '') as 'File Name', coalesce(nullif(albumartheight, ''), 'Empty') as 'Art Height', coalesce(nullif(albumartwidth, ''), 'Empty') as 'Art Width' from albumart where (albumartheight < $SMALLART or albumartwidth < $SMALLART) or (albumartheight > $LARGEART or albumartwidth > $LARGEART) or (albumartheight <> albumartwidth) or albumartheight is null or albumartheight = '' or albumartwidth is null or albumartwidth = '' order by filename"
else
  ART_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from albumart where (albumartheight < $SMALLART or albumartwidth < $SMALLART) or (albumartheight > $LARGEART or albumartwidth > $LARGEART) or albumartheight is null or albumartheight = '' or albumartwidth is null or albumartwidth = '';")
  ART_SQL="select rtrim(filename, replace(filename, '/', '')) as 'Folder Name', replace(filename, rtrim(filename, replace(filename, '/', '')), '') as 'File Name', coalesce(nullif(albumartheight, ''), 'Empty') as 'Art Height', coalesce(nullif(albumartwidth, ''), 'Empty') as 'Art Width' from albumart where (albumartheight < $SMALLART or albumartwidth < $SMALLART) or (albumartheight > $LARGEART or albumartwidth > $LARGEART) or albumartheight is null or albumartheight = '' or albumartwidth is null or albumartwidth = '' order by filename"
fi

REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
REPORT_TITLE="Files with embedded album art issues"
REPORT_ALLCLEAR="\\nAll known music files appear to have good embedded album artwork.\\n\\nPress OK to continue."

if [[ $ART_COUNT -eq 0 ]]; then
    dialog --stdout --backtitle "Niente Reporting - Album Art" --title " Good News! " --msgbox "$REPORT_ALLCLEAR" 9 80
else
    sqlite3 "$CONFDIR/db/$DBNAME.db" <<EOF > "$REPORT_FILE"
.print '<head><title>Niente Art Report</title></head>'
.print '  <link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/nienteico.svg">'
.mode html
.headers on
.print '<style>'
.print '  table { border-collapse: collapse; width: 100%; font-family: serif; font-size: 13px; }'
.print '  th { background-color: #333; color: white; padding: 6px 8px; position: sticky; top: 0; }'
.print '  th, td { border: 1px solid #aaa; padding: 4px 8px; text-align: left; line-height: 1.2; vertical-align: top; }'
.print '  td:first-child { white-space: normal; word-break: break-all; }'
.print '  td:not(:first-child) { white-space: nowrap; width: 1%; }'
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
$ART_SQL;
.print '</table>'

/* 2. Switch to list mode to clear the "Null Null" ghosting */
.mode list
.headers off

.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
.print '<p class="footer">Total rows: '
SELECT count(*) FROM ($ART_SQL);
.print '</p>'

/* 3. Inject the pre-formatted variable without extra shell quotes */
.print '<p class="footer">Generated on: $REPORT_DATE</p>'
.print '<p class="footer">Records on this report are here (1) because their embedded album art is not square when the configuration file has been set to expect them to be; or (2) because their embedded album art is <i>smaller</i> than the "small art threshold size" set in the configuration file; or (3) because their embedded album art is <i>larger</i> than the "large art threshold size" set in the configuration file; or (4) because no album art size has been detected at all -perhaps because no album art integrity check has yet been performed on them. The <i>is it square?</i> factor only applies if you have said it should matter in the configuration file.</p>'
.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
EOF

    output_report
fi
}

####################################################################
# Report 2: Possible physical (peak loudness) volume boosts
####################################################################
function report_maxv {
REPORT_FILE="$CONFDIR/tmp/maxv.html"
rm -f "$REPORT_FILE" 2>/dev/null
check_database

# Now we can produce the report
MAXV_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from (select $FOLDERSQL from maxvolumes group by $FOLDERSQL having min(boost) > $VOLUMETHRESHOLD)")
MAXV_SQL="select $FOLDERSQL as 'Folder Name', min(boost) as 'Potential Boost' from maxvolumes group by $FOLDERSQL having min(boost) > $VOLUMETHRESHOLD order by 1"

REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
REPORT_TITLE="Music folders with potentially useful <i>physical</i> volume boosts"
REPORT_ALLCLEAR="\\nAll known music files appear to have been volume-boosted to their maximum, non-distorting amount.\\n\\nPress OK to continue."

if [[ $MAXV_COUNT -eq 0 ]]; then
    dialog --stdout --backtitle "Niente Reporting - Physical Volume Boosts" --title " Good News! " --msgbox "$REPORT_ALLCLEAR" 9 80
else
    sqlite3 "$CONFDIR/db/$DBNAME.db" <<EOF > "$REPORT_FILE"
.print '<head><title>Niente Volume Report</title></head>'
.print '  <link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/nienteico.svg">'
.mode html
.headers on
.print '<style>'
.print '  table { border-collapse: collapse; width: 100%; font-family: serif; font-size: 13px; }'
.print '  th { background-color: #333; color: white; padding: 6px 8px; position: sticky; top: 0; }'
.print '  th, td { border: 1px solid #aaa; padding: 4px 8px; text-align: left; line-height: 1.2; vertical-align: top; }'
.print '  td:first-child { white-space: normal; word-break: break-all; }'
.print '  td:not(:first-child) { white-space: nowrap; width: 1%; }'
.print '  th:nth-child(2), td:nth-child(2) { text-align: right; }'
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
$MAXV_SQL;
.print '</table>'

/* 2. Switch to list mode to clear the "Null Null" ghosting */
.mode list
.headers off

.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
.print '<p class="footer">Total rows: '
SELECT count(*) FROM ($MAXV_SQL);
.print '</p>'

/* 3. Inject the pre-formatted variable without extra shell quotes */
.print '<p class="footer">Generated on: $REPORT_DATE</p>'
.print '<p class="footer">Folders mentioned on this report are here because the FLACs they contain have been subject to a volume boost integrity check and found to have low peak volumes. Such files can have a non-distorting physical volume boost applied that is signficantly larger than the threshold set in the configuration file. This does not mean every file <i>should</i> be physically volume boosted: there may be good reasons for them being recorded as quietly as they have been! It is simply an observation that these files can be expected to play back at much lower perceived peak loudness than they could be made to do.</p>'
.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
EOF

    output_report
fi
}

####################################################################
# Report 3: Missing or null ReplayGain amounts
####################################################################
function report_replaygain {
REPORT_FILE="$CONFDIR/tmp/replay.html"
rm -f "$REPORT_FILE" 2>/dev/null
check_database

# Now we can produce the report
REPLAY_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from tracks where replaygain is null or replaygain=''")
REPLAY_SQL="select rtrim(filename, replace(filename, '/', '')) as 'Folder Name', replace(filename, rtrim(filename, replace(filename, '/', '')), '') as 'File Name', coalesce(nullif(replaygain, ''), 'Empty') as 'Album ReplayGain' from tracks where replaygain is null or replaygain='' order by 1,2"

REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
REPORT_TITLE="Music folders missing potentially useful <i>metadata</i> volume boosts (ReplayGain)"
REPORT_ALLCLEAR="\\nAll known music files appear to have already had ReplayGain calculated.\\n\\nPress OK to continue."

if [[ $REPLAY_COUNT -eq 0 ]]; then
    dialog --stdout --backtitle "Niente Reporting - ReplayGain Volume Boosts" --title " Good News! " --msgbox "$REPORT_ALLCLEAR" 9 80
else
    sqlite3 "$CONFDIR/db/$DBNAME.db" <<EOF > "$REPORT_FILE"
.print '<head><title>Niente ReplayGain Report</title></head>'
.print '  <link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/nienteico.svg">'
.mode html
.headers on
.print '<style>'
.print '  table { border-collapse: collapse; width: 100%; font-family: serif; font-size: 13px; }'
.print '  th { background-color: #333; color: white; padding: 6px 8px; position: sticky; top: 0; }'
.print '  th, td { border: 1px solid #aaa; padding: 4px 8px; text-align: left; line-height: 1.2; vertical-align: top; }'
.print '  td:first-child { white-space: normal; word-break: break-all; }'
.print '  td:not(:first-child) { white-space: nowrap; width: 1%; }'
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
$REPLAY_SQL;
.print '</table>'

/* 2. Switch to list mode to clear the "Null Null" ghosting */
.mode list
.headers off

.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
.print '<p class="footer">Total rows: '
SELECT count(*) FROM ($REPLAY_SQL);
.print '</p>'

/* 3. Inject the pre-formatted variable without extra shell quotes */
.print '<p class="footer">Generated on: $REPORT_DATE</p>'
.print '<p class="footer">Folders mentioned on this report are here because the FLACs they contain do not have a REPLAYGAIN_ALBUM_GAIN metadata tag. You may wish to consider performing a <i>metadata</i> volume boost (i.e., analysing them and writing ReplayGain tags back to the FLACs) with a suitable tool, such as <a href="https://bbritten.com/softwares/semplice/semplice" target="_blank">Semplice</a>.</p>'
.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
EOF

    output_report
fi
}

####################################################################
# Report 4: Files missing bit/sample rates in file names
####################################################################
function report_nosample {
REPORT_FILE="$CONFDIR/tmp/nosampl.html"
rm -f "$REPORT_FILE" 2>/dev/null
check_database

# Now we can produce the report
SAMPL_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from (select filename, bitdepth, sample_rate, instr(filename, computed_bitdepth||'-'||computed_samplerate) as intest, computed_bitdepth, computed_samplerate from ( select filename, bitdepth, sample_rate, ifnull(bitdepth, 1) as computed_bitdepth, ifnull(sample_rate,1) as computed_samplerate from tracks ) where intest=0)")
SAMPL_SQL="select filename as Filename, ifnull(bitdepth,'Null') as Bitdepth, ifnull(sample_rate,'Null') as 'Sample Rate' from ( select filename, bitdepth, sample_rate, ifnull(bitdepth, 1) as computed_bitdepth, ifnull(sample_rate,1) as computed_samplerate from tracks ) where instr(filename, computed_bitdepth||'-'||computed_samplerate)=0 order by filename"

REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
REPORT_TITLE="Files with missing bit-depth or sample rates in their file names"
REPORT_ALLCLEAR="\nAll known music files appear to have appropriate bit-depth and sample-rate data included in the physical file names.\\n\\nPress OK to continue."

if [[ $SAMPL_COUNT -eq 0 ]]; then
    dialog --stdout --backtitle "Niente Reporting - Bit-depth/Sample Rates in Filenames" --title " Good News! " --msgbox "$REPORT_ALLCLEAR" 12 80
else
    sqlite3 "$CONFDIR/db/$DBNAME.db" <<EOF > "$REPORT_FILE"
.print '<head><title>Niente Filename Report</title></head>'
.print '  <link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/nienteico.svg">'
.mode html
.headers on
.print '<style>'
.print '  table { border-collapse: collapse; width: 100%; font-family: serif; font-size: 13px; }'
.print '  th { background-color: #333; color: white; padding: 6px 8px; position: sticky; top: 0; }'
.print '  th, td { border: 1px solid #aaa; padding: 4px 8px; text-align: left; line-height: 1.2; vertical-align: top; }'
.print '  td:first-child { white-space: normal; word-break: break-all; }'
.print '  td:not(:first-child) { white-space: nowrap; width: 1%; }'
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
$SAMPL_SQL;
.print '</table>'

/* 2. Switch to list mode to clear the "Null Null" ghosting */
.mode list
.headers off

.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
.print '<p class="footer">Total rows: '
SELECT count(*) FROM ($SAMPL_SQL);
.print '</p>'

/* 3. Inject the pre-formatted variable without extra shell quotes */
.print '<p class="footer">Generated on: $REPORT_DATE</p>'
.print '<p class="footer">Files mentioned on this report are here because their physical file names either (1) do not contain bitdepth and/or sample rates that match the <i>actual</i> bitdepth and sample rate that their audio signal contains; or (2) they do not contain bitdepth and/or sample rates at all. It is not a <i>requirement</i> that physical files contain this data, but it <b>is</b> a recommendation. If your music file is an 88,100Hz at 24-bit one, it is a good idea to see <b>-24-88100</b> in the file name somewhere.</p>'
.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
EOF

    output_report
fi
}

####################################################################
# Report 5: Music Folders containing multiple physical FLACs
####################################################################
function report_multitrack {
REPORT_FILE="$CONFDIR/tmp/multitrack.html"
rm -f "$REPORT_FILE" 2>/dev/null
check_database

# Now we can produce the report
MULTI_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from (select rtrim(filename, replace(filename, '/', '')), artistname, albumname, count(*) from tracks group by rtrim(filename, replace(filename, '/', '')), artistname, albumname having count(*) > 1)")
MULTI_SQL="select rtrim(filename, replace(filename, '/', '')) as 'Folder Name', artistname as 'Artist Tag', albumname as 'Album Tag', count(*) as 'Track Count' from tracks group by rtrim(filename, replace(filename, '/', '')), artistname, albumname having count(*) > 1 order by 1,3"

REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
REPORT_TITLE="Music folders containing multiple physical FLACs"
REPORT_ALLCLEAR="\nThere are no known examples of multiple FLACs existing in the same physical folder.\\n\\nPress OK to continue."

if [[ $MULTI_COUNT -eq 0 ]]; then
    dialog --stdout --backtitle "Niente Reporting - Multiple FLACs in the same folder" --title " Good News! " --msgbox "$REPORT_ALLCLEAR" 12 80
else
    sqlite3 "$CONFDIR/db/$DBNAME.db" <<EOF > "$REPORT_FILE"
.print '<head><title>Niente Multi-File Report</title></head>'
.print '  <link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/nienteico.svg">'
.mode html
.headers on
.print '<style>'
.print '  table { border-collapse: collapse; width: 100%; font-family: serif; font-size: 13px; }'
.print '  th { background-color: #333; color: white; padding: 6px 8px; position: sticky; top: 0; }'
.print '  th, td { border: 1px solid #aaa; padding: 4px 8px; text-align: left; line-height: 1.2; vertical-align: top; }'
.print '  td:first-child { white-space: normal; word-break: break-all; }'
.print '  td:not(:first-child) { white-space: nowrap; width: 1%; }'
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
$MULTI_SQL;
.print '</table>'

/* 2. Switch to list mode to clear the "Null Null" ghosting */
.mode list
.headers off

.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
.print '<p class="footer">Total rows: '
SELECT count(*) FROM ($MULTI_SQL);
.print '</p>'

/* 3. Inject the pre-formatted variable without extra shell quotes */
.print '<p class="footer">Generated on: $REPORT_DATE</p>'
.print '<p class="footer">Folders mentioned on this report are here because they contain more than one FLAC. That is not necessarily a problem: a symphony will likely contain four movements, each movement a separate FLAC, for example. However, you may want to consider using the <a href="https://bbritten.com/softwares/semplice/semplice" target="_blank">Semplice</a> SuperFLAC feature to merge such separate files into a single "whole recording" FLAC, resulting in just one big FLAC representing the entire work. See the <a href="https://bbritten.com/softwares/semplice/semsuper" target="_blank">SuperFLAC</a> part of the Semplice documentation for more details.</p>'
.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
EOF

    output_report
fi
}

####################################################################
# Report 6: Possibly duplicate recordings
####################################################################
function report_dupes {
REPORT_FILE="$CONFDIR/tmp/duplicates.html"
rm -f "$REPORT_FILE" 2>/dev/null
check_database

# Now we can produce the report
DUPE_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from (select rtrim(filename, replace(filename, '/', '')) , replace(filename, rtrim(filename, replace(filename, '/', '')), ''), hash_orig from tracks where hash_orig in (select hash_orig from tracks group by hash_orig having count(*)>1))")
DUPE_SQL="select rtrim(filename, replace(filename, '/', '')) as 'Folder Name', replace(filename, rtrim(filename, replace(filename, '/', '')), '') as 'File Name', hash_orig as 'Audio Fingerprint' from tracks where hash_orig in (select hash_orig from tracks group by hash_orig having count(*)>1) order by 1,3"

REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
REPORT_TITLE="Recordings which appear to be duplicates of each other"
REPORT_ALLCLEAR="\nThere are no known examples of FLACs which appear to be exact duplicates of each other.\\n\\nPress OK to continue."

if [[ $DUPE_COUNT -eq 0 ]]; then
    dialog --stdout --backtitle "Niente Reporting - Detection of possible duplicate recordings" --title " Good News! " --msgbox "$REPORT_ALLCLEAR" 12 80
else
    sqlite3 "$CONFDIR/db/$DBNAME.db" <<EOF > "$REPORT_FILE"
.print '<head><title>Niente Duplicates Report</title></head>'
.print '  <link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/nienteico.svg">'
.mode html
.headers on
.print '<style>'
.print '  table { border-collapse: collapse; width: 100%; font-family: serif; font-size: 13px; }'
.print '  th { background-color: #333; color: white; padding: 6px 8px; position: sticky; top: 0; }'
.print '  th, td { border: 1px solid #aaa; padding: 4px 8px; text-align: left; line-height: 1.2; vertical-align: top; }'
.print '  td:first-child { white-space: normal; word-break: break-all; }'
.print '  td:not(:first-child) { white-space: nowrap; width: 1%; }'
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
$DUPE_SQL;
.print '</table>'

/* 2. Switch to list mode to clear the "Null Null" ghosting */
.mode list
.headers off

.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
.print '<p class="footer">Total rows: '
SELECT count(*) FROM ($DUPE_SQL);
.print '</p>'

/* 3. Inject the pre-formatted variable without extra shell quotes */
.print '<p class="footer">Generated on: $REPORT_DATE</p>'
.print '<p class="footer">Files mentioned on this report are here because the MD5 hash "fingerprint" of their audio signal matches <i>exactly</i> the MD5 hash for at least one other FLAC. That is very unlikely to happen by chance: it is much more probable that you have the exact same recording stored more than once in your music collection.'
.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
EOF

    output_report
fi
}

####################################################################
# Report 7: The Operations Log
####################################################################
function report_ops {
REPORT_FILE="$CONFDIR/tmp/ops.html"
rm -f "$REPORT_FILE" 2>/dev/null
check_database

# Now we can produce the report
OPS_SQL="select operation_date as 'Operation Date', operation as 'Operation' from refresh_logs order by operation_date desc"

REPORT_DATE=$(date "+%a %d %b %Y %H:%M:%S %Z")
REPORT_TITLE="Niente Operations Events Log<br><span style=\"font-size: 10pt;\">(<i>most recent first</i>)</span>"

sqlite3 "$CONFDIR/db/$DBNAME.db" <<EOF > "$REPORT_FILE"
.print '<head><title>Niente Operations Log</title></head>'
.print '  <link rel="icon" type="image/svg+xml" href="file://$CONFDIR/art/nienteico.svg">'
.mode html
.headers on
.print '<style>'
.print '  table { border-collapse: collapse; width: 100%; font-family: serif; font-size: 13px; }'
.print '  th { background-color: #333; color: white; padding: 6px 8px; position: sticky; top: 0; }'
.print '  th, td { border: 1px solid #aaa; padding: 4px 8px; text-align: left; line-height: 1.2; vertical-align: top; }'
/* target the first column (date/time) specifically */
.print '  th:first-child, td:first-child { width: 10%; white-space: nowrap; }'
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
$OPS_SQL;
.print '</table>'

/* 2. Switch to list mode to clear the "Null Null" ghosting */
.mode list
.headers off

.print '<hr style="border: 0; border-top: 1px solid #ccc; margin: 10px 0;">'
.print '<p class="footer">Total rows: '
SELECT count(*) FROM ($OPS_SQL);
.print '</p>'

/* 3. Inject the pre-formatted variable without extra shell quotes */
.print '<p class="footer">Generated on: $REPORT_DATE</p>'
EOF

output_report
}

function main {
REPORT_TYPE=$1
case $REPORT_TYPE in
  badart) report_art; nsubmenuoptions other;;
  maxv  ) report_maxv; nsubmenuoptions other;;
  replay) report_replaygain; nsubmenuoptions other;;
  namebt) report_nosample; nsubmenuoptions other;;
  multtk) report_multitrack; nsubmenuoptions other;;
  dupes ) report_dupes; nsubmenuoptions other;;
  ops   ) report_ops; nsubmenuoptions other;; 
esac
 }

main "$@"