#!/usr/bin/perl
# Perl - v: 5.16.3
#------------------------------------------------------------------------------#
# XL-ParserAnalysis.pl	: Analysis functions for XL-Parser
# Website     					: http://le-tools.com/XL-Parser.html
# SourceForge						: https://sourceforge.net/p/xl-parser
# GitHub								: https://github.com/arioux/XL-Parser
# Creation							: 2016-07-15
# Modified							: 2017-09-10
# Author								: Alain Rioux (admin@le-tools.com)
#
# Copyright (C) 2016-2017 Alain Rioux (le-tools.com)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#------------------------------------------------------------------------------#
# Modules
#------------------------------------------------------------------------------#
use strict;
use warnings;
use DateTime;
use DateTime::TimeZone;
use DateTime::Format::Duration;
use DateTime::Format::Strptime;
use JSON qw(encode_json decode_json);
use Regexp::IPv6 qw($IPv6_re);
use Win32::File;
use Digest::MD5::File qw(file_md5_hex);
use Digest::SHA qw(sha1_hex);
use Win32::Process;

#------------------------------------------------------------------------------#
sub createLADB
#------------------------------------------------------------------------------#
{
  # Local variables
  my ($PROGDIR, $USERDIR, $refWinLFDB, $refWinDTDB, $refWinFileFilters, $refWinFileFormats, $refWinLAFilters, $refWin, $refWinConfig,
      $refWinFO, $refSTR, $refConfig) = @_;
  my $dbFile = $$refWin->tfDestDir->Text();
  my $procID = time;
  # Create or update the database
  my $refDbh = &createLADBTables($dbFile);
  # Prepare log files
  my %listFiles;
  if ($$refWin->rbInputDir->Checked() or $$refWin->rbInputFiles->Checked()) {
    &getListFiles(\%listFiles, $refWinFileFormats, $refWinFileFilters, $refWin, $refSTR);
  }
  # Clipboard
  elsif ($$refWin->rbInputClipboard->Checked()) { $listFiles{'Clipboard'} = 0; }
	my $nbrFiles = scalar(keys %listFiles);
	if ($nbrFiles) {
    # Create FILES table and prepare files
    &createLADB_FILES(\%listFiles, $refDbh, $refWinFO, $refWin, $refSTR);
    # Set process options
    my ($refDatabaseINFO) = &setLADB_INFO($refDbh, $refWinLFDB, $refWinDTDB, $refWinConfig, $refConfig, $refWin);
    # List Filters
    my ($refFilterSets, $nbrFilterSets, $filterISP, $filterGeoIP, $filterUA, $filterWeekday, $whiteList);
    if ($$refWinLAFilters) {
      ($refFilterSets, $nbrFilterSets, $filterISP, $filterGeoIP, $filterUA, $filterWeekday, $whiteList) =
      &getSelFilterSets($$refWinConfig->tfLAFiltersDB->Text(), $refWinLAFilters, $refSTR);
    }
    $$refDatabaseINFO{filterISP}     = 0;
    $$refDatabaseINFO{filterGeoIP}   = 0;
    $$refDatabaseINFO{filterUA}      = 0;
    $$refDatabaseINFO{filterWeekday} = 0;
    if ($nbrFilterSets) {
      $$refDatabaseINFO{filtered}      = 1;
      $$refDatabaseINFO{nbrFilterSets} = $nbrFilterSets;
      $$refDatabaseINFO{filterISP}     = 1 if $filterISP;
      $$refDatabaseINFO{filterGeoIP}   = 1 if $filterGeoIP;
      $$refDatabaseINFO{filterUA}      = 1 if $filterUA;
      $$refDatabaseINFO{filterWeekday} = 1 if $filterWeekday;
      $$refDatabaseINFO{whiteList}     = 1 if $whiteList;
      foreach my $cat (keys %{$refFilterSets}) { foreach my $filter (keys %{$$refFilterSets{$cat}}) { $$refDatabaseINFO{listFilters} .= "$cat - $filter, "; } }
      chop($$refDatabaseINFO{listFilters}); chop($$refDatabaseINFO{listFilters});
      &updateLADB_INFO($refDbh, $refDatabaseINFO);
      # Save selected filters as JSON
      my $destDir = $dbFile;
      while (chop($destDir) ne "\\") { } # Dir only
      my $jsonObj = JSON->new;
      my $jsonText = $jsonObj->encode($refFilterSets);
      if (open(my $json, '>:encoding(cp1252)', "$destDir\\CurrentProjectSelFilters-" . $procID .'.json')) {
        print $json $jsonText;
        close($json);
      }
    }
    # Hide Progress controls in main window
    $$refWin->lblPbCurr->Text('');
    $$refWin->pb->SetPos(0);
    $$refWin->lblPbCount->Text('');
    $$refWin->lblPbCurr->Hide();
    $$refWin->pb->Hide();
    $$refWin->lblPbCount->Hide();
    $$refDbh->disconnect();
    $$refWin->Disable();
    # Start Log Analysis Process
    my $command = 'XL-Parser-process ';
    if ($$refWin->rbLACreateDB->Checked()) { $command .= 'LADB-Create'; }
    else                                   { $command .= 'LADB-Update'; }
    $command .= " $procID \"$PROGDIR\" \"$dbFile\" \"$USERDIR\"";
    Win32::Process::Create(my $processObj, $PROGDIR .'\XL-Parser-process.exe', $command, 0, NORMAL_PRIORITY_CLASS, $PROGDIR);
    $processObj->Wait(INFINITE) if $$refWin->chLASelectDB->Checked();
    $$refWin->Enable();
    $$refWin->BringWindowToTop();
  } else { Win32::GUI::MessageBox($$refWin, $$refSTR{'noFile'}, $$refSTR{'error'}, 0x40010); } # No files
  
}  #--- End createLADB

#------------------------------------------------------------------------------#
sub createLADB_FILES
#------------------------------------------------------------------------------#
{
  # Local variables
  my ($refListFiles, $refDbh, $refWinFO, $refWin, $refSTR) = @_;
  my $setReadOnly    = 1 if $$refWin->chLASetReadOnly->Checked();
  my %linesByFile;
  my @listFiles;
  # Get file order
  $$refWin->lblPbCurr->Text($$refSTR{'SortingFiles'}.'...');
  if ($$refWinFO and (my $nbrRows = $$refWinFO->gridFO->GetRows()) > 1) {
    for (my $i = 1; $i < $nbrRows; $i++) { push(@listFiles, $$refWinFO->gridFO->GetCellText($i, 3)); }
  } else { @listFiles = sort { (stat $a)[9] <=> (stat $b)[9] } keys %{$refListFiles}; }
  $refListFiles = undef; # We don't need this hash anymore
  # Add file to database
  my $count = 0;
  my $nbrFiles = scalar(@listFiles);
  $$refWin->pb->SetRange(0, $nbrFiles);
  $$refWin->pb->SetPos(0);
  $$refWin->pb->SetStep(1);
  $$refWin->lblPbCount->Text("$count/$nbrFiles");
  foreach my $file (@listFiles) {
    $$refWin->lblPbCurr->Text($$refSTR{'PreProcessing'}.' '.$file.'...');
    Win32::File::SetAttributes($file, READONLY) if $setReadOnly; # Set file attribute to "read-only"
    my $countLines = 0;
    if (open my $fh, '<', $file) {
      # Count lines
      while (sysread $fh, my $buffer, 4096) { $countLines += ($buffer =~ tr/\n//); }
      close($fh);
      if (my $nbrRows = $$refDbh->selectrow_array('SELECT COUNT(id) FROM FILES')) {
        # An entry for this file already exist
        if (my ($fileId, $nbrLines, $nbrEntries, $nbrRejected, $nbrFiltered, $firstEntry) =
            $$refDbh->selectrow_array('SELECT id,lines,entries,rejected,filtered,firstEntry
                                      FROM FILES WHERE path == ? COLLATE NOCASE', undef, $file)) {
          &updateFILES($refDbh, $fileId, $countLines, $nbrEntries, $nbrRejected, $nbrFiltered, $firstEntry);
        # Create a new entry
        } else { &insertIntoFILES($refDbh, ($nbrRows + 1), $file, $countLines, $refWin, $refSTR); }
      # First entry
      } else { &insertIntoFILES($refDbh, 1, $file, $countLines, $refWin, $refSTR); }
    }
    $count++;
    $$refWin->pb->StepIt();
    $$refWin->lblPbCount->Text("$count/$nbrFiles");
  }
  $$refDbh->commit();
  
}  #--- End createLADB_FILES

#------------------------------------------------------------------------------#
sub setLADB_INFO
#------------------------------------------------------------------------------#
{
  # Local variables
  my ($refDbh, $refWinLFDB, $refWinDTDB, $refWinConfig, $refConfig, $refWin) = @_;
  my %databaseINFO;
  # Resolve options
  $databaseINFO{resISP}         = 1 if $$refWin->chLAOptResISP->Checked();
  $databaseINFO{resGeoIP}       = 1 if $$refWin->chLAOptResGeoIP->Checked();
  $databaseINFO{resUA}          = 1 if $$refWin->chLAOptResUA->Checked();
  $databaseINFO{resWeekday}     = 1 if $$refWin->chLAOptResWeekday->Checked();
  # Logging
  $databaseINFO{logFiltered}    = 1 if $$refWin->chLALogFiltered->Checked();
  $databaseINFO{logRejected}    = 1 if $$refWin->chLALogRejected->Checked();
  $databaseINFO{ignoreComments} = 1 if $$refWin->chLAIgnoreComments->Checked();
  # Log format
  $databaseINFO{LFName} = $$refWin->cbLF->GetString($$refWin->cbLF->GetCurSel());
  ($databaseINFO{LFPattern}, $databaseINFO{LFRegex}) = &getLFDetails($databaseINFO{LFName}, $refWinLFDB);
  # Datetime format
  $databaseINFO{timezone}   = $$refWinConfig->cbLocalTZ->GetString($$refConfig{'LOCAL_TIMEZONE'});
  if ($databaseINFO{LFPattern} =~ /datetime\(([^\)]+)\)/) {
    my $DTSample = $1;
    $DTSample =~ s/%20/ /g;
    # Guess format
    for (my $i = 1; $i < $$refWinDTDB->gridDT->GetRows(); $i++) {
      my $curSampleRow         = $$refWinDTDB->gridDT->GetCellText($i, 0);
      $databaseINFO{DTPattern} = $$refWinDTDB->gridDT->GetCellText($i, 1) if $curSampleRow eq $DTSample;
    }
  }
  # Useragent with spaces ?
  if ($databaseINFO{LFPattern} =~ /useragent-s/) { $databaseINFO{uaWithSpaces} = 1; }
  else { $databaseINFO{uaWithSpaces} = 0; }
  # Update INFO table
  &updateLADB_INFO($refDbh, \%databaseINFO);
  return(\%databaseINFO);
  
}  #--- End setLADB_INFO

#------------------------------------------------------------------------------#
sub updateLADB
#------------------------------------------------------------------------------#
{
  # Local variables
  my ($PROGDIR, $USERDIR, $refWinLAFilters, $refWin, $refWinConfig, $refConfig, $refSTR) = @_;
  my %updateParams;
  my $procID = time;
  # Hide Progress controls in main window
  $$refWin->lblPbCurr->Text('');
  $$refWin->pb->SetPos(0);
  $$refWin->lblPbCount->Text('');
  $$refWin->lblPbCurr->Hide();
  $$refWin->pb->Hide();
  $$refWin->lblPbCount->Hide();
  # Get parameters and options
  $updateParams{dbFile}     = $$refWin->tfInput->Text();
  $updateParams{createNew}  = 1 if $$refWin->rbDestDBNew->Checked();
  $updateParams{resISP}     = 1 if $$refWin->chLAOptResISP->Checked();
  $updateParams{resGeoIP}   = 1 if $$refWin->chLAOptResGeoIP->Checked();
  $updateParams{resUA}      = 1 if $$refWin->chLAOptResUA->Checked();
  $updateParams{resWeekday} = 1 if $$refWin->chLAOptResWeekday->Checked();
  $updateParams{timezone}   = $$refWinConfig->cbLocalTZ->GetString($$refConfig{'LOCAL_TIMEZONE'});
  $updateParams{newDbFile}  = $$refWin->tfDestDir->Text() if $updateParams{createNew} and $$refWin->tfDestDir->Text();
  my $destDir = $updateParams{dbFile};
  while (chop($destDir) ne "\\") { } # Dir only
  # List Filters
  my ($refFilterSets, $nbrFilterSets, $filterISP, $filterGeoIP, $filterUA, $filterWeekday, $whiteList);
  if ($$refWinLAFilters) {
    ($refFilterSets, $nbrFilterSets, $filterISP, $filterGeoIP, $filterUA, $filterWeekday, $whiteList) =
    &getSelFilterSets($$refWinConfig->tfLAFiltersDB->Text(), $refWinLAFilters, $refSTR);
  }
  if ($nbrFilterSets) {
    $updateParams{filtered}      = 1;
    $updateParams{nbrFilterSets} = $nbrFilterSets;
    $updateParams{filterISP}     = 1 if $filterISP;
    $updateParams{filterGeoIP}   = 1 if $filterGeoIP;
    $updateParams{filterUA}      = 1 if $filterUA;
    $updateParams{filterWeekday} = 1 if $filterWeekday;
    $updateParams{whiteList}     = 1 if $whiteList;
    foreach my $cat (keys %{$refFilterSets}) { foreach my $filter (keys %{$$refFilterSets{$cat}}) { $updateParams{listFilters} .= "$cat - $filter, "; } }
    chop($updateParams{listFilters}); chop($updateParams{listFilters});
    # Save selected filters as JSON
    my $jsonObj = JSON->new;
    my $jsonText = $jsonObj->encode($refFilterSets);
    if (open(my $json, '>:encoding(cp1252)', "$destDir\\CurrentProjectSelFilters-" . $procID .'.json')) {
      print $json $jsonText;
      close($json);
    }
  }
  # Save update params and options as JSON
  my $jsonObj = JSON->new;
  my $jsonText = $jsonObj->encode(\%updateParams);
  if (open(my $json, '>:encoding(cp1252)', "$destDir\\CurrentUpdateParams-" . $procID .'.json')) {
    print $json $jsonText;
    close($json);
  }
  $$refWin->Disable();
  # Start Log Analysis Process
  my $command = 'XL-Parser-process LADB-UpdateDB';
  $command .= " $procID \"$PROGDIR\" \"$destDir\" \"$USERDIR\"";
  Win32::Process::Create(my $processObj, $PROGDIR .'\XL-Parser-process.exe', $command, 0, NORMAL_PRIORITY_CLASS, $PROGDIR);
  $processObj->Wait(INFINITE) if $$refWin->chLASelectDB->Checked();
  $$refWin->Enable();
  $$refWin->BringWindowToTop();

}  #--- End updateLADB

#------------------------------------------------------------------------------#
sub updateLADB_INFO
#------------------------------------------------------------------------------#
{
  # Local variables
  my ($refDbh, $refINFO) = @_;
  my $sthUptInfo = $$refDbh->prepare('INSERT OR REPLACE INTO INFO (key, value) VALUES(?,?)');
  foreach my $key (keys %{$refINFO}) { $sthUptInfo->execute($key, $$refINFO{$key}); }
  $sthUptInfo->finish();
  $$refDbh->commit();
  
}  #--- End updateLADB_INFO

#--------------------------#
sub updateFilteredFILES
#--------------------------#
{
  # Local variables
  my ($refDbh, $fileId, $entries, $filtered, $firstEntry) = @_;
  # Update entry in FILES
  my $sthFiles = $$refDbh->prepare('UPDATE FILES SET entries = ?, filtered = ?, firstEntry = ? WHERE id == ?');
  $sthFiles->execute($entries, $filtered, $firstEntry, $fileId);
  $sthFiles->finish();
  
}  #--- End updateFilteredFILES

#--------------------------#
sub createLADBTables
#--------------------------#
{
  # Local variables
  my $dbFile = shift;
  my $dsn    = "DBI:SQLite:dbname=$dbFile";
  my $dbh    = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 0}) or return(0);
  $dbh->do('PRAGMA locking_mode = EXCLUSIVE');
  # Create info table
  my $stmt = qq(CREATE TABLE IF NOT EXISTS INFO
                (key            VARCHAR(255)  NOT NULL,
                 value          INT,
                 PRIMARY KEY (key)));
  my $rv = $dbh->do($stmt);
  # Create log table
  $stmt = qq(CREATE TABLE IF NOT EXISTS LOG
                (id             INT           NOT NULL,
                 remoteIP       VARCHAR(255)  NOT NULL,
                 remoteIPInt    INT,
                 datetimeInt    INT           NOT NULL,
                 timeOfDay      INT           NOT NULL,
                 weekday        INT,
                 http_method    VARCHAR(255)  NOT NULL,
                 http_request   VARCHAR(255)  NOT NULL,
                 http_params    VARCHAR(255),
                 http_protocol  VARCHAR(255),
                 http_status    INT           NOT NULL,
                 size           INT,
                 referer        VARCHAR(255),
                 useragent      VARCHAR(255),
                 file           INT           NOT NULL,
                 PRIMARY KEY (id)));
  $rv = $dbh->do($stmt);
  # Create IP Table
  $stmt = qq(CREATE TABLE IF NOT EXISTS IP
                (ip             VARCHAR(255),
                 isp            VARCHAR(255),
                 geoIP          VARCHAR(255),
                 PRIMARY KEY (ip)));
  $rv = $dbh->do($stmt);
  # Create UserAgent Table
  $stmt = qq(CREATE TABLE IF NOT EXISTS UA
                (ua             VARCHAR(255) NOT NULL,
                 type           VARCHAR(255),
                 os             VARCHAR(255),
                 browser        VARCHAR(255),
                 device         VARCHAR(255),
                 lang           VARCHAR(255),
                 PRIMARY KEY (ua)));
  $rv = $dbh->do($stmt);
  # Create Files Table
  $stmt = qq(CREATE TABLE IF NOT EXISTS FILES
                (id             INT          NOT NULL,
                 path           VARCHAR(255) NOT NULL,
                 lines          INT,
                 entries        INT,
                 firstEntry     INT,
                 rejected       INT,
                 filtered       INT,
                 md5            VARCHAR(34),
                 sha1           VARCHAR(42),
                 PRIMARY KEY (id)));
  $rv = $dbh->do($stmt);
  return(\$dbh);
  
}  #--- End createLADBTables

#--------------------------#
sub updateCurrDatabaseInfos
#--------------------------#
{
  # Local variables
  my ($inputDB, $timezone, $refWinLACurrDBFiles, $refWin, $refSTR) = @_;
  # Reset value
  $$refWin->lblCurrDBLastUpdateVal->Text('');
  $$refWin->lblCurrDBPeriodVal->Text('');
  $$refWin->lblCurrDBNbrEntriesVal->Text('');
  $$refWin->lblCurrDBFilteredVal->Text('');
  $$refWin->lblCurrDBRejectedVal->Text('');
  $$refWin->lblCurrDBLogFormatVal->Text('');
  $$refWin->tfCurrDBFiltersVal->Text('');
  $$refWin->btnLACurrDBRejected->Disable();
  $$refWin->btnLACurrDBFiltered->Disable();
  $$refWin->lblCurrDBNbrResISPVal->Text('');
  $$refWin->lblCurrDBNbrResGeoIPVal->Text('');
  $$refWin->lblCurrDBResUAsVal->Text('');
  $$refWin->lblCurrDBResWDsVal->Text('');
  $$refWinLACurrDBFiles->gridCurrDBListFiles->DeleteNonFixedRows() if $$refWinLACurrDBFiles;
  # Connect to Log database
  $inputDB = encode('utf8', $inputDB);
  my $dsn	 = "DBI:SQLite:dbname=$inputDB";
  if (my $dbh = DBI->connect($dsn, undef, undef, { })) {
    # Gather and show infos
    my ($startTime, $endTime, $filtered, $rejected);
    my $all = $dbh->selectall_arrayref("SELECT key,value FROM INFO");
    foreach my $row (@$all) {
      my ($key, $value) = @$row;
      if ($key eq 'lastUpdateTime') {
        my $lastUpdateTime = DateTime->from_epoch(epoch => $value);
        $lastUpdateTime->set_time_zone($timezone);
        $$refWin->lblCurrDBLastUpdateVal->Text($lastUpdateTime->strftime('%F %T'));
      }
      elsif ($key eq 'firstDT'       ) { $startTime = $value; }
      elsif ($key eq 'lastDT'        ) { $endTime   = $value; }
      elsif ($key eq 'nbrLogEntries' ) { $$refWin->lblCurrDBNbrEntriesVal->Text($value); }
      elsif ($key eq 'nbrRejected' and $value) {
        $$refWin->lblCurrDBRejectedVal->Text($value);
        $$refWin->btnLACurrDBRejected->Enable() if -T "$inputDB.RejectedLines.log";
        $rejected = 1;
      }
      elsif ($key eq 'nbrFiltered' and $value) {
        $$refWin->lblCurrDBFilteredVal->Text($value);
        $$refWin->btnLACurrDBFiltered->Enable() if -T "$inputDB.FilteredLines.log";
        $filtered = 1;
      }
      elsif ($key eq 'LFName'          ) { $$refWin->lblCurrDBLogFormatVal->Text($value);   }
      elsif ($key eq 'listFilters'     ) {
        my @listFilters = split(/, /, $value);
        my $listFilters;
        foreach (@listFilters) { $listFilters .= '- '.$_."\r\n"; }
        $$refWin->tfCurrDBFiltersVal->Text($listFilters);
      }
      elsif ($key eq 'nbrResISP'       ) { $$refWin->lblCurrDBNbrResISPVal->Text($value);   }
      elsif ($key eq 'nbrResGeoIP'     ) { $$refWin->lblCurrDBNbrResGeoIPVal->Text($value); }
      elsif ($key eq 'nbrResUAs'       ) { $$refWin->lblCurrDBResUAsVal->Text($value);      }
      elsif ($key eq 'nbrResWeekdays'  ) { $$refWin->lblCurrDBResWDsVal->Text($value);      }
      $$refWin->lblCurrDBRejectedVal->Text(0) if !$rejected;
      $$refWin->lblCurrDBFilteredVal->Text(0) if !$filtered;
    }
    if ($startTime and $endTime) {
      my $startDT = DateTime->from_epoch(epoch => $startTime);
      my $endDT   = DateTime->from_epoch(epoch => $endTime  );
      $startDT->set_time_zone($timezone);
      $endDT->set_time_zone($timezone);
      $$refWin->lblCurrDBPeriodVal->Text($startDT->strftime('%F %T') . ' ' . $$refSTR{'To'}. ' ' . $endDT->strftime('%F %T'));
    }
    $dbh->disconnect();
    $$refWin->btnLACurrDBFiles->Enable();
  } else { Win32::GUI::MessageBox($$refWin, $$refSTR{'errorConnectDB'}.': '.$DBI::errstr, $$refSTR{'error'}, 0x40010); }

}  #--- End updateCurrDatabaseInfos

#--------------------------#
sub loadCurrDBFiles
#--------------------------#
{
  # Local variables
  my ($inputDB, $refWinLACurrDBFiles, $refWin, $refSTR) = @_;
  # Connect to Log database
  $inputDB = encode('utf8', $inputDB);
  my $dsn  = "DBI:SQLite:dbname=$inputDB";
  if (my $dbh  = DBI->connect($dsn, undef, undef, { })) {
    # Header
    $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellText(0, 0, $$refSTR{'Path'} );
    $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellText(0, 1, $$refSTR{'Exists'});
    $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellText(0, 2, $$refSTR{'ResStatsLines'});
    $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellText(0, 3, $$refSTR{'Entries'});
    $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellText(0, 4, $$refSTR{'FirstEntry'});
    $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellText(0, 5, $$refSTR{'lblCurrDBRejected'});
    $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellText(0, 6, $$refSTR{'lblCurrDBFiltered'});
    $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellText(0, 7, 'MD5' );
    $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellText(0, 8, 'SHA1');
    # Load data
    my $all = $dbh->selectall_arrayref('SELECT path,lines,entries,firstEntry,rejected,filtered,md5,sha1 FROM FILES');
    foreach my $entry (@$all) {
      if (my $row = $$refWinLACurrDBFiles->gridCurrDBListFiles->InsertRow(0, -1)) {
        $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellText($row, 0, $$entry[0]);
        $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellText($row, 2, $$entry[1]);
        $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellText($row, 3, $$entry[2]);
        $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellText($row, 4, $$entry[3]);
        if ($$entry[4]) { $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellText($row, 5, $$entry[4]); }
        else            { $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellText($row, 5, 0);          }
        if ($$entry[5]) { $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellText($row, 6, $$entry[5]); }
        else            { $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellText($row, 6, 0);          }
        $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellText($row, 7, $$entry[6]);
        $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellText($row, 8, $$entry[7]);
        if (!-f $$entry[0]) {
          $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellColor($row, 0, [255,0,0]);
          $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellColor($row, 1, [255,0,0]);
          $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellColor($row, 2, [255,0,0]);
          $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellColor($row, 3, [255,0,0]);
          $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellColor($row, 4, [255,0,0]);
          $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellColor($row, 5, [255,0,0]);
          $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellColor($row, 6, [255,0,0]);
          $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellColor($row, 7, [255,0,0]);
          $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellColor($row, 8, [255,0,0]);
          $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellText($row, 1, $$refSTR{'No'});
        } else { $$refWinLACurrDBFiles->gridCurrDBListFiles->SetCellText($row, 1, $$refSTR{'Yes'}); }
      }
    }
    $$refWinLACurrDBFiles->gridCurrDBListFiles->AutoSize();
    $$refWinLACurrDBFiles->gridCurrDBListFiles->ExpandLastColumn();
    $$refWinLACurrDBFiles->gridCurrDBListFiles->Refresh();
    $dbh->disconnect();
  } else { Win32::GUI::MessageBox($$refWinLACurrDBFiles, $$refSTR{'errorConnectDB'}.': '.$DBI::errstr, $$refSTR{'error'}, 0x40010); }

}  #--- End loadCurrDBFiles

#--------------------------#
sub insertIntoFILES
#--------------------------#
{
  # Local variables
  my ($refDbh, $fileId, $file, $lines, $refWin, $refSTR) = @_;
  # Calculates hash
  my ($md5, $sha1);
  $$refWin->lblPbCurr->Text($$refSTR{'Hashing'}.' '.$file.' [MD5]...');
  $md5  = undef if !($md5 = file_md5_hex($file));
  $$refWin->lblPbCurr->Text($$refSTR{'Hashing'}.' '.$file.' [SHA1]...');
  $sha1 = undef if !($sha1 = Digest::SHA->new(1)->addfile($file,"b")->hexdigest);
  # Insert into table FILES
  my $sthFiles = $$refDbh->prepare('INSERT INTO FILES (id,path,lines,md5,sha1) VALUES(?,?,?,?,?)');
  $sthFiles->execute($fileId, $file, $lines, $md5, $sha1);
  $sthFiles->finish();
  
}  #--- End insertIntoFILES

#--------------------------#
sub updateFILES
#--------------------------#
{
  # Local variables
  my ($refDbh, $fileId, $lines, $entries, $rejected, $filtered, $firstEntry) = @_;
  # Update entry in FILES
  my $sthFiles = $$refDbh->prepare('UPDATE FILES SET lines = ?, entries = ?, rejected = ?, filtered = ?, firstEntry = ? WHERE id == ?');
  $sthFiles->execute($lines, $entries, $rejected, $filtered, $firstEntry, $fileId);
  $sthFiles->finish();
  
}  #--- End updateFILES
  
#--------------------------#
sub validLADB
#--------------------------#
{
  # Local variables
  my $LADB = shift;  
  if (-f $LADB) {
    # Connect to DB
    $LADB   = encode('utf8', $LADB);
    my $dsn = "DBI:SQLite:dbname=$LADB";
    if (my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1})) {
      my $sth;
      eval { $sth = $dbh->table_info(undef, undef, '%', 'TABLE'); };
      return(0) if $@;
      # If table LOG exists, database is valid
      my $refAllRows = $sth->fetchall_arrayref();
      $sth->finish();
      foreach my $refRow (@{$refAllRows}) { return(1) if $$refRow[2] eq 'LOG'; }
    }
  }
  return(0);
  
}  #--- End validLADB

#--------------------------#
sub queryLADB
#--------------------------#
{
  # Local variables
  my ($PROGDIR, $USERDIR, $refWinReport, $refWinLASavedQueries, $refWinConfig, $refWin, $refSTR) = @_;
  # Hide Progress controls in main window
  $$refWin->lblPbCurr->Text('');
  $$refWin->pb->SetPos(0);
  $$refWin->lblPbCount->Text('');
  $$refWin->lblPbCurr->Hide();
  $$refWin->pb->Hide();
  $$refWin->lblPbCount->Hide();
  my %queryParams;
  $queryParams{dbFile}       = $$refWin->tfInput->Text();
  $queryParams{query}        = $$refWin->tfLAQuery->Text();
  $queryParams{reportDir}    = $$refWinReport->tfReportDir->Text();
  $queryParams{reportFormat} = $$refWinReport->cbReportFormat->GetString($$refWinReport->cbReportFormat->GetCurSel());
  $queryParams{replReport}   = 1 if $$refWinReport->chReplaceReport->Checked();
  $queryParams{openReport}   = 1 if $$refWinReport->chOpenReport->Checked();
  $queryParams{incHeader}    = 1 if $$refWinReport->chReportOptIncHeaders->Checked();
  $queryParams{incSource}    = 1 if $$refWinReport->chReportOptIncSource->Checked();
  $queryParams{incISP}       = 1 if $$refWinReport->chReportOptIncISP->Checked();
  $queryParams{incGeoIP}     = 1 if $$refWinReport->chReportOptIncGeoIP->Checked();
  $queryParams{incUADetails} = 1 if $$refWinReport->chReportOptIncUADetails->Checked();
  $queryParams{incWeekdays}  = 1 if $$refWinReport->chReportOptIncWeekday->Checked();
  my $selOutputDTFormat      = $$refWinReport->cbOutputDTFormat->GetCurSel();
  $queryParams{localTZ}      = $$refWinConfig->cbLocalTZ->GetString($$refWinConfig->cbLocalTZ->GetCurSel());
  $queryParams{language}     = $$refWinConfig->cbDefaultLang->GetString($$refWinConfig->cbDefaultLang->GetCurSel());
  ($queryParams{outPattern}, $queryParams{outTZ}) = (&infoDTFormat($$refWinReport->cbOutputDTFormat->GetString($selOutputDTFormat)))[1,3];
  # Update Saved Queries database (used indicator)
  &updateSavedQueriesUsed($queryParams{query}, $refWinLASavedQueries, $refWinConfig, $refWin, $refSTR);
  # Save query params and options as JSON
  my $destDir = $queryParams{dbFile};
  while (chop($destDir) ne "\\") { } # Dir only
  my $procID  = time;
  my $jsonObj = JSON->new;
  my $jsonText = $jsonObj->encode(\%queryParams);
  if (open(my $json, '>:encoding(cp1252)', "$destDir\\CurrentQueryParams-" . $procID .'.json')) {
    print $json $jsonText;
    close($json);
  }
  # Start Query Database Process
  my $command = 'XL-Parser-process ' . "LADB-Query $procID \"$PROGDIR\" \"$destDir\" \"$USERDIR\"";
  Win32::Process::Create(my $processObj, $PROGDIR .'\XL-Parser-process.exe', $command, 0, NORMAL_PRIORITY_CLASS, $PROGDIR);
  $$refWin->Enable();
  $$refWin->BringWindowToTop();
	$$refWin->tfLAQuery->BringWindowToTop();
  
}  #--- End queryLADB

#--------------------------#
sub updateSavedQueriesUsed
#--------------------------#
{
  # Local variables
  my ($query, $refWinLASavedQueries, $refWinConfig, $refWin, $refSTR) = @_;
  my $queryExists    = 0;
  my $usedValue      = 0;
  my $savedQueriesDB = $$refWinConfig->tfSavedQueriesDB->Text();
  my ($queryCat, $queryName);
  # Verify if expression exists in grid
  for (my $k = 1; $k < $$refWinLASavedQueries->gridQueries->GetRows(); $k++) {
    my $currEntryQuery = $$refWinLASavedQueries->gridQueries->GetCellText($k, 4);
    if ($query eq $currEntryQuery) {
      # Update used value
      $queryCat  = $$refWinLASavedQueries->gridQueries->GetCellText($k, 0);
      $queryName = $$refWinLASavedQueries->gridQueries->GetCellText($k, 1);
      $usedValue = $$refWinLASavedQueries->gridQueries->GetCellText($k, 2);
      $usedValue++;
      $$refWinLASavedQueries->gridQueries->SetCellText($k, 2, $usedValue);
      $queryExists = 1;
      last;
    }
  }
  # Update in database
  if ($queryExists and $queryCat and $queryName and -f $savedQueriesDB) {
    $savedQueriesDB = encode('utf8', $savedQueriesDB);
    my $dsn  = "DBI:SQLite:dbname=$savedQueriesDB";
    if (my $dbh = DBI->connect($dsn, undef, undef, { AutoCommit => 1 })) {
      # Database: table = QUERIES, Fields = name, cat, query, used, time
      my $sth = $dbh->prepare('UPDATE QUERIES SET used = ? WHERE cat = ? and name = ?');
      my $rv  = $sth->execute($usedValue, $queryCat, $queryName);
      Win32::GUI::MessageBox($$refWin, $$refSTR{'errUpdatingDB'}.': '.$DBI::errstr, $$refSTR{'error'}, 0x40010) if $rv < 0;
      $dbh->disconnect();
    } else { Win32::GUI::MessageBox($$refWin, $$refSTR{'errorConnectDB'}.': '.$DBI::errstr, $$refSTR{'error'}, 0x40010); }
  }

}  #--- End updateSavedQueriesUsed

#--------------------------#
sub searchSA_LADB
#--------------------------#
{
  # Local variables
  my ($PROGDIR, $USERDIR, $refWinLAQueryCols, $refWinReport, $refWinConfig, $refWin, $refSTR) = @_;
  # Hide Progress controls in main window
  $$refWin->lblPbCurr->Text('');
  $$refWin->pb->SetPos(0);
  $$refWin->lblPbCount->Text('');
  $$refWin->lblPbCurr->Hide();
  $$refWin->pb->Hide();
  $$refWin->lblPbCount->Hide();
  my %searchParams;
  $searchParams{dbFile}       = $$refWin->tfInput->Text();
  $searchParams{maxResults}   = $$refWin->tfLASearchSAMaxRes->Text();
  $searchParams{reportDir}    = $$refWinReport->tfReportDir->Text();
  $searchParams{reportFormat} = $$refWinReport->cbReportFormat->GetString($$refWinReport->cbReportFormat->GetCurSel());
  $searchParams{replReport}   = 1 if $$refWinReport->chReplaceReport->Checked();
  $searchParams{openReport}   = 1 if $$refWinReport->chOpenReport->Checked();
  $searchParams{incHeader}    = 1 if $$refWinReport->chReportOptIncHeaders->Checked();
  $searchParams{incSource}    = 1 if $$refWinReport->chReportOptIncSource->Checked();
  $searchParams{incISP}       = 1 if $$refWinReport->chReportOptIncISP->Checked();
  $searchParams{incGeoIP}     = 1 if $$refWinReport->chReportOptIncGeoIP->Checked();
  $searchParams{incUADetails} = 1 if $$refWinReport->chReportOptIncUADetails->Checked();
  $searchParams{incWeekdays}  = 1 if $$refWinReport->chReportOptIncWeekday->Checked();
  my $selOutputDTFormat       = $$refWinReport->cbOutputDTFormat->GetCurSel();
  $searchParams{localTZ}      = $$refWinConfig->cbLocalTZ->GetString($$refWinConfig->cbLocalTZ->GetCurSel());
  $searchParams{language}     = $$refWinConfig->cbDefaultLang->GetString($$refWinConfig->cbDefaultLang->GetCurSel());
  ($searchParams{outPattern}, $searchParams{outTZ}) = (&infoDTFormat($$refWinReport->cbOutputDTFormat->GetString($selOutputDTFormat)))[1,3];
  # Get selected indicators
  for (my $i = 1; $i <= $$refWin->gridLASearchSAInd->GetRows(); $i++) {
    if ($$refWin->gridLASearchSAInd->GetCellCheck($i, 0)) {
      my $indicator = $$refWin->gridLASearchSAInd->GetCellText($i, 1);
      $searchParams{selIndicators}{$indicator}{score}  = $$refWin->gridLASearchSAInd->GetCellText($i, 2);
      $searchParams{selIndicators}{$indicator}{limit}  = $$refWin->gridLASearchSAInd->GetCellText($i, 3);
      $searchParams{selIndicators}{$indicator}{option} = $$refWin->gridLASearchSAInd->GetCellText($i, 4);
    }
  }
  # Get selected columns options
  if (!$$refWinLAQueryCols) { &createWinLAQueryCols(); }
  $searchParams{DISTINCT}    = 1 if $$refWinLAQueryCols->chLAQueryColsDistinct->Checked();
  $searchParams{cols}{ALL}   = 1 if $$refWinLAQueryCols->rbLAQueryColsAll->Checked();
  $searchParams{cols}{COUNT} = 1 if $$refWinLAQueryCols->chLAQueryColsAllCount->Checked();
  if (!$searchParams{cols}{ALL}) {
    # Selected columns
    for (my $i = 1; $i < 12; $i++) {
      if ($$refWinLAQueryCols->gridLAQueryCols->GetCellCheck($i, 0)) {
        $searchParams{cols}{$i}{colName} = $$refWinLAQueryCols->gridLAQueryCols->GetCellText($i, 2);
        $searchParams{cols}{$i}{colName} = 'datetimeInt' if $searchParams{cols}{$i}{colName} eq $$refSTR{'DTDB'};
        $searchParams{cols}{$i}{COUNT}   = 1 if $$refWinLAQueryCols->gridLAQueryCols->GetCellCheck($i, 1);
      }
    }
  }
  # Save query params and options as JSON
  my $destDir = $searchParams{dbFile};
  while (chop($destDir) ne "\\") { } # Dir only
  my $procID   = time;
  my $jsonObj  = JSON->new;
  my $jsonText = $jsonObj->encode(\%searchParams);
  if (open(my $json, '>:encoding(cp1252)', "$destDir\\CurrentSearchParams-" . $procID .'.json')) {
    print $json $jsonText;
    close($json);
  }
  # Start Search Database Process
  my $command = 'XL-Parser-process ' . "LADB-Search $procID \"$PROGDIR\" \"$destDir\" \"$USERDIR\"";
  Win32::Process::Create(my $processObj, $PROGDIR .'\XL-Parser-process.exe', $command, 0, NORMAL_PRIORITY_CLASS, $PROGDIR);
  $$refWin->Enable();
  $$refWin->BringWindowToTop();
  $$refWin->gridLASearchSAInd->BringWindowToTop();
  
}  #--- End searchSA_LADB

#------------------------------------------------------------------------------#
sub listValFilterFieldDB
#------------------------------------------------------------------------------#
{
  # Local variables
  my ($field, $dbFile, $refWin, $refSTR) = @_;
  my @listVal;
  # Connect to database
  $dbFile = encode('utf8', $dbFile);
  my $dsn = "DBI:SQLite:dbname=$dbFile";
  if (my $dbhLog = DBI->connect($dsn, undef, undef, { })) {
    my $all;
    if    ($field eq $$refSTR{'LFclientIP'}  ) { $all = $dbhLog->selectall_arrayref('SELECT DISTINCT remoteIP FROM LOG ORDER BY remoteIP ASC');           }
    elsif ($field eq $$refSTR{'LFHTTPmethod'}) { $all = $dbhLog->selectall_arrayref('SELECT DISTINCT http_method FROM LOG ORDER BY http_method ASC');     }
    elsif ($field eq $$refSTR{'LFHTTPreq'}   ) { $all = $dbhLog->selectall_arrayref('SELECT DISTINCT http_request FROM LOG ORDER BY http_request ASC');   }
    elsif ($field eq $$refSTR{'LFHTTPparam'} ) { $all = $dbhLog->selectall_arrayref('SELECT DISTINCT http_params FROM LOG ORDER BY http_params ASC');     }
    elsif ($field eq $$refSTR{'LFHTTPprot'}  ) { $all = $dbhLog->selectall_arrayref('SELECT DISTINCT http_protocol FROM LOG ORDER BY http_protocol ASC'); }
    elsif ($field eq $$refSTR{'LFHTTPstatus'}) { $all = $dbhLog->selectall_arrayref('SELECT DISTINCT http_status FROM LOG ORDER BY http_status ASC');     }
    elsif ($field eq $$refSTR{'LFsize'}      ) { $all = $dbhLog->selectall_arrayref('SELECT DISTINCT size FROM LOG ORDER BY size ASC');                   }
    elsif ($field eq $$refSTR{'LFReferer'}   ) { $all = $dbhLog->selectall_arrayref('SELECT DISTINCT referer FROM LOG ORDER BY referer ASC');             }
    elsif ($field eq $$refSTR{'LFUA'}        ) { $all = $dbhLog->selectall_arrayref('SELECT DISTINCT useragent FROM LOG ORDER BY useragent ASC');         }
    elsif ($field eq $$refSTR{'isp'}         ) { $all = $dbhLog->selectall_arrayref('SELECT DISTINCT isp FROM IP ORDER BY isp ASC');                      }
    elsif ($field eq $$refSTR{'GeoIPDB'}     ) { $all = $dbhLog->selectall_arrayref('SELECT DISTINCT geoIP FROM IP ORDER BY geoIP ASC');                  }
    elsif ($field eq $$refSTR{'LFUA-t'}      ) { $all = $dbhLog->selectall_arrayref('SELECT DISTINCT type FROM UA ORDER BY type ASC');                    }
    elsif ($field eq $$refSTR{'LFUA-os'}     ) { $all = $dbhLog->selectall_arrayref('SELECT DISTINCT os FROM UA ORDER BY os ASC');                        }
    elsif ($field eq $$refSTR{'LFUA-b'}      ) { $all = $dbhLog->selectall_arrayref('SELECT DISTINCT browser FROM UA ORDER BY browser ASC');              }
    elsif ($field eq $$refSTR{'LFUA-d'}      ) { $all = $dbhLog->selectall_arrayref('SELECT DISTINCT device FROM UA ORDER BY device ASC');                }
    elsif ($field eq $$refSTR{'LFUA-l'}      ) { $all = $dbhLog->selectall_arrayref('SELECT DISTINCT lang FROM UA ORDER BY lang ASC');                    }
    foreach my $row (@$all) {
      my @values = @$row;
      push(@listVal, $values[0]) if $values[0];
    }
    $dbhLog->disconnect();
    return(\@listVal);
  } else { Win32::GUI::MessageBox($$refWin, $$refSTR{'errorConnectDB'}.': '.$DBI::errstr, $$refSTR{'error'}, 0x40010); }
  
}  #--- End listValFilterFieldDB

#--------------------------#
sub createLFDB
#--------------------------#
{
  # Local variables
  my $LFDBFile = shift;
  # Create a new database
  $LFDBFile = encode('utf8', $LFDBFile);
  my $dsn   = "DBI:SQLite:dbname=$LFDBFile";
  my $dbh   = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 }) or return(0);
  # Create main table
  my $stmt = qq(CREATE TABLE IF NOT EXISTS LF
                (name       VARCHAR(255)  NOT NULL,
                 sample     VARCHAR(255)  NOT NULL,
                 pattern    VARCHAR(255)  NOT NULL,
                 regex      VARCHAR(255)  NOT NULL,
                 PRIMARY KEY (name)));
  my $rv = $dbh->do($stmt);
  return(0) if $rv < 0;
  $dbh->disconnect();
  return(1);
  
}  #--- End createLFDB

#--------------------------#
sub loadLFDB
#--------------------------#
{
  # Local variables
  my ($LFDBFile, $refWinLFDB, $refWin, $refSTR) = @_;
  if (-f $LFDBFile) {
    # Connect to DB
    $LFDBFile = encode('utf8', $LFDBFile);
    my $dsn   = "DBI:SQLite:dbname=$LFDBFile";
    if (my $dbh   = DBI->connect($dsn, undef, undef, { AutoCommit => 1 })) {
      # Check if LF table exists
      my $sth;
      eval { $sth = $dbh->table_info(undef, undef, '%', 'TABLE'); };
      if ($@) {
        Win32::GUI::MessageBox($$refWin, $$refSTR{'errorConnectDB'}.': '.$DBI::errstr, $$refSTR{'error'}, 0x40010);
        return(0);
      }
      my @info = $sth->fetchrow_array;
      $sth->finish();
      if ($info[2] eq 'LF') { # If table LF exists, than load data
        my $all = $dbh->selectall_arrayref('SELECT * FROM LF ORDER BY name ASC');
        # Database: table = LF, Fields = name, sample, pattern, regex
        # Feed the grid
        my $i = 1;
        $$refWinLFDB->gridLF->SetRows(scalar(@$all)+1);
        foreach my $row (@$all) {
          my (@values) = @$row;
          $$refWinLFDB->gridLF->SetCellText($i, 0, $values[0]); # Name
          $$refWinLFDB->gridLF->SetCellText($i, 1, $values[1]); # Sample
          $$refWinLFDB->gridLF->SetCellText($i, 2, $values[2]); # Pattern
          $$refWinLFDB->gridLF->SetCellText($i, 3, $values[3]); # Regex
          $i++;
        }
        # Refresh grid
        $$refWinLFDB->gridLF->SortCells(0, 1, sub { my ($e1, $e2) = @_; return (lc($e1) cmp lc($e2)); });
        $$refWinLFDB->gridLF->AutoSizeColumns();
        $dbh->disconnect();
        return(1);
      } else { Win32::GUI::MessageBox($$refWin, $$refSTR{'errorConnectDB'}.': '.$DBI::errstr, $$refSTR{'error'}, 0x40010); }
    } else { Win32::GUI::MessageBox($$refWin, $$refSTR{'errorDB'}, $$refSTR{'error'}, 0x40010); }
  }
  return(0);

}  #--- End loadLFDB

#--------------------------#
sub findLFFormatInLog
#--------------------------#
{
  # Get first line of one file in input
  my ($firstLine, $refWinLFDB, $refWin) = @_;
  if (!$firstLine and ($$refWin->rbInputDir->Checked() or $$refWin->rbInputFiles->Checked())) {
    my $oneFile = &getOneFile;
    if (open(my $fh, $oneFile)) {
      while (<$fh>) { if ($_ !~ /^#/) { $firstLine = $_; last; } }
      close($fh);
    }
  }
  # Compare with all input format
  my $bestLFName;
  my $LFRegexLength = 0;
  my $match         = 0;
  my @listMatches;
  if ($firstLine) {
    for (my $i = 1; $i < $$refWinLFDB->gridLF->GetRows(); $i++) {
      my $regex = $$refWinLFDB->gridLF->GetCellText($i, 3);
      if ($firstLine =~ /($regex)/i) {
        my $LFName = $$refWinLFDB->gridLF->GetCellText($i, 0);
        push(@listMatches, $LFName);
        $match++;
        if (length($regex) > $LFRegexLength) { # Keep the longest regex
          $bestLFName    = $LFName;
          $LFRegexLength = length($regex);
        }
      }
    }
  }
  return(1, $bestLFName, undef) if $bestLFName and $match == 1;
  return(2, $bestLFName, @listMatches) if $match > 1;
  return(0, undef, undef);
  
}  #--- End findLFFormatInLog

#--------------------------#
sub getLFDetails
#--------------------------#
{
  # Guess format
  my ($name, $refWinLFDB) = @_;
  for (my $i = 1; $i < $$refWinLFDB->gridLF->GetRows(); $i++) {
    my $curNameRow = $$refWinLFDB->gridLF->GetCellText($i, 0);
    return($$refWinLFDB->gridLF->GetCellText($i, 2), $$refWinLFDB->gridLF->GetCellText($i, 3)) if $curNameRow eq $name;
  }
  return(0);
  
}  #--- End getLFDetails

#--------------------------#
sub createLAFilterSetDB
#--------------------------#
{
  # Local variables
  my $LAFiltersDBFile = shift;
  # Create a new database
  $LAFiltersDBFile = encode('utf8', $LAFiltersDBFile);
  my $dsn          = "DBI:SQLite:dbname=$LAFiltersDBFile";
  if (my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 }) or return(0)) {
    # Create main table
    my $stmt = qq(CREATE TABLE IF NOT EXISTS FILTER_SET
                  (category   VARCHAR(255)  NOT NULL,
                   name       VARCHAR(255)  NOT NULL,
                   path       VARCHAR(255)  NOT NULL,
                   whiteList  INT,
                   PRIMARY KEY (category,name)));
    my $rv = $dbh->do($stmt);
    $dbh->disconnect();
    return(0) if $rv < 0;
    return(1);
  } else { return(0); }
  
}  #--- End createLAFilterSetDB

#--------------------------#
sub loadLAFilterSetDB
#--------------------------#
{
  # Local variables
  my ($type, $LAFilterSetDBFile, $refWinFilterSet, $refWin, $refWinLAFilters, $refSTR) = @_; # if type == 1: white list filters
  my %cat;
  my %json;
  if (-f $LAFilterSetDBFile) {
    # Connect to DB
    $LAFilterSetDBFile = encode('utf8', $LAFilterSetDBFile);
    my $dsn = "DBI:SQLite:dbname=$LAFilterSetDBFile";
    if (my $dbh = DBI->connect($dsn, undef, undef, { AutoCommit => 1 })) {
      # Check if FILTER_SET table exists
      my $sth;
      eval { $sth = $dbh->table_info(undef, undef, '%', 'TABLE'); };
      if ($@) {
        Win32::GUI::MessageBox($$refWin, $$refSTR{'errorConnectDB'}.': '.$DBI::errstr, $$refSTR{'error'}, 0x40010);
        return(0);
      }
      my $refAllRows = $sth->fetchall_arrayref();
      $sth->finish();
      my $tableExists = 0;
      foreach my $refRow (@{$refAllRows}) { $tableExists = 1 if $$refRow[2] eq 'FILTER_SET'; }
      if ($tableExists) { # If table FILTER_SET exists, than load data
        my $all;
        if ($type) { $all = $dbh->selectall_arrayref('SELECT * FROM FILTER_SET WHERE whiteList == 1 ORDER BY category,name'); }
        else       { $all = $dbh->selectall_arrayref('SELECT * FROM FILTER_SET WHERE whiteList == 0 ORDER BY category,name'); }
        foreach my $entry (@$all) {
          if (-f $$entry[2]) { # The Json file must be present
            $json{$$entry[2]} = 1;
            # Add to controls
            if (!exists($cat{$$entry[0]})) { # No duplicates
              # Treeview
              my $parent = $$refWinLAFilters->tvLAFilters->InsertItem(-text => $$entry[0]);
              if (my $refFilterSetNames = &getFilterSetNames($LAFilterSetDBFile, $$entry[0])) {
                foreach my $name (@{$refFilterSetNames}) {
                  $$refWinLAFilters->tvLAFilters->InsertItem(-parent => $parent, -text => $$name[0]);
                }
              }
              $cat{$$entry[0]} = 1;
            }
          # The Json file doesn't exist, remove the entry
          } else {
            my $sth = $dbh->prepare('DELETE FROM FILTER_SET WHERE category == ? AND name == ?');
            my $rv  = $sth->execute($$entry[0], $$entry[1]);
          }
        }
        $dbh->disconnect();
      } else { Win32::GUI::MessageBox($$refWin, $$refSTR{'errorConnectDB'}.': '.$DBI::errstr, $$refSTR{'error'}, 0x40010); return(0); }
    } else { Win32::GUI::MessageBox($$refWin, $$refSTR{'errorDB'}, $$refSTR{'error'}, 0x40010); return(0); }
  }
  # Browse the filters directory, parse json file and add new filter if not exist
  my @dirParts = split(/\\/, $LAFilterSetDBFile);
  pop(@dirParts);
  my $jsonDir = join("\\", @dirParts)."\\".'Filters';
  if (-d $jsonDir) {
    if (opendir(DIR,"$jsonDir\\")) {
      while (my $file = readdir(DIR)) {
        if ($file =~ /\.json/) {
          if (open(my $json, "$jsonDir\\$file")) {
            my $jsonText = <$json>;
            close($json);
            my $jsonObj = JSON->new;
            my $refFilter = $jsonObj->decode($jsonText);
            if (!(&isFilterSetExists($LAFilterSetDBFile, $$refFilter{category}, $$refFilter{name}))) {
              # Add to database
              if (&addLAFilterSetDB($LAFilterSetDBFile, $$refFilter{category}, $$refFilter{name}, $$refFilter{whiteList}, "$jsonDir\\$file")) {
                # Add to controls
                if (!exists($cat{$$refFilter{category}})) { # No duplicates
                  # Treeview
                  my $parent = $$refWinLAFilters->tvLAFilters->InsertItem(-text => $$refFilter{category});
                  if (my $refFilterSetNames = &getFilterSetNames($LAFilterSetDBFile, $$refFilter{category})) {
                    foreach my $name (@{$refFilterSetNames}) {
                      $$refWinLAFilters->tvLAFilters->InsertItem(-parent => $parent, -text => $$name[0]);
                    }
                  }
                  $cat{$$refFilter{category}} = 1;
                }
              }
            }
          }
        }
      }
      closedir(DIR);
    }
  }

}  #--- End loadLAFilterSetDB

#------------------------------------------------------------------------------#
sub getFilterSetNames
#------------------------------------------------------------------------------#
{
  # Local variables
  my ($LAFilterSetDBFile, $category) = @_;
  $LAFilterSetDBFile = encode('utf8', $LAFilterSetDBFile);
  my $dsn = "DBI:SQLite:dbname=$LAFilterSetDBFile";
  if (my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 })) {
    my $sth   = $dbh->prepare('SELECT name FROM FILTER_SET WHERE category == ? COLLATE NOCASE ORDER BY name');
    if ($sth->execute($category) > -1) {
      my $refFilserSetNames = $sth->fetchall_arrayref();
      $sth->finish();
      $dbh->disconnect();
      return($refFilserSetNames);
    }
  }
  return(0);
  
}  #--- End getFilterSetNames

#------------------------------------------------------------------------------#
sub getFilterSetFilters
#------------------------------------------------------------------------------#
{
  # Local variables
  my ($LAFilterSetDBFile, $category, $name) = @_;
  $LAFilterSetDBFile = encode('utf8', $LAFilterSetDBFile);
  my $dsn = "DBI:SQLite:dbname=$LAFilterSetDBFile";
  if (my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 })) {
    my $sth   = $dbh->prepare('SELECT path FROM FILTER_SET WHERE category == ? AND name == ? COLLATE NOCASE');
    if ($sth->execute($category, $name) > -1) {
      # Load filters from json file
      my $jsonFile = ($sth->fetchrow_array())[0];
      $sth->finish();
      if (-f $jsonFile and open(my $json, $jsonFile)) {
        my $jsonText = <$json>;
        close($json);
        $dbh->disconnect();
        my $jsonObj = JSON->new;
        return($jsonObj->decode($jsonText));
      }
    }
    $dbh->disconnect();
  }
  return(0);
  
}  #--- End getFilterSetFilters
  
#------------------------------------------------------------------------------#
sub isFilterSetExists
#------------------------------------------------------------------------------#
{
  # Local variables
  my ($LAFilterSetDBFile, $category, $name) = @_;
  $LAFilterSetDBFile = encode('utf8', $LAFilterSetDBFile);
  my $dsn = "DBI:SQLite:dbname=$LAFilterSetDBFile";
  if (my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 })) {
    my $sth   = $dbh->prepare('SELECT category FROM FILTER_SET WHERE category == ? AND name == ? COLLATE NOCASE');
    if ($sth->execute($category, $name) > -1 and $sth->fetchrow_array()) {
      $sth->finish();
      $dbh->disconnect();
      return(1);
    } else {
      $sth->finish();
      $dbh->disconnect();
      return(0);
    }
  } return(0);
  
}  #--- End isFilterSetExists

#------------------------------------------------------------------------------#
sub addLAFilterSetDB
#------------------------------------------------------------------------------#
{
  # Local variables
  my ($LAFilterSetDBFile, $category, $name, $whiteList, $jsonFile) = @_;
  $LAFilterSetDBFile = encode('utf8', $LAFilterSetDBFile);
  my $dsn = "DBI:SQLite:dbname=$LAFilterSetDBFile";
  if (my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 })) {
    my $sth   = $dbh->prepare('INSERT INTO FILTER_SET (category, name, whiteList, path) VALUES(?,?,?,?)');
    my $rv    = $sth->execute($category, $name, $whiteList, $jsonFile);
    $sth->finish();
    $dbh->disconnect();
    return(0) if $rv < 0;
    return(1);
  } else { return(0); }
  
}  #--- End addLAFilterSetDB

#------------------------------------------------------------------------------#
sub delLAFilterSetDB
#------------------------------------------------------------------------------#
{
  # Local variables
  my ($LAFilterSetDBFile, $category, $name) = @_;
	$LAFilterSetDBFile = encode('utf8', $LAFilterSetDBFile);
  my $dsn = "DBI:SQLite:dbname=$LAFilterSetDBFile";
  if (my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 })) {
    my $sth = $dbh->prepare('DELETE FROM FILTER_SET WHERE category == ? AND name == ?');
    my $rv  = $sth->execute($category, $name);
    $sth->finish();
    $dbh->disconnect();
    return(0) if $rv < 0;
    return(1);
  } else { return(0); }
  
}  #--- End delLAFilterSetDB

#--------------------------#
sub validLAFilterSetDB
#--------------------------#
{
  # Local variables
  my $LAFilterSetDBFile = shift;
  if (-f $LAFilterSetDBFile) {
    # Connect to DB
    $LAFilterSetDBFile = encode('utf8', $LAFilterSetDBFile);
    my $dsn = "DBI:SQLite:dbname=$LAFilterSetDBFile";
    if (my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 })) {
      my $sth;
      eval { $sth = $dbh->table_info(undef, undef, '%', 'TABLE'); };
      return(0) if $@;
      # Test if tables exist, database is valid
      my $refAllRows = $sth->fetchall_arrayref();
      $sth->finish();
      foreach my $refRow (@{$refAllRows}) { return(1) if $$refRow[2] eq 'FILTER_SET'; }
    }
  }
  return(0);
  
}  #--- End validLAFilterSetDB

#--------------------------#
sub createLAFiltersDB
#--------------------------#
{
  # Local variables
  my $LAFiltersDBFile = shift;
  # Create a new database
  $LAFiltersDBFile = encode('utf8', $LAFiltersDBFile);
  my $dsn = "DBI:SQLite:dbname=$LAFiltersDBFile";
  if (my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 }) or return(0)) {
    # Create main table
    my $stmt = qq(CREATE TABLE IF NOT EXISTS FILTERS
                  (id         INT           NOT NULL,
                   field      VARCHAR(255)  NOT NULL,
                   cond       VARCHAR(255)  NOT NULL,
                   matchcase  INT,
                   regex      INT,
                   value      VARCHAR(255)  NOT NULL,
                   PRIMARY KEY (id)));
    my $rv = $dbh->do($stmt);
    $dbh->disconnect();
    return(0) if $rv < 0;
    return(1);
  } else { return(0); }
  
}  #--- End createLAFiltersDB

#--------------------------#
sub loadLAFiltersDB
#--------------------------#
{
  # Local variables
  my ($LAFiltersDBFile, $refWinFieldFilter, $refWin, $refSTR) = @_;
  if (-f $LAFiltersDBFile) {
    # Connect to DB
    $LAFiltersDBFile = encode('utf8', $LAFiltersDBFile);
    my $dsn = "DBI:SQLite:dbname=$LAFiltersDBFile";
    if (my $dbh = DBI->connect($dsn, undef, undef, { AutoCommit => 1 })) {
      # Check if FILTERS table exists
      my $sth;
      eval { $sth = $dbh->table_info(undef, undef, '%', 'TABLE'); };
      if ($@) {
        Win32::GUI::MessageBox($$refWin, $$refSTR{'errorConnectDB'}.': '.$DBI::errstr, $$refSTR{'error'}, 0x40010);
        return(0);
      }
      my $refAllRows = $sth->fetchall_arrayref();
      $sth->finish();
      my $tableExists = 0;
      foreach my $refRow (@{$refAllRows}) { $tableExists = 1 if $$refRow[2] eq 'FILTERS'; }
      if ($tableExists) { # If table FILTERS exists, than load data
        my $all = $dbh->selectall_arrayref('SELECT * FROM FILTERS');
        foreach my $entry (@$all) {
          # Add to grid
          if (my $row = $$refWinFieldFilter->gridFFDB->InsertRow(0, -1)) {
            $$refWinFieldFilter->gridFFDB->SetCellText($row, 0, $$entry[0]);
            $$refWinFieldFilter->gridFFDB->SetCellText($row, 1, $$entry[1]);
            $$refWinFieldFilter->gridFFDB->SetCellText($row, 2, $$entry[2]);
            $$refWinFieldFilter->gridFFDB->SetCellType($row, 3, 4);
            $$refWinFieldFilter->gridFFDB->SetCellType($row, 4, 4);
            if ($$entry[3]) { $$refWinFieldFilter->gridFFDB->SetCellCheck($row, 3, 1);  }
            else            { $$refWinFieldFilter->gridFFDB->SetCellCheck($row, 3, 0);  }
            if ($$entry[4]) { $$refWinFieldFilter->gridFFDB->SetCellCheck($row, 4, 1);  }
            else            { $$refWinFieldFilter->gridFFDB->SetCellCheck($row, 4, 0);  }
            $$refWinFieldFilter->gridFFDB->SetCellText($row, 5, $$entry[5]);
            $$refWinFieldFilter->gridFFDB->SetCellEditable($row, 0, 0);
            $$refWinFieldFilter->gridFFDB->SetCellEditable($row, 1, 0);
            $$refWinFieldFilter->gridFFDB->SetCellEditable($row, 2, 0);
            $$refWinFieldFilter->gridFFDB->SetCellEditable($row, 3, 0);
            $$refWinFieldFilter->gridFFDB->SetCellEditable($row, 4, 0);
            $$refWinFieldFilter->gridFFDB->SetCellEditable($row, 5, 0);
            
            # Refresh grid
            $$refWinFieldFilter->gridFFDB->AutoSizeColumns();
            $$refWinFieldFilter->gridFFDB->ExpandLastColumn();
          }
        }
      }
      $dbh->disconnect();
    } else { Win32::GUI::MessageBox($$refWin, $$refSTR{'errorConnectDB'}.': '.$DBI::errstr, $$refSTR{'error'}, 0x40010); }
  } else { Win32::GUI::MessageBox($$refWin, $$refSTR{'errorDB'}, $$refSTR{'error'}, 0x40010); }
  return(0);

}  #--- End loadLAFiltersDB

#--------------------------#
sub validLAFiltersDB
#--------------------------#
{
  # Local variables
  my $LAFiltersDBFile = shift;
  if (-f $LAFiltersDBFile) {
    # Connect to DB
    $LAFiltersDBFile = encode('utf8', $LAFiltersDBFile);
    my $dsn = "DBI:SQLite:dbname=$LAFiltersDBFile";
    if (my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 })) {
      my $sth;
      eval { $sth = $dbh->table_info(undef, undef, '%', 'TABLE'); };
      return(0) if $@;
      # Test if tables exist, database is valid
      my $refAllRows = $sth->fetchall_arrayref();
      $sth->finish();
      foreach my $refRow (@{$refAllRows}) { return(1) if $$refRow[2] eq 'FILTERS'; }
    }
  }
  return(0);
  
}  #--- End validLAFiltersDB

#--------------------------#
sub uncheckAllFilterSets
#--------------------------#
{
  # Local variables
  my ($refWinLAFilters) = shift;
  my $nextNode = $$refWinLAFilters->tvLAFilters->GetRoot();
  while ($nextNode) {
    $$refWinLAFilters->tvLAFilters->ItemCheck($nextNode, 0);
    if (my $nextChildNode = $$refWinLAFilters->tvLAFilters->GetChild($nextNode)) {
      $$refWinLAFilters->tvLAFilters->ItemCheck($nextChildNode, 0);
      while ($nextChildNode = $$refWinLAFilters->tvLAFilters->GetNextSibling($nextChildNode)) {
        $$refWinLAFilters->tvLAFilters->ItemCheck($nextChildNode, 0);
      }
    }
    $nextNode = $$refWinLAFilters->tvLAFilters->GetNextSibling($nextNode)
  }
  $$refWinLAFilters->tfLAFiltersIPList->Text('');
  $$refWinLAFilters->lblLAFiltersSel->Text(0);
  $$refWinLAFilters->btnLAFiltersEdit->Disable();
  $$refWinLAFilters->btnLAFiltersDel->Disable();
  
}  #--- End uncheckAllFilterSets

#--------------------------#
sub getSelFilterSets
#--------------------------#
{
  # Local variables
  my ($LAFilterSetDBFile, $refWinLAFilters, $refSTR) = @_;
  my $filtersType   = $$refWinLAFilters->TabSelFilters->GetCurSel();
  my $filterISP     = 0;
  my $filterGeoIP   = 0;
  my $filterUA      = 0;
  my $filterWeekday = 0;
  my $whiteList     = 0;
  my $nbrFilterSets = 0;
  my %selFilterSets;
  # Gather selected filters from treeview
  if (!$filtersType or $filtersType == 1) {
    my $firstNode = $$refWinLAFilters->tvLAFilters->GetRoot();
    if ($firstNode) {
      my %item     = $$refWinLAFilters->tvLAFilters->GetItem($firstNode);
      my $category = $item{'-text'};
      my $nextNode = $firstNode;
      if ($$refWinLAFilters->tvLAFilters->ItemCheck($nextNode)) {
        # Enumerate all childs
        if (my $nextChildNode = $$refWinLAFilters->tvLAFilters->GetChild($nextNode)) {
          my %currItem = $$refWinLAFilters->tvLAFilters->GetItem($nextChildNode);
          my $filterSetName = $currItem{'-text'};
          if ($$refWinLAFilters->tvLAFilters->ItemCheck($nextChildNode)) {
            $selFilterSets{$category}{$filterSetName} = {};
            $nbrFilterSets++;
          }
          while ($nextChildNode = $$refWinLAFilters->tvLAFilters->GetNextSibling($nextChildNode)) {
            %currItem = $$refWinLAFilters->tvLAFilters->GetItem($nextChildNode);
            $filterSetName = $currItem{'-text'};
            if ($$refWinLAFilters->tvLAFilters->ItemCheck($nextChildNode)) {
              $selFilterSets{$category}{$filterSetName} = {};
              $nbrFilterSets++;
            }
          }
        }
      }
      
      while ($nextNode = $$refWinLAFilters->tvLAFilters->GetNextSibling($nextNode)) {
        %item    = $$refWinLAFilters->tvLAFilters->GetItem($nextNode);
        $category = $item{'-text'};
        if ($$refWinLAFilters->tvLAFilters->ItemCheck($nextNode)) {
          # Enumerate all childs
          if (my $nextChildNode = $$refWinLAFilters->tvLAFilters->GetChild($nextNode)) {
            my %currItem = $$refWinLAFilters->tvLAFilters->GetItem($nextChildNode);
            my $filterSetName = $currItem{'-text'};
            if ($$refWinLAFilters->tvLAFilters->ItemCheck($nextChildNode)) {
              $selFilterSets{$category}{$filterSetName} = {};
              $nbrFilterSets++;
            }
            while ($nextChildNode = $$refWinLAFilters->tvLAFilters->GetNextSibling($nextChildNode)) {
              %currItem = $$refWinLAFilters->tvLAFilters->GetItem($nextChildNode);
              $filterSetName = $currItem{'-text'};
              if ($$refWinLAFilters->tvLAFilters->ItemCheck($nextChildNode)) {
                $selFilterSets{$category}{$filterSetName} = {};
                $nbrFilterSets++;
              }
            }
          }
        }
      }
    }
    # Gather filters from json files
    foreach my $filterSetCat (keys %selFilterSets) {
      foreach my $filterSetName ((keys %{$selFilterSets{$filterSetCat}})) {
        $selFilterSets{$filterSetCat}{$filterSetName}{AND}         = 0;
        $selFilterSets{$filterSetCat}{$filterSetName}{NBR_FILTERS} = 0;
        $selFilterSets{$filterSetCat}{$filterSetName}{FILTERS}     = &getFilterSetFilters($LAFilterSetDBFile, $filterSetCat, $filterSetName);
        # Ex.: "1":{"operator":"-","value":"33.33.33.33","regex":0,"case":0,"condition":"is","field":"remoteIP"}
        delete($selFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{category});
        delete($selFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{name});
        if ($selFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{whiteList}) { $whiteList = 1; }
        delete($selFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{whiteList});
        # Prepare each filter of the filter set
        for (my $index = 1; $index <= scalar(keys %{$selFilterSets{$filterSetCat}{$filterSetName}{FILTERS}}); $index++) {
          # There is a AND in list
          if ($selFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{operator} eq $$refSTR{'AND'})  {
            $selFilterSets{$filterSetCat}{$filterSetName}{AND}++;
          }
          # Datetime
          if ($selFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'DTDB'}) {
            my ($date, $time);
            if ($selFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{value} =~ /(\d+-\d+-\d+)/) { $date = $1; }
            if ($selFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{value} =~ /(\d+:\d+:\d+)/) { $time = $1; }
            # Date and time
            if ($date and $time) {
              my $strp = DateTime::Format::Strptime->new(pattern => '%F %T');
              if (my $dt = $strp->parse_datetime($selFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{value})) {
                $selFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{int} = $dt->epoch();
              }
            }
            # Date only
            elsif ($date) {
              my $strp = DateTime::Format::Strptime->new(pattern => '%F');
              if (my $dt = $strp->parse_datetime($date)) {
                $selFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{date} = $dt->ymd;
              }
            }
            # Time only
            elsif ($time) {
              my $strp = DateTime::Format::Strptime->new(pattern => '%T');
              if (my $dt = $strp->parse_datetime($time)) {
                $selFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{time} = $dt->hms;
              }
            }
            $filterWeekday = 1; # Indicate to resolve datetime int before filtering
          # Filter by ISP or GeoIP
          } elsif ($selFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'isp'}) {
            $filterISP = 1;
          } elsif ($selFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'GeoIPDB'}) {
            $filterGeoIP = 1;
          # Filter by useragent details
          } elsif ($selFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'LFUA-t'}  or
                   $selFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'LFUA-os'} or
                   $selFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'LFUA-b'}  or
                   $selFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'LFUA-d'}  or
                   $selFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'LFUA-l'}) {
            $filterUA = 1;
          # Filter by weekday
          } elsif ($selFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'Weekday'}) {
            $filterWeekday = 1;
          }
          $selFilterSets{$filterSetCat}{$filterSetName}{NBR_FILTERS}++;
        }
      }
    }
  # Gather IP list and convert to filter
  } else {
    my $IPlist;
    my $nbrLines = $$refWinLAFilters->tfLAFiltersIPList->GetLineCount();
    my $i = 0;
    while ($i <= $nbrLines) {
      if (my $line = $$refWinLAFilters->tfLAFiltersIPList->GetLine($i)) {
        $IPlist .= $line.'|' if $line =~ /^((?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))$/ or
                                $line =~ /($IPv6_re)/;
      }
      $i++;
    }
    if ($IPlist) {
      chop($IPlist);
      $nbrFilterSets                                        = 1;
      $selFilterSets{IPlist}{IPlist}{AND}                   = 0;
      $selFilterSets{IPlist}{IPlist}{NBR_FILTERS}           = 1;
      $selFilterSets{IPlist}{IPlist}{FILTERS}{1}{case}      = 0;
      $selFilterSets{IPlist}{IPlist}{FILTERS}{1}{field}     = 'remoteIP';
      $selFilterSets{IPlist}{IPlist}{FILTERS}{1}{condition} = lc($$refSTR{'Contains'});
      $selFilterSets{IPlist}{IPlist}{FILTERS}{1}{operator}  = '-';
      $selFilterSets{IPlist}{IPlist}{FILTERS}{1}{regex}     = 1;
      $selFilterSets{IPlist}{IPlist}{FILTERS}{1}{value}     = $IPlist;
    }
  }
  return(\%selFilterSets, $nbrFilterSets, $filterISP, $filterGeoIP, $filterUA, $filterWeekday, $whiteList);
  
}  #--- End getSelFilterSets

#------------------------------------------------------------------------------#
sub filtersAsSQLStr
#------------------------------------------------------------------------------#
{
  # Local variables
  my ($refFilterSets, $SQLStr, $timezone, $refSTR) = @_;
  my $firstFilter = 1;
  foreach my $filterSetCat (keys %{$refFilterSets}) {
    foreach my $filterSetName ((keys %{$$refFilterSets{$filterSetCat}})) {
      my $partSQLStr;
      for (my $index = 1; $index <= $$refFilterSets{$filterSetCat}{$filterSetName}{NBR_FILTERS}; $index++) {
        if ($$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{operator}) {
          # Operator
          if ($$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{operator} eq '-') {
            if ($firstFilter) { $firstFilter = 0; }
            else              { $partSQLStr .= $$refSTR{'OR'}.' '; }
          } else { $partSQLStr .= $$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{operator}.' '; }
          # Field
          if ($$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'DTDB'}) {
            $partSQLStr .= 'datetimeInt ';
          } else {
            if ($$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'isp'} or
                $$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'GeoIPDB'}) {
              $partSQLStr .= 'remoteIP IN (SELECT ip FROM IP WHERE ';
              $partSQLStr .= $$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field}.' ';
            } elsif ($$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'LFUA-t'}  or
                     $$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'LFUA-os'} or
                     $$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'LFUA-b'}  or
                     $$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'LFUA-d'}  or
                     $$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'LFUA-l'}) {
              my %colNames = ($$refSTR{'LFUA-t'} => 'Type'  , $$refSTR{'LFUA-os'} => 'os', $$refSTR{'LFUA-b'} => 'browser',
                              $$refSTR{'LFUA-d'} => 'device', $$refSTR{'LFUA-l'}  => 'lang');
              $partSQLStr .= 'useragent IN (SELECT ua FROM UA WHERE ';
              $partSQLStr .= $colNames{$$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field}}.' ';
            } else {
              $partSQLStr .= $$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field}.' ';
            }
          }
          # Condition
          my $condition;
          if ($$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{condition} eq lc($$refSTR{'Contains'})) {
            if    ($$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{regex}) { $condition = 'REGEXP'; }
            elsif ($$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{case} ) { $condition = 'GLOB';   } # Case sensitive
            else                                                                           { $condition = 'LIKE';   } # Case insensitive
          } elsif ($$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{condition} eq lc($$refSTR{'notContain'})) {
            if ($$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{case}) { $condition = 'NOT GLOB';   } # Case sensitive
            else                                                                       { $condition = 'NOT LIKE';   } # Case insensitive
          } elsif ($$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{condition} eq lc($$refSTR{'Before'}) or
                   $$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{condition} eq lc($$refSTR{'Smaller'})) { $condition = '<'; }
          elsif ($$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{condition}   eq lc($$refSTR{'After'}) or
                 $$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{condition}   eq lc($$refSTR{'Bigger'})) { $condition = '>'; }
          else {
            if    ($$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{condition} eq $$refSTR{'is'}   ) { $condition = '=';  }
            elsif ($$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{condition} eq $$refSTR{'isNot'}) { $condition = '!='; }
            else { $condition = $$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{condition}; }
          }
          $partSQLStr .= $condition.' ';
          # Value
          if      ($$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{int} ) {
            $partSQLStr .= $$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{int}.' ';
          } elsif ($$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{date}) {
            $partSQLStr =~ s/$condition $//;
            my $strp = DateTime::Format::Strptime->new(pattern => '%F');
            my $dt   = $strp->parse_datetime($$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{date});
            $dt->set_hour(0);
            $dt->set_minute(0);
            $dt->set_second(0);
            $dt->set_time_zone($timezone);
            $partSQLStr .= '>= '.$dt->epoch().' and datetimeInt < '.($dt->epoch()+86400).' ';
          } elsif ($$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{time}) {
            $partSQLStr =~ s/datetimeInt $condition $//;
            my ($h,$m,$s) = split(/:/, $$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{time});
            my $refTime   = DateTime->now(time_zone => $timezone);
            $refTime->set_hour($h);
            $refTime->set_minute($m);
            $refTime->set_second($s);
            $refTime->set_time_zone('UTC');
            my $refTime2  = $refTime->clone();
            $refTime2->set_hour(0);
            $refTime2->set_minute(0);
            $refTime2->set_second(0);
            my $timeInSeconds = $refTime->epoch()-$refTime2->epoch();
            if ($partSQLStr =~ /timeOfDay > (\d+) AND/) { $partSQLStr =~ s/AND $/OR / if $1 > $timeInSeconds; }
            $partSQLStr .= 'timeOfDay '.$condition.' '.$timeInSeconds.' ';
          } else {
            $partSQLStr .= "'";
            if    ($condition eq 'GLOB' or $condition eq 'NOT GLOB') { $partSQLStr .= '*'; }
            elsif ($condition eq 'LIKE' or $condition eq 'NOT LIKE') { $partSQLStr .= '%'; }
            my $value = $$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{value};
            # Escape special chars
            $value =~ s/'/''/g;
            if (($condition eq 'LIKE' or $condition eq 'NOT LIKE') and ($value =~ /\%/ or $value =~ /_/)) {
              $value =~ s/%/\\%/g;
              $value =~ s/_/\\_/g;
            }
            $partSQLStr .= $value;
            if    ($condition eq 'GLOB' or $condition eq 'NOT GLOB') { $partSQLStr .= '*'; }
            elsif ($condition eq 'LIKE' or $condition eq 'NOT LIKE') {
              $partSQLStr .= '%';
            }
            $partSQLStr .= "' ";
            if ($condition eq 'LIKE' and
                ($$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{value} =~ /\%/ or
                 $$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{value} =~ /_/)) {
              $partSQLStr .= "ESCAPE \'\\\' ";
            }
          }
        }
        if ($$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'isp'}     or
            $$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'GeoIPDB'} or
            $$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'LFUA-t'}  or
            $$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'LFUA-os'} or
            $$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'LFUA-b'}  or
            $$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'LFUA-d'}  or
            $$refFilterSets{$filterSetCat}{$filterSetName}{FILTERS}{$index}{field} eq $$refSTR{'LFUA-l'}) {
          chop($partSQLStr);
          $partSQLStr .= ') ';
        }
      }
      $SQLStr .= $partSQLStr;
    }
  }
  chop($SQLStr);
  return($SQLStr);
  
}  #--- End filtersAsSQLStr

#--------------------------#
sub loadSavedQueriesDB
#--------------------------#
{
  # Local variables
  my ($savedQueriesDB, $refWinLASavedQueries, $refWin, $refSTR) = @_;
  if (-f $savedQueriesDB) {
    # Connect to DB
    $savedQueriesDB = encode('utf8', $savedQueriesDB);
    my $dsn = "DBI:SQLite:dbname=$savedQueriesDB";
    if (my $dbh = DBI->connect($dsn, undef, undef, { })) {
      # Check if QUERIES table exists
      my $sth;
      eval { $sth = $dbh->table_info(undef, undef, '%', 'TABLE'); };
      if ($@) {
        Win32::GUI::MessageBox($$refWin, $$refSTR{'errorConnectDB'}.': '.$DBI::errstr, $$refSTR{'error'}, 0x40010);
        return(0);
      }
      my @info = $sth->fetchrow_array;
      $sth->finish();
      if ($info[2] eq 'QUERIES') { # If table QUERIES exists, than load data
        my $all = $dbh->selectall_arrayref('SELECT * FROM QUERIES ORDER BY cat,name ASC');
        # Database: table = QUERIES, Fields = name, cat, query, used, time
        # Feed the grid
        my $i = 1;
        $$refWinLASavedQueries->gridQueries->SetRows(scalar(@$all)+1);
        foreach my $row (@$all) {
          my (@values) = @$row;
          my ($sec, $min, $hour, $mday, $mon, $year) = (localtime($values[4]))[0,1,2,3,4,5];
          $year += 1900;
          $mon++;
          my $timeStr = sprintf("%04d\-%02d\-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec);
          $$refWinLASavedQueries->gridQueries->SetCellText($i, 0, $values[1]); # Category
          $$refWinLASavedQueries->gridQueries->SetCellText($i, 1, $values[0]); # Name
          $$refWinLASavedQueries->gridQueries->SetCellText($i, 2, $values[3]); # Used
          $$refWinLASavedQueries->gridQueries->SetCellText($i, 3, $timeStr  ); # Date
          $$refWinLASavedQueries->gridQueries->SetCellText($i, 4, $values[2]); # Query
          $i++;
        }
        # Refresh grid
        $$refWinLASavedQueries->gridQueries->SortCells(0, 1, sub { my ($e1, $e2) = @_; return ($e1 cmp $e2); });
        $$refWinLASavedQueries->gridQueries->Refresh();
        $$refWinLASavedQueries->gridQueries->AutoSize();
        my $currWidth = $$refWinLASavedQueries->gridQueries->GetColumnWidth(0);
        $$refWinLASavedQueries->gridQueries->SetColumnWidth(0, $currWidth+10);
        $$refWinLASavedQueries->gridQueries->ExpandLastColumn();
        $dbh->disconnect();
        return(1);
      }
      $dbh->disconnect();
    } else { Win32::GUI::MessageBox($$refWin, $$refSTR{'errorConnectDB'}.': '.$DBI::errstr, $$refSTR{'error'}, 0x40010); }
  } else { Win32::GUI::MessageBox($$refWin, $$refSTR{'errLoadingDB'}, $$refSTR{'errorDB'}, 0x40010); }
  return(0);

}  #--- End loadSavedQueriesDB

#--------------------------#
sub createSavedQueriesDB
#--------------------------#
{
  # Local variables
  my $savedQueriesDB = shift;
  # Create a new database
  $savedQueriesDB = encode('utf8', $savedQueriesDB);
  my $dsn = "DBI:SQLite:dbname=$savedQueriesDB";
  my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 }) or return(0);
  # Create main table
  my $stmt = qq(CREATE TABLE IF NOT EXISTS QUERIES
                (name  VARCHAR(255)  NOT NULL,
                 cat   VARCHAR(255)  NOT NULL,
                 query VARCHAR(255)  NOT NULL,
                 used  INT,
                 time  INT           NOT NULL,
                 PRIMARY KEY (cat,name)));
  my $rv = $dbh->do($stmt);
  return(0) if $rv < 0;
  $dbh->disconnect();
  return(1);
  
}  #--- End createSavedQueriesDB

#--------------------------#
sub validSavedQueriesDB
#--------------------------#
{
  # Local variables
  my $savedQueriesDB = shift;
  if (-f $savedQueriesDB) {
    # Connect to DB
    $savedQueriesDB = encode('utf8', $savedQueriesDB);
    my $dsn = "DBI:SQLite:dbname=$savedQueriesDB";
    if (my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 })) {
      my $sth;
      eval { $sth = $dbh->table_info(undef, undef, '%', 'TABLE'); };
      return(0) if $@;
      my @info = $sth->fetchrow_array;
      $sth->finish();
      return(1) if $info[2] eq 'QUERIES'; # If table QUERIES exists, database is valid
    }
  }
  return(0);
  
}  #--- End validSavedQueriesDB

#--------------------------#
sub loadSAIndGrid
#--------------------------#
{
  # Local variables
  my ($jsonFile, $refWin, $refSTR) = @_;
  # Grid header
  $$refWin->gridLASearchSAInd->SetCellType(    0, 0, 4);
  $$refWin->gridLASearchSAInd->SetCellText(    0, 1, $$refSTR{'Indicator'});
  $$refWin->gridLASearchSAInd->SetCellText(    0, 2, $$refSTR{'Score'});
  $$refWin->gridLASearchSAInd->SetCellText(    0, 3, $$refSTR{'LimitInd'});
  $$refWin->gridLASearchSAInd->SetCellText(    0, 4, $$refSTR{'Options'});
  $$refWin->gridLASearchSAInd->SetCellCheck(   0, 0, 1);
  # Insert indicators in grid
  $$refWin->gridLASearchSAInd->SetRows(15);
  my $refIndicators = &loadSAInd($jsonFile, $refWin, $refSTR);
  foreach my $index (sort { $a <=> $b } keys %{$refIndicators}) {
    $$refWin->gridLASearchSAInd->SetCellType(    $index, 0, 4);
    $$refWin->gridLASearchSAInd->SetCellText(    $index, 1, $$refIndicators{$index}{name});
    $$refWin->gridLASearchSAInd->SetCellText(    $index, 2, $$refIndicators{$index}{score});
    $$refWin->gridLASearchSAInd->SetCellText(    $index, 3, $$refIndicators{$index}{limit});
    $$refWin->gridLASearchSAInd->SetCellText(    $index, 4, $$refIndicators{$index}{options}) if $$refIndicators{$index}{options};
    $$refWin->gridLASearchSAInd->SetCellEditable($index, 1, 0);
    $$refWin->gridLASearchSAInd->SetCellCheck(   $index, 0, 1);
  }
  $$refWin->gridLASearchSAInd->Refresh();
  $$refWin->gridLASearchSAInd->AutoSize();
  $$refWin->gridLASearchSAInd->ExpandLastColumn();
  
}  #--- End loadSAIndGrid

#--------------------------#
sub loadSAInd
#--------------------------#
{
  # Local variables
  my ($jsonFile, $refWin, $refSTR) = @_;
  my %indicators;
  my $refIndicators = \%indicators;
  # If file already exists, load values
  if (-f $jsonFile and open(my $json, $jsonFile)) {
    my $jsonText = <$json>;
    close($json);
    my $jsonObj = JSON->new;
    $refIndicators = $jsonObj->decode($jsonText);
		$$refWin->btnLASearchReset->Enable();
  # File don't exist, set default values
  } else {
    # High number of request
    $$refIndicators{1}{name}     = $$refSTR{'SDSAI1'};
    $$refIndicators{1}{score}    = 4;
    $$refIndicators{1}{limit}    = 10;
    # Request length (nbr)
    $$refIndicators{2}{name}     = $$refSTR{'SDSAI2a'};
    $$refIndicators{2}{score}    = 4;
    $$refIndicators{2}{limit}    = 10;
    $$refIndicators{2}{options}  = 50;
    # Request length (max)
    $$refIndicators{3}{name}     = $$refSTR{'SDSAI2b'};
    $$refIndicators{3}{score}    = 4;
    $$refIndicators{3}{limit}    = 10;
    $$refIndicators{3}{options}  = 50;
    # URI encoding
    $$refIndicators{4}{name}     = $$refSTR{'SDSAI3'};
    $$refIndicators{4}{score}    = 5;
    $$refIndicators{4}{limit}    = 10;
    $$refIndicators{4}{options}  = '%';
    # HTTP Method
    $$refIndicators{5}{name}     = $$refSTR{'SDSAI4'};
    $$refIndicators{5}{score}    = 3;
    $$refIndicators{5}{limit}    = 10;
    $$refIndicators{5}{options}  = 'POST|HEAD|TRACE|OPTIONS|CONNECT';
    # High number of errors
    $$refIndicators{6}{name}     = $$refSTR{'SDSAI5'};
    $$refIndicators{6}{score}    = 4;
    $$refIndicators{6}{limit}    = 10;
    $$refIndicators{6}{options}  = '40|50';
    # SQL Query
    $$refIndicators{7}{name}     = $$refSTR{'SDSAI6'};
    $$refIndicators{7}{score}    = 7;
    $$refIndicators{7}{limit}    = 10;
    $$refIndicators{7}{options}  = '[^\w]union[^\w]|[^\w]select[^\w]';
    # Use of quotes (or double-quotes)
    $$refIndicators{8}{name}     = $$refSTR{'SDSAI7'};
    $$refIndicators{8}{score}    = 6;
    $$refIndicators{8}{limit}    = 10;
    $$refIndicators{8}{options}  = "'|\"|%27|%22";
    # Directory traversal
    $$refIndicators{9}{name}     = $$refSTR{'SDSAI8'};
    $$refIndicators{9}{score}    = 8;
    $$refIndicators{9}{limit}    = 10;
    $$refIndicators{9}{options}  = '\\.\\./|\\.\\.%2[Ff]';
    # Remote file inclusion
    $$refIndicators{10}{name}    = $$refSTR{'SDSAI9'};
    $$refIndicators{10}{score}   = 8;
    $$refIndicators{10}{limit}   = 10;
    $$refIndicators{10}{options} = 'http[:%]';
    # Admin or login scan
    $$refIndicators{11}{name}    = $$refSTR{'SDSAI10'};
    $$refIndicators{11}{score}   = 6;
    $$refIndicators{11}{limit}   = 10;
    $$refIndicators{11}{options} = 'admin|login';
    # Web scanner
    $$refIndicators{12}{name}    = $$refSTR{'SDSAI11'};
    $$refIndicators{12}{score}   = 10;
    $$refIndicators{12}{limit}   = 10;
    $$refIndicators{12}{options} = 'havij|sqlmap|nikto|webcruiser|zap|acunetix|dirbuster|zap|WCRTEXTAREATESTINPUT|r3dm0v3|ApacheBench';
    # No useragent
    $$refIndicators{13}{name}    = $$refSTR{'SDSAI12'};
    $$refIndicators{13}{score}   = 5;
    $$refIndicators{13}{limit}   = 10;
    $$refIndicators{13}{options} = 3;
    # Many useragent
    $$refIndicators{14}{name}    = $$refSTR{'SDSAI13'};
    $$refIndicators{14}{score}   = 5;
    $$refIndicators{14}{limit}   = 10;
  }
  return($refIndicators);
  
}  #--- End loadSAInd

#------------------------------------------------------------------------------#
1;