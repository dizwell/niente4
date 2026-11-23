#!/usr/bin/env bash
####################################################################
#
# nenaggstatnd: routine for running the Aggstats report, but
# with no output to screen, just a written report to disk
#
####################################################################
PATH=/usr/local/bin:/usr/bin:/bin:$PATH

if [[ $SQUAREART -eq 1 ]]; then
  AGGSTATS_SQL="select 'G1' as 'Statistic', 'Total number of FLACs: ' as 'Statistic Name',  count(*) as 'Count' from tracks union
  select 'G2', 'Recordings with physical integrity problems: ', count(*) as 'Record Count' from (select * from tracks where hash_orig<>hash_new or hash_orig is null or hash_new is null) union
  select 'G3', 'Recordings not yet analysed: ', count(*) from (select * from tracks where (bitdepth IS NULL OR bitdepth='') AND (sample_rate IS NULL OR sample_rate='') AND (hash_orig IS NULL OR hash_orig='') AND (hash_new IS NULL OR hash_new='') AND (album_year IS NULL OR album_year='') AND (date_tag IS NULL OR date_tag='') AND (performer IS NULL OR performer='') AND (comment IS NULL OR comment='') AND (albumname IS NULL OR albumname='') AND (artistname IS NULL OR artistname='') AND (composername IS NULL OR composername='') AND (genrename IS NULL OR genrename='') AND (tracktitle IS NULL OR tracktitle='')) union
  select 'G4', 'Missing Tags of all kinds: ', count(*) from
  (SELECT * FROM tracks WHERE ((bitdepth IS NULL OR bitdepth='') OR (sample_rate IS NULL OR sample_rate='') OR (hash_orig IS NULL OR hash_orig='') OR (hash_new IS NULL OR hash_new='') OR (album_year IS NULL OR album_year='') OR (date_tag IS NULL OR date_tag='') OR (performer IS NULL OR performer='') OR (comment IS NULL OR comment='') OR (albumname IS NULL OR albumname='') OR (artistname IS NULL OR artistname='') OR (composername IS NULL OR composername='') OR (genrename IS NULL OR genrename='') OR (tracktitle IS NULL OR tracktitle='')) AND NOT ((bitdepth IS NULL OR bitdepth='') AND (sample_rate IS NULL OR sample_rate='') AND (hash_orig IS NULL OR hash_orig='') AND (hash_new IS NULL OR hash_new='') AND (album_year IS NULL OR album_year='') AND (date_tag IS NULL OR date_tag='') AND (performer IS NULL OR performer='') AND (comment IS NULL OR comment='') AND (albumname IS NULL OR albumname='') AND (artistname IS NULL OR artistname='') AND (composername IS NULL OR composername='') AND (genrename IS NULL OR genrename='') AND (tracktitle IS NULL OR tracktitle=''))) union
  select 'L1', 'Inconsistent YEAR/ALBUM tags: ',count(*) from tracks where album_year<>date_tag and length(DATE_TAG)>0 and length(ALBUM_YEAR)>0 union
  select 'L2', 'Inconsistent TRACKNUMBER tags: ', count(*) from (select  id from tracks t, (select albumname from tracks group by albumname having min(cast(tracknumber as int)) <> 1) b where b.albumname=t.albumname) union
  select 'L3', 'Inconsistent PERFORMER/COMMENT tags: ', count(*) from tracks where not instr(comment, performer) union
  select 'L4', 'Inconsistent PERFORMER/ALBUM tags: ', count(*) from tracks where not instr(performer, substr(albumname,instr(albumname,'(')+1,(length(albumname)-8)-(instr(albumname, '(')))) union
  select 'L5', 'Inconsistent ARTIST/COMPOSER tags: ', count(*) from tracks where artistname<>composername union
  select 'L6', 'Inconsistent Bit Depth/Sample Rates: ', count(*) from (select * from tracks where bitdepth=16 and sample_rate>48000 union select * from tracks where bitdepth=24 and sample_rate<48000) union
  select 'O1','Album Art size issues:', count(*) from (select * from albumart where (albumartheight < $SMALLART or albumartwidth < $SMALLART) or (albumartheight > $LARGEART or albumartwidth > $LARGEART) or (albumartheight <> albumartwidth) or albumartheight is null or albumartheight = '' or albumartwidth is null or albumartwidth = '') union"

  if [[ $REPORTMAXV == "yes" ]]; then AGGSTATS_SQL="$AGGSTATS_SQL select 'O2', 'Potential Volume Boosts:', count(*) from (select $FOLDERSQL from maxvolumes group by $FOLDERSQL having min(boost) > $VOLUMETHRESHOLD) union"; fi
  if [[ $NAMEBITS == "yes" ]]; then AGGSTATS_SQL="$AGGSTATS_SQL select 'O4', 'Missing audio data in filenames:', count(*) from (select filename, bitdepth, sample_rate, instr(filename, computed_bitdepth||'-'||computed_samplerate) as intest, computed_bitdepth, computed_samplerate from ( select filename, bitdepth, sample_rate, ifnull(bitdepth, 1) as computed_bitdepth, ifnull(sample_rate,1) as computed_samplerate from tracks ) where intest=0) union"; fi

  AGGSTATS_SQL="$AGGSTATS_SQL select 'O5', 'Folders containing multiple physical FLACs:', count(*) from (select rtrim(filename, replace(filename, '/', '')), composername, albumname, count(*) from tracks group by rtrim(filename, replace(filename, '/', '')), composername, albumname having count(*) > 1) union
  select 'O6', 'Possible duplicate recordings:', count(*) from (select hash_orig from tracks where hash_orig in (select hash_orig from tracks group by hash_orig having count(*)>1)) union
  select 'O3', 'Missing ReplayGain information:', count(*) from tracks where replaygain is null or replaygain='' union
  select 'T1', 'Last integrity check done on (y-m-d):', substr(max(operation_date),1,10) from refresh_logs where operation like '%integrity check%'
  order by 1"
else
  AGGSTATS_SQL="select 'G1' as 'Statistic', 'Total number of recordings: ' as 'Statistic Name',  count(*) as 'Count' from tracks union
  select 'G2', 'Recordings with physical integrity problems: ', count(*) as 'Record Count' from (select * from tracks where hash_orig<>hash_new or hash_orig is null or hash_new is null) union
  select 'G3', 'Recordings not yet analysed: ', count(*) from (select * from tracks where (bitdepth IS NULL OR bitdepth='') AND (sample_rate IS NULL OR sample_rate='') AND (hash_orig IS NULL OR hash_orig='') AND (hash_new IS NULL OR hash_new='') AND (album_year IS NULL OR album_year='') AND (date_tag IS NULL OR date_tag='') AND (performer IS NULL OR performer='') AND (comment IS NULL OR comment='') AND (albumname IS NULL OR albumname='') AND (artistname IS NULL OR artistname='') AND (composername IS NULL OR composername='') AND (genrename IS NULL OR genrename='') AND (tracktitle IS NULL OR tracktitle='')) union
  select 'G4', 'Missing Tags of all kinds: ', count(*) from
  (SELECT * FROM tracks WHERE ((bitdepth IS NULL OR bitdepth='') OR (sample_rate IS NULL OR sample_rate='') OR (hash_orig IS NULL OR hash_orig='') OR (hash_new IS NULL OR hash_new='') OR (album_year IS NULL OR album_year='') OR (date_tag IS NULL OR date_tag='') OR (performer IS NULL OR performer='') OR (comment IS NULL OR comment='') OR (albumname IS NULL OR albumname='') OR (artistname IS NULL OR artistname='') OR (composername IS NULL OR composername='') OR (genrename IS NULL OR genrename='') OR (tracktitle IS NULL OR tracktitle='')) AND NOT ((bitdepth IS NULL OR bitdepth='') AND (sample_rate IS NULL OR sample_rate='') AND (hash_orig IS NULL OR hash_orig='') AND (hash_new IS NULL OR hash_new='') AND (album_year IS NULL OR album_year='') AND (date_tag IS NULL OR date_tag='') AND (performer IS NULL OR performer='') AND (comment IS NULL OR comment='') AND (albumname IS NULL OR albumname='') AND (artistname IS NULL OR artistname='') AND (composername IS NULL OR composername='') AND (genrename IS NULL OR genrename='') AND (tracktitle IS NULL OR tracktitle=''))) union
  select 'L1', 'Inconsistent YEAR/ALBUM tags: ',count(*) from tracks where album_year<>date_tag and length(DATE_TAG)>0 and length(ALBUM_YEAR)>0 union
  select 'L2', 'Inconsistent TRACKNUMBER tags: ',count(*) from (select  id from tracks t, (select albumname from tracks group by albumname having min(cast(tracknumber as int)) <> 1) b where b.albumname=t.albumname) union
  select 'L3', 'Inconsistent PERFORMER/COMMENT tags: ', count(*) from tracks where not instr(comment, performer) union
  select 'L4', 'Inconsistent PERFORMER/ALBUM tags: ', count(*) from tracks where not instr(performer, substr(albumname,instr(albumname,'(')+1,(length(albumname)-8)-(instr(albumname, '(')))) union
  select 'L5', 'Inconsistent ARTIST/COMPOSER tags: ', count(*) from tracks where artistname<>composername union
  select 'L6', 'Inconsistent Bit Depth/Sample Rates: ', count(*) from (select * from tracks where bitdepth=16 and sample_rate>48000 union select * from tracks where bitdepth=24 and sample_rate<48000) union
  select 'O1','Album Art size issues:', count(*) from (select * from albumart where (albumartheight < $SMALLART or albumartwidth < $SMALLART) or (albumartheight > $LARGEART or albumartwidth > $LARGEART) or albumartheight is null or albumartheight = '' or albumartwidth is null or albumartwidth = '') union"

  if [[ $REPORTMAXV == "yes" ]]; then AGGSTATS_SQL="$AGGSTATS_SQL select 'O2', 'Potential Volume Boosts:', count(*) from (select $FOLDERSQL from maxvolumes group by $FOLDERSQL having min(boost) > $VOLUMETHRESHOLD) union"; fi
  if [[ $NAMEBITS == "yes" ]]; then AGGSTATS_SQL="$AGGSTATS_SQL select 'O4', 'Missing audio data in filenames:', count(*) from (select filename, bitdepth, sample_rate, instr(filename, computed_bitdepth||'-'||computed_samplerate) as intest, computed_bitdepth, computed_samplerate from ( select filename, bitdepth, sample_rate, ifnull(bitdepth, 1) as computed_bitdepth, ifnull(sample_rate,1) as computed_samplerate from tracks ) where intest=0) union"; fi

  AGGSTATS_SQL="$AGGSTATS_SQL select 'O5', 'Folders containing multiple physical FLACs:', count(*) from (select rtrim(filename, replace(filename, '/', '')), composername, albumname, count(*) from tracks group by rtrim(filename, replace(filename, '/', '')), composername, albumname having count(*) > 1) union
  select 'O6', 'Possible duplicate recordings:', count(*) from (select hash_orig from tracks where hash_orig in (select hash_orig from tracks group by hash_orig having count(*)>1)) union
  select 'O3', 'Missing ReplayGain information:', count(*) from tracks where replaygain is null or replaygain='' union
  select 'T1', 'Last integrity check done on (y-m-d):', substr(max(operation_date),1,10) from refresh_logs where operation like '%integrity check%'
  order by 1"
fi

/usr/bin/sqlite3 "$CONFDIR/db/$DBNAME.db" -cmd '.separator |' "$AGGSTATS_SQL"  > /tmp/nientestats.csv

exit