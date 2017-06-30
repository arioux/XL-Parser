#!/usr/bin/perl
# Perl - v: 5.16.3
#------------------------------------------------------------------------------#
# XL-ParserExtract.pl : Extract functions for XL-Parser
# Website             : http://le-tools.com/
# GitHub		          : https://github.com/arioux/XL-Parser
# Creation            : 2016-07-15
# Modified            : 2017-06-30
# Author              : Alain Rioux (admin@le-tools.com)
#
# Copyright (C) 2016-2017  Alain Rioux (le-tools.com)
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
use Time::Local 'timelocal';
use Win32::Process;

#------------------------------------------------------------------------------#
sub extractExprFiles
#------------------------------------------------------------------------------#
{
  # Local variables
  my ($PROGDIR, $USERDIR, $reportDir, $refWinFileFilters, $refWinFileFormats, $refWinExtraction, $refWinExprOpt,
			$refWinConfig, $refWin, $refSTR) = @_;
  # Hide Progress controls in main window
  $$refWin->lblPbCurr->Text('');
  $$refWin->pb->SetPos(0);
  $$refWin->lblPbCount->Text('');
  $$refWin->lblPbCurr->Hide();
  $$refWin->pb->Hide();
  $$refWin->lblPbCount->Hide();
	&createWinExtraction() if !$$refWinExtraction;
  my %extractParams;
	# Get input
	$extractParams{input} = $$refWin->tfInput->Text();
	if ($$refWin->rbInputClipboard->Checked()) { $extractParams{inputType} = 'Clipboard'; }
	else {
		if ($$refWin->rbInputDir->Checked()) {
			$extractParams{inputType}  = 'Dir';
			$extractParams{recurseDir} = 1 if $$refWin->chInputDirRecurse->Checked();
			# Get Filters
			$extractParams{filters} = &getFilters($refWinFileFormats, $refWinFileFilters, $refWin, $refSTR) if $$refWinFileFilters;
		} elsif ($$refWin->rbInputFiles->Checked()) { $extractParams{inputType} = 'Files'; }
	}
	# Get file formats
	&getFileFormats(\%extractParams, $refWinFileFormats, $refWin, $refSTR) if $refWinFileFormats;
  $extractParams{reportDir} = $reportDir;
	# Expression list
	for (my $k = 1; $k < $$refWin->gridExtraction->GetRows(); $k++) {
		my $operator = $$refWin->gridExtraction->GetCellText( $k, 0);
		my $case     = $$refWin->gridExtraction->GetCellCheck($k, 1);
		my $regex    = $$refWin->gridExtraction->GetCellCheck($k, 2);
		my $invert   = $$refWin->gridExtraction->GetCellCheck($k, 3);
		my $expr     = $$refWin->gridExtraction->GetCellText( $k, 4);
		my $comment  = $$refWin->gridExtraction->GetCellText( $k, 5);
		$extractParams{expressions}{$k}{operator} = $operator;
		$extractParams{expressions}{$k}{case}     = $case;
		$extractParams{expressions}{$k}{regex}    = $regex;
		$extractParams{expressions}{$k}{invert}   = $invert;
		$extractParams{expressions}{$k}{expr}     = $expr;
		$extractParams{expressions}{$k}{nbrRes}   = 0;
		# Save expressions to history
		&addExprHisto($case, $regex, $invert, $expr, $comment) if $$refWinExtraction->chEnableExprHistory->Checked();
		# Update Expression database (used indicator)
		&updateExprDBUsed($expr, $refWinExtraction, $refWinConfig, $refWin, $refSTR);
	}
  # If some option have been set
  if ($$refWinExprOpt) {
		$extractParams{reportDir}    = $reportDir;
		$extractParams{modeByFile}   = 1 if $$refWinExprOpt->rbExprOptSearchByFile->Checked();
		$extractParams{maxResByFile} = $$refWinExprOpt->tfExprOptMaxResFile->Text();
		$extractParams{maxResTot}    = $$refWinExprOpt->tfExprOptMaxResTot->Text();
		$extractParams{linesBefore}  = $$refWinExprOpt->tfExprOptIncContextLineBefore->Text();
		$extractParams{linesAfter}   = $$refWinExprOpt->tfExprOptIncContextLineAfter->Text();
		$extractParams{noDupl}       = 1 if $$refWinExprOpt->chExprOptNoDuplicate->Checked();
  }
  # Save extract params and options as JSON
	my $procID   = time;
  my $jsonObj  = JSON->new;
  my $jsonText = $jsonObj->encode(\%extractParams);
  if (open(my $json, '>:encoding(cp1252)', "$reportDir\\ExtractExprParams-" . $procID .'.json')) {
    print $json $jsonText;
    close($json);
  }
  # Start Process
  my $command = 'XL-Parser-process ' . "Extract-Expr $procID \"$PROGDIR\" \"$reportDir\" \"$USERDIR\"";
  Win32::Process::Create(my $processObj, $PROGDIR .'\XL-Parser-process.exe', $command, 0, NORMAL_PRIORITY_CLASS, $PROGDIR);
	$$refWin->btnExtractRefresh->Enable();
  $$refWin->Enable();
  $$refWin->BringWindowToTop();

}  #--- End extractExprFiles

#--------------------------#
sub updateExprDBUsed
#--------------------------#
{
  # Local variables
  my ($expr, $refWinExtraction, $refWinConfig, $refWin, $refSTR) = @_;
  my $exprExists = 0;
  my $usedValue  = 0;
  my $exprDBFile = $$refWinConfig->tfExprDB->Text();
  # Verify if expression exists in grid
  for (my $k = 1; $k < $$refWinExtraction->gridExprDatabase->GetRows(); $k++) {
    my $currEntryExpr = $$refWinExtraction->gridExprDatabase->GetCellText($k, 4);
    if ($expr eq $currEntryExpr) {
      # Update used value
      $usedValue = $$refWinExtraction->gridExprDatabase->GetCellText($k, 0);
      $usedValue++;
      $$refWinExtraction->gridExprDatabase->SetCellText($k, 0, $usedValue);
      $exprExists = 1;
      last;
    }
  }
  # Update in database
  if ($exprExists and -f $exprDBFile) {
    my $dsn = "DBI:SQLite:dbname=$exprDBFile";
    if (my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 })) {
      # Database: table = EXPR_DB, Fields = used, matchcase, regex, invert, expr, comment
      my $sth = $dbh->prepare('UPDATE EXPR_DB SET used = ? WHERE ? == expr');
      my $rv  = $sth->execute($usedValue, $expr);
      Win32::GUI::MessageBox($$refWin, $$refSTR{'errUpdatingDB'}.$DBI::errstr, $$refSTR{'error'}, 0x40010) if $rv < 0;
      $dbh->disconnect();
    } else { Win32::GUI::MessageBox($$refWin, $$refSTR{'errorConnectDB'}.$DBI::errstr, $$refSTR{'error'}, 0x40010); }
    # Sort grid
    $$refWinExtraction->gridExprDatabase->SortCells(0, 0, sub { my ($e1, $e2) = @_; return ($e1 <=> $e2); }); # Sort by used, descending
    $$refWinExtraction->gridExprDatabase->Refresh();
  }

}  #--- End updateExprDBUsed

#------------------------------------------------------------------------------#
sub textExpr
#------------------------------------------------------------------------------#
{
  # Local variables
  my ($line, $refExpr, $globalExpr) = @_;
  my $expr   = $$refExpr{expr};
  my $nbrRes = 0;
  my @listRes;
  $expr = quotemeta($expr) if !$$refExpr{regex};
  # Output :
  #   If result == 1 and $nbrRes == 0, means no capture, but expression matches
  #   If result == 1 and $nbrRes > 1, $nbrRes is the number of extracted data and $refListRes is the list of the data
  # Line match
  if (($$refExpr{case} and ($line =~ /$expr/ )) or (!$$refExpr{case} and ($line =~ /$expr/i))) {
    # Invert but match, no need to continue
    return(0, 0, undef) if $$refExpr{invert};
    # If there is at least one capture group, we must extract data
    my $r = Extract::Regex->new($expr, 1);
    if ($r->nbrCaptureGroups()) {
      while (($$refExpr{case} and ($line =~ /$expr/ )) or (!$$refExpr{case} and ($line =~ /$expr/i))) {
        my ($partRes, $pos, $width) = &extractExpr($line, $expr, $$refExpr{case});
        if ($partRes) {
          $nbrRes++;
          push(@listRes, "$globalExpr\t$partRes");
          # Remove processed part of the line
          chomp($partRes);
          my $lineWidth = length($line);
          my $offset    = $pos+$width;
          $line         = substr($line,$offset,$lineWidth-$offset);
        } else {
          if ($$refExpr{case}) { $line =~ s/$expr//i; }
          else                 { $line =~ s/$expr//;  }
        }
      }
      return(1, $nbrRes, \@listRes);
    # No capture group, test if expr match line only
    } else {
      push(@listRes, "$globalExpr\t$line");
      return(1, 1, \@listRes);
    }
  }
  # Line doesn't match, but invert option is selected
  elsif ($$refExpr{invert}) {
    push(@listRes, "$globalExpr\t$line");
    return(1, 1, \@listRes);
  }
  # Line doesn't match
  else { return(0, 0, undef); }
  
}  #--- End textExpr

#------------------------------------------------------------------------------#
sub textExprAll
#------------------------------------------------------------------------------#
{
  # Local variables
  my ($line, $refExpr, $refSTR) = @_;
  my $expr   = $$refExpr{expr};
  my $nbrRes = 0;
  my @listRes;
  $expr = quotemeta($expr) if !$$refExpr{regex};
  # Output :
  #   If result == 1 and $nbrRes == 0, means no capture, but expression matches
  #   If result == 1 and $nbrRes > 1, $nbrRes is the number of extracted data and $refListRes is the list of the data
  # Line match
  if (($$refExpr{case} and ($line =~ /$expr/ )) or (!$$refExpr{case} and ($line =~ /$expr/i))) {
    # Invert but match, no need to continue
    return(0, 0, undef) if $$refExpr{invert};
    # If there is at least one capture group, we must extract data
    my $r = Extract::Regex->new($expr, 1);
    if ($r->nbrCaptureGroups()) {
      while (($$refExpr{case} and ($line =~ /$expr/ )) or (!$$refExpr{case} and ($line =~ /$expr/i))) {
        my ($partRes, $pos, $width) = &extractExpr($line, $expr, $$refExpr{case});
        if ($partRes) {
          $nbrRes++;
          push(@listRes, "$expr\t$partRes");
          # Remove processed part of the line
          chomp($partRes);
          my $lineWidth = length($line);
          my $offset    = $pos+$width;
          $line         = substr($line,$offset,$lineWidth-$offset);
        } else {
          if ($$refExpr{case}) { $line =~ s/$expr//i; }
          else                 { $line =~ s/$expr//;  }
        }
      }
      return(1, $nbrRes, \@listRes);
    # No capture group, test if expr match line only
    } else {
      push(@listRes, "$$refExpr{expr}\t$line");
      return(1, 1, \@listRes);
    }
  }
  # Line doesn't match, but invert option is selected
  elsif ($$refExpr{invert}) {
    push(@listRes, "[$$refSTR{'Invert'}] $$refExpr{expr}\t$line");
    return(1, 1, \@listRes);
  }
  # Line doesn't match
  else { return(0, 0, undef); }
  
}  #--- End textExprAll

#------------------------------------------------------------------------------#
sub extractExpr
#------------------------------------------------------------------------------#
{
  # Local variables
  my ($line, $expr, $case) = @_;
  my $res   = '';
  my $width = 0;
  my $pos   = 0;
  my @listRes;
  # Test expr again
  if ($case)  { @listRes = ($line =~ /$expr/);  }
  else        { @listRes = ($line =~ /$expr/i); }
  foreach (@listRes) {
    if (defined $_) {
      $res  .= "$_\t";
      $pos   = index($line,$_,$pos);
      $width = length($_);
    }
  }
  chop($res);
  return($res, $pos, $width);

}  #--- End extractExpr

#------------------------------------------------------------------------------#
sub extractSOFiles
#------------------------------------------------------------------------------#
{
  # Local variables
  my ($PROGDIR, $USERDIR, $reportDir, $refWinFileFilters, $refWinFileFormats, $refWin, $refSTR, $refConfig) = @_;
  # Hide Progress controls in main window
  $$refWin->lblPbCurr->Text('');
  $$refWin->pb->SetPos(0);
  $$refWin->lblPbCount->Text('');
  $$refWin->lblPbCurr->Hide();
  $$refWin->pb->Hide();
  $$refWin->lblPbCount->Hide();
  my %extractParams;
	# Get input
	$extractParams{input} = $$refWin->tfInput->Text();
	if ($$refWin->rbInputClipboard->Checked()) { $extractParams{inputType} = 'Clipboard'; }
	else {
		if ($$refWin->rbInputDir->Checked()) {
			$extractParams{inputType}  = 'Dir';
			$extractParams{recurseDir} = 1 if $$refWin->chInputDirRecurse->Checked();
			# Get Filters
			$extractParams{filters} = &getFilters($refWinFileFormats, $refWinFileFilters, $refWin, $refSTR) if $$refWinFileFilters;
		} elsif ($$refWin->rbInputFiles->Checked()) { $extractParams{inputType} = 'Files'; }
	}
	# Get file formats
	&getFileFormats(\%extractParams, $refWinFileFormats, $refWin, $refSTR) if $refWinFileFormats;
  $extractParams{reportDir} = $reportDir;
	# Get selected objects and options
	my $refSO = &getSO(\%extractParams, $refWin);
	$extractParams{TLD_DB_FILE}      = $$refConfig{'TLD_DB_FILE'};
	$extractParams{RES_TLD_DB_FILE}  = $$refConfig{'RES_TLD_DB_FILE'};
	$extractParams{XLWHOIS_DB_FILE}  = $$refConfig{'XLWHOIS_DB_FILE'};
	$extractParams{GEOIP_DB_FILE} 	 = $$refConfig{'GEOIP_DB_FILE'};
	$extractParams{MACOUI_DB_FILE} 	 = $$refConfig{'MACOUI_DB_FILE'};
	$extractParams{IIN_DB_FILE}   	 = $$refConfig{'IIN_DB_FILE'};
	$extractParams{NSLOOKUP_TIMEOUT} = $$refConfig{'NSLOOKUP_TIMEOUT'};
  # Save extract params and options as JSON
  my $procID   = time;
	my $jsonObj  = JSON->new;
	my $jsonText = $jsonObj->encode(\%extractParams);
  if (open(my $json, '>:encoding(cp1252)', "$reportDir\\ExtractSOParams-" . $procID .'.json')) {
    print $json $jsonText;
    close($json);
  }
  # Start Query Database Process
  my $command = 'XL-Parser-process ' . "Extract-SO $procID \"$PROGDIR\" \"$reportDir\" \"$USERDIR\"";
  Win32::Process::Create(my $processObj, $PROGDIR .'\XL-Parser-process.exe', $command, 0, NORMAL_PRIORITY_CLASS, $PROGDIR);
	$$refWin->btnExtractRefresh->Enable();
  $$refWin->Enable();
  $$refWin->BringWindowToTop();

}  #--- End extractSOFiles

#--------------------------#
sub getSO
#--------------------------#
{
  # Gather selected special objects and options
	my ($refExtractParams, $refWin) = @_;
  my $nextNode;
  my $firstNode = $$refWin->tvSO->GetRoot();
  if ($firstNode) {
		&getSONode($refWin, $refExtractParams, $firstNode) if $$refWin->tvSO->ItemCheck($firstNode);
    $nextNode = $firstNode;
    while ($nextNode = $$refWin->tvSO->GetNextSibling($nextNode)) {
			&getSONode($refWin, $refExtractParams, $nextNode) if $$refWin->tvSO->ItemCheck($nextNode);
    }
  }
  
}  #--- End getSO

#--------------------------#
sub getSONode
#--------------------------#
{
	# Local variables
	my ($refWin, $refExtractParams, $node) = @_;
	# First level
	my %item     = $$refWin->tvSO->GetItem($node);
	my $nodeStr  = $item{'-text'};
	$$refExtractParams{SO}{$nodeStr}{options} = {};
	$$refExtractParams{SO}{$nodeStr}{nbrRes}  = 0;
	my $nextNode;
	# Second level
	if ($nextNode = $$refWin->tvSO->GetChild($node)) {
		if ($$refWin->tvSO->ItemCheck($nextNode)) {
			my %currNode = $$refWin->tvSO->GetItem($nextNode);
			$$refExtractParams{SO}{$nodeStr}{options}{$currNode{'-text'}} = 1;
		}
		while ($nextNode = $$refWin->tvSO->GetNextSibling($nextNode)) {
			if ($$refWin->tvSO->ItemCheck($nextNode)) {
				my %currNode = $$refWin->tvSO->GetItem($nextNode);
				$$refExtractParams{SO}{$nodeStr}{options}{$currNode{'-text'}} = 1;
			}
			# Third level
			if (my $nextNodeChild = $$refWin->tvSO->GetChild($nextNode)) {
				if ($$refWin->tvSO->ItemCheck($nextNodeChild)) {
					my %currNode = $$refWin->tvSO->GetItem($nextNodeChild);
					$$refExtractParams{SO}{$nodeStr}{options}{$currNode{'-text'}} = 1;
				}
			}
		}
	}	
	
}  #--- End getSONode

#--------------------------#
sub getListFiles
#--------------------------#
{
  # Local variables
  my ($refListFiles, $refWinFileFormats, $refWinFileFilters, $refWin, $refSTR) = @_;
  my $dir = $$refWin->tfInput->Text();
  # List of files (No filter)
  if (!-d $dir) {
    my $filesStr = $dir;
    # Multiple files
    if ($filesStr =~ /" "/) {
      my @items = split(/" "/, $filesStr);
      my $baseDir = shift(@items);
      $baseDir =~ s/^\"//;
      foreach my $item (@items) {
        $item =~ s/\"$//;
        $$refListFiles{$baseDir."\\".$item} = 1;
      }
    # Single file
    } else { $$refListFiles{$filesStr} = 1; }
  # Directory (List files and apply filters)
  } else {
    # Local variables
    my $filter;
    my $selSize;
    my $sizeOp;
    my $regex;
    my $selDateUT;
    my $dateOp;
    my @subFolders;
    my $nbrSubFolders = 1; # The base dir count as one
    my $count         = 0;
		my $countFiles    = 0;
    # Get Filters
    my $refFilters;
    $refFilters = &getFilters($refWinFileFormats, $refWinFileFilters, $refWin, $refSTR) if $$refWinFileFilters;
    my $nbrFilters = keys %{$refFilters};
    # Open base directory
    $$refWin->lblPbCurr->Text("[$count/$nbrSubFolders] $$refSTR{'ListingFile'}: $dir");
    if (opendir(DIR,"$dir\\")) {
      while (my $file = readdir(DIR)) {
        my $filePath = "$dir\\$file";
        if ((-d $filePath) and ($file !~ /^\.\.?$/) and ($file ne 'System Volume Information')) { # It's a directory
          if ($$refWin->chInputDirRecurse->Checked()) { # Subfolders option
            push(@subFolders, $filePath);
            $nbrSubFolders++;
						$$refWin->lblPbCurr->Text("[$count/$nbrSubFolders] $$refSTR{'ListingFile'}: $dir");
          } else { $nbrSubFolders++; }
        } elsif (!-d $filePath and (!$nbrFilters or &testFilters($dir, $refFilters, $nbrFilters, $file, $filePath, $refSTR))) { # It's a file
          $$refListFiles{$filePath} = 0; # Filter match
					$countFiles++;
					$$refWin->lblPbCount->Text($countFiles);
        }
      }
      closedir(DIR);
    }
    $count++;
    $$refWin->lblPbCount->Text("$count/$nbrSubFolders");
    # List folders and files in subfolders
    if ($$refWin->chInputDirRecurse->Checked() and scalar(@subFolders) > 0) {
      foreach my $subFolder (@subFolders) {
        $$refWin->lblPbCurr->Text("[$count/$nbrSubFolders] $$refSTR{'ListingFile'}: $dir");
        if (opendir(DIR,"$subFolder\\")) {
          while (my $file = readdir(DIR)) {
            my $filePath = "$subFolder\\$file";
            if ((-d $filePath) and ($file !~ /^\.\.?$/)) { # It's a directory
              push(@subFolders, $filePath);
              $nbrSubFolders++;
							$$refWin->lblPbCurr->Text("[$count/$nbrSubFolders] $$refSTR{'ListingFile'}: $dir");
            } elsif (!-d $filePath and (!$nbrFilters or &testFilters($dir, $refFilters, $nbrFilters, $file, $filePath, $refSTR))) { # It's a file
              $$refListFiles{$filePath} = 0; # Filter match
							$countFiles++;
							$$refWin->lblPbCount->Text($countFiles);
            }
          }
          closedir(DIR);
        }
        $count++;
				$$refWin->lblPbCurr->Text("[$count/$nbrSubFolders] $$refSTR{'ListingFile'}: $dir");
      }
    }
    $$refWin->lblPbCurr->Text('');
    $$refWin->lblPbCount->Text('');
  }

}  #--- End getListFiles

#--------------------------#
sub getFilters
#--------------------------#
{
  # Local variables
  my ($refWinFileFormats, $refWinFileFilters, $refWin, $refSTR) = @_;
  my %filters;
  my $i = 1;
  # Gather filter list
  for (my $row = 1; $row < $$refWinFileFilters->gridFileFilters->GetRows(); $row++) {
    my $firstVal = $$refWinFileFilters->gridFileFilters->GetCellText($row, 0);
    if ($firstVal) {
      $filters{$i}{Operator}  = $$refWinFileFilters->gridFileFilters->GetCellText($row, 0);
      $filters{$i}{Type}      = $$refWinFileFilters->gridFileFilters->GetCellText($row, 1) if $$refWinFileFilters->gridFileFilters->GetCellText($row, 1);
      $filters{$i}{TypeOp}    = $$refWinFileFilters->gridFileFilters->GetCellText($row, 2) if $$refWinFileFilters->gridFileFilters->GetCellText($row, 2);
      $filters{$i}{Flags}     = $$refWinFileFilters->gridFileFilters->GetCellText($row, 3) if $$refWinFileFilters->gridFileFilters->GetCellText($row, 3);
      $filters{$i}{SearchStr} = $$refWinFileFilters->gridFileFilters->GetCellText($row, 4) if $$refWinFileFilters->gridFileFilters->GetCellText($row, 4);
      if ($filters{$i}{Type} eq $$refSTR{'rbFiltersLastAccess'} or $filters{$i}{Type} eq $$refSTR{'rbFiltersLastModif'}) {
        my ($y, $m, $d) = split(/\-/, $filters{$i}{SearchStr});
        $filters{$i}{'DateUT'} = timelocal(0,0,0,$d,$m-1,$y); # Store in Unixtime format
      }
    }
    $i++;
  }
  # Add file formats list (filter by extension)
	if ($$refWinFileFormats) {
		my @listFormats;
		my @listExt;
		for (my $row = 1; $row < $$refWinFileFormats->gridFileFormats->GetRows(); $row++) {
			if ($$refWinFileFormats->gridFileFormats->GetCellCheck($row, 0)) {
				push(@listFormats, $$refWinFileFormats->gridFileFormats->GetCellText($row, 1));
				my $searchStr = $$refWinFileFormats->gridFileFormats->GetCellText($row, 2);
				$searchStr =~ s/^\./\\./g; # Quote starting dot
				$searchStr =~ s/\*/\.\*/g; # Replace wildcards
				push(@listExt, $searchStr);
			}
		}
		if (scalar(@listFormats) and scalar(@listExt)) {
			if ($i) { $filters{$i}{Operator} = $$refSTR{'AND'}; }
			else    { $filters{$i}{Operator} = '-';             }
			$filters{$i}{Operator} = $$refSTR{'AND'};
			$filters{$i}{Type}     = $$refSTR{'FileFormats'};
			foreach (@listFormats) { $filters{$i}{TypeOp} .= $_.','; }
			chop($filters{$i}{TypeOp});
			$filters{$i}{SearchStr} .= '(?:';
			foreach (@listExt)     { $filters{$i}{SearchStr} .= $_.'|'; }
			chop($filters{$i}{SearchStr});
			$filters{$i}{SearchStr} .= ')$';
		}
	}
  return(\%filters);  
  
}  #--- End getFilters

#--------------------------#
sub getFileFormats
#--------------------------#
{
  # Local variables
  my ($refExtractParams, $refWinFileFormats, $refWin, $refSTR) = @_;
  my $i = 1;
  # Gather File formats
  for (my $row = 1; $row <= $$refWinFileFormats->gridFileFormats->GetRows(); $row++) {
    if ($$refWinFileFormats->gridFileFormats->GetCellCheck($row, 0)) {
      my $format     = $$refWinFileFormats->gridFileFormats->GetCellText($row, 1);
      my $extensions = $$refWinFileFormats->gridFileFormats->GetCellText($row, 2);
      my @extList    = split(/ *, */, $extensions);
      my $options;
      if ($format eq $$refSTR{'Unicode'}) { $options = $$refWinFileFormats->gridFileFormats->GetCellText($row, 3); }
      elsif ($format eq 'Doc' or $format eq 'Docx') {
        if ($$refWinFileFormats->gridFileFormats->GetCellCheck($row, 3)) { $options = 'MSWORD=1'; }
        else                                                             { $options = 'MSWORD=0'; }
      }
      $$refExtractParams{fileFormats}{$format}{extList} = \@extList;
      $$refExtractParams{fileFormats}{$format}{options} = $options if $options;
      $i++;
    }
  }
  
}  #--- End getFileFormats

#--------------------------#
sub selFileFormats
#--------------------------#
{
  # Local variables
  my ($refListExt, $refWinFileFormats, $refSTR) = @_;
  # Select File formats based on extension
  foreach my $ext (@{$refListExt}) {
    for (my $row = 1; $row <= $$refWinFileFormats->gridFileFormats->GetRows(); $row++) {
      my $extensions = $$refWinFileFormats->gridFileFormats->GetCellText($row, 2);
      $$refWinFileFormats->gridFileFormats->SetCellCheck($row, 0, 1) if $extensions =~ /\.$ext(?:,|$)/;
    }
  }
  
}  #--- End selFileFormats

#--------------------------#
sub testFilters
#--------------------------#
{
  # Local variables
  my ($dir, $refFilters, $nbrFilters, $file, $path, $refSTR) = @_;
  my $match       = 0;
  # Path is a folder, only Contains filter applies
  if ($path and -d $path) {
    for (my $i = 1; $i <= $nbrFilters; $i++) {
      if ($$refFilters{$i}{Type} eq $$refSTR{'Contains'}) {
        # Regex option is checked
        my $expr;
        my ($case, $regex, $fileOnly) = split(/\-/, $$refFilters{$i}{Flags});
        if (!$regex) { $expr = quotemeta($$refFilters{$i}{SearchStr}); }
        else         { $expr = $$refFilters{$i}{SearchStr};            }
        if (!$fileOnly and
            ((!$case and $path =~ /$expr/i) or
             ($case and $path =~ /$expr/))) {
          # Match and next operator is OR
          if (exists($$refFilters{$i+1}{Operator}) and $$refFilters{$i+1}{Operator} eq $$refSTR{'OR'}) { return(1); }
          else { $match = 1; }
        # Don't match and operator is AND
        } elsif (exists($$refFilters{$i+1}{Operator}) and $$refFilters{$i+1}{Operator} eq $$refSTR{'AND'}) { return(0); }
      # Filter size, Last accessed, Last modified, File Formats apply to files only
      } elsif (($$refFilters{$i}{Type} eq $$refSTR{'rbFiltersSize'}       or
                $$refFilters{$i}{Type} eq $$refSTR{'rbFiltersLastAccess'} or
                $$refFilters{$i}{Type} eq $$refSTR{'rbFiltersLastModif'}  or
                $$refFilters{$i}{Type} eq $$refSTR{'FileFormats'})        and
               ((exists($$refFilters{$i+1}{Operator}) and $$refFilters{$i+1}{Operator} eq $$refSTR{'AND'}) or
                ($$refFilters{$i}{Operator} ne $$refSTR{'OR'}))) {
        return(0);
      }
    }
  # It's a file
  } else {
    for (my $i = 1; $i <= $nbrFilters; $i++) {
      my $matchTmp = 0;
      # Contains filter
      if      ($$refFilters{$i}{Type} eq $$refSTR{'Contains'}) {
        my $expr;
        my ($case, $regex, $fileOnly) = split(/\-/, $$refFilters{$i}{Flags});
        if (!$regex) { $expr = quotemeta($$refFilters{$i}{SearchStr}); }
        else         { $expr = $$refFilters{$i}{SearchStr};            }
        my $relPath = $path =~ s/\Q$dir\E\\//r;
        $relPath    = $file if $fileOnly;
        if ((!$case and $relPath =~ /$expr/i) or ($case and $relPath =~ /$expr/)) { $matchTmp = 1; }
				else { $matchTmp = 0; }
      # File size filter
      } elsif ($$refFilters{$i}{Type} eq $$refSTR{'rbFiltersSize'}) {
        if (&cmpFileSize($path, $$refFilters{$i}{SearchStr}, $$refFilters{$i}{TypeOp})) {
          $matchTmp = 1;
        } else { $matchTmp = 0; }
      # Filter: Last accessed or Last modified
      } elsif ($$refFilters{$i}{Type} eq $$refSTR{'rbFiltersLastAccess'} or $$refFilters{$i}{Type} eq $$refSTR{'rbFiltersLastModif'}) {
        my $cmpDateUT;
        if ($$refFilters{$i}{Type} eq $$refSTR{'rbFiltersLastAccess'}) { $cmpDateUT = (stat($path))[8]; }
        else                                                           { $cmpDateUT = (stat($path))[9]; }
        if (&cmpDates($path, $$refFilters{$i}{DateUT}, $cmpDateUT, $$refFilters{$i}{TypeOp})) {
          $matchTmp = 1;
        } else { $matchTmp = 0; }
      # File format filter
      } elsif ($$refFilters{$i}{Type} eq $$refSTR{'FileFormats'}) {
        if ($path =~ /$$refFilters{$i}{SearchStr}/i or ($$refFilters{$i}{TypeOp} eq $$refSTR{'PlainText'} and -T $path)) {
          $matchTmp = 1;
        } else { $matchTmp = 0; }
      }
      # Match
      if ($matchTmp and exists($$refFilters{$i+1}{Operator})) {
        # Next operator is OR
        if ($$refFilters{$i+1}{Operator} eq $$refSTR{'OR'}) { return(1);  } # No need to check other filter
        else { $match = 1; }
      # Don't match
      } elsif (!$matchTmp) {
        # Next or actual operator is AND
        if ((exists($$refFilters{$i+1}{Operator}) and
             ($$refFilters{$i+1}{Operator} eq $$refSTR{'AND'}) or
              ($$refFilters{$i}{Operator} eq $$refSTR{'AND'}))) { return(0); } # No need to check other filter
        else { $match = 0; }
      } else { $match = $matchTmp; }
    }
  }
  return(1) if $match;
  return(0);

}  #--- End testFilters

#--------------------------#
sub splitLogs
#--------------------------#
{
  # Local variables
  my ($refWinFileFormats, $refWinFileFilters, $refZONE_MAP, $refWin, $refSTR) = @_;
  my $splitBySize  = 1 if $$refWin->rbSplitBySize->Checked();
  my $splitByLines = 1 if $$refWin->rbSplitByLines->Checked();
  my $destFolder   = $$refWin->tfSplitDestDir->Text();
  # List of files
  my %listFiles;
  if ($$refWin->rbInputDir->Checked() or $$refWin->rbInputFiles->Checked()) {
    &getListFiles(\%listFiles, $refWinFileFormats, $refWinFileFilters, $refWin, $refSTR);
  }
	my $nbrFiles = scalar(keys %listFiles);
	if ($nbrFiles) {
		# Set progress
		$$refWin->pb->SetRange(0, $nbrFiles);
		$$refWin->pb->SetPos(0);
		$$refWin->pb->SetStep(1);
		$$refWin->lblPbCount->Text("0 / $nbrFiles");
		$$refWin->lblPbCurr->Text("$$refSTR{'Splitting'} $$refSTR{'Started'}");
		my $count = 0;
		# Split by size
		if ($splitBySize) {
			my $sizeFrag = $$refWin->tfSplitBySizeFrag->Text;
			my $sizeUnit = $$refWin->cbSplitBySizeUnit->GetCurSel();
			# Possible values are: 0 = Kbytes, 1 = Mbytes, 2 = Gbytes
			# Fragment size in bytes
			if    (!$sizeUnit    ) { $sizeFrag = $sizeFrag * 1024; }               # Kbytes
			elsif ($sizeUnit == 1) { $sizeFrag = $sizeFrag * 1024 * 1024; }        # Mbytes
			elsif ($sizeUnit == 2) { $sizeFrag = $sizeFrag * 1024 * 1024 * 1024; } # GBytes
			# Use datetime in filename
			if ($$refWin->chSplitUseDTFN->Checked()) {
				my ($format, $sample, $pattern, $regex, $timezone);
				$format = $$refWin->cbSplitTimeFormat->GetString($$refWin->cbSplitTimeFormat->GetCurSel());
				($sample, $pattern, $regex, $timezone) = &findInputDTFormat($format) if $format ne $$refSTR{'selectDTFormat'};
				if ($pattern and $regex) {
					# Foreach file
					foreach my $file (sort { $a cmp $b } keys %listFiles) {
						if ((stat($file))[7] > $sizeFrag) { # Split file if bigger than fragment size
							$$refWin->lblPbCurr->Text("$$refSTR{'Splitting'} $file".'...');
							my $totalLength = 0;
							# Read the file to split
							if (open(my $fh, $file)) {
								my $dstFh;
								my $buffer;
								while (<$fh>) {
									# Create a new destination file (Not already opened, or fragment size reached)
									if ((!$dstFh or ($dstFh and $totalLength >= $sizeFrag))) {
										if (/($regex)/) {
											close($dstFh) if $dstFh;
											my $extract = $1;
											my $strp    = DateTime::Format::Strptime->new(pattern => $pattern, zone_map => $refZONE_MAP);
											my $datetimeStr;
											my $dstFile;
											if (my $dt = $strp->parse_datetime($extract)) {
												$dstFile = "$destFolder\\".$dt->strftime("%Y%m%d_%H%M%S").'.txt';
												open($dstFh,">$dstFile");
												flock($dstFh, 2);
												$totalLength = 0;
												if ($buffer) {
													print $dstFh $buffer;
													$totalLength += length($buffer);
												}
											} else { # Datetime couldn't be parsed, error
												close($fh);
												# Add error message
												last;
											}
										} else { # Line doesn't contain matching datetime pattern
											$buffer .= $_;
											$totalLength += length($_);
										}
									}
									if ($dstFh) {
										print $dstFh $_;
										$totalLength += length($_);
									}
								}
								close($dstFh);
								close($fh);
							}
						}
						$count++;
						$$refWin->lblPbCount->Text("$count / $nbrFiles");
						$$refWin->pb->StepIt();
					}
				}
			# Use incremental number in filename
			} else {
				# Foreach file
				foreach my $file (sort { $a cmp $b } keys %listFiles) {
					if ((stat($file))[7] > $sizeFrag) { # Split file if bigger than fragment size
						$$refWin->lblPbCurr->Text("$$refSTR{'Splitting'} $file".'...');
						# Set destination file path
						my @pathParts   = split(/\\/, $file);
						my $filename    = pop(@pathParts);
						my @fileParts   = split(/\./, $filename);
						my $extension   = pop(@fileParts);
						if (scalar(@fileParts)) { $filename  = join('.', @fileParts); } # Filename have extension
						else                    { $extension = undef; }
						my $totalLength = 0;
						# First fragment filename
						my $i = 1;
						my $dstFile = "$destFolder\\$filename"."_$i";
						$dstFile   .= '.' . $extension if $extension;
						# Read the file to split
						if (open(my $fh, $file) and open(my $dstFh,">$dstFile")) {
							flock($dstFh, 2);
							while (<$fh>) {
								# If fragment size has been reached, we start a new file
								if ($totalLength >= $sizeFrag) {
									close($dstFh);
									$i++;
									$dstFile  = "$destFolder\\$filename"."_$i";
									$dstFile .= '.' . $extension if $extension;
									open($dstFh,">$dstFile");
									flock($dstFh, 2);
									$totalLength = 0;
								}
								print $dstFh $_;
								$totalLength += length($_);
							}
							close($dstFh);
							close($fh);
						}
					}
					$count++;
					$$refWin->lblPbCount->Text("$count / $nbrFiles");
					$$refWin->pb->StepIt();
				}
			}
		# Split by lines
		} elsif ($splitByLines) {
			my $nbrLines = $$refWin->tfSplitByLinesNbr->Text;
			# Use datetime in filename
			if ($$refWin->chSplitUseDTFN->Checked()) {
				my ($format, $sample, $pattern, $regex, $timezone);
				$format = $$refWin->cbSplitTimeFormat->GetString($$refWin->cbSplitTimeFormat->GetCurSel());
				($sample, $pattern, $regex, $timezone) = &findInputDTFormat($format) if $format ne $$refSTR{'selectDTFormat'};
				if ($pattern and $regex) {
					# Foreach file
					foreach my $file (sort { $a cmp $b } keys %listFiles) {
						my $nbrLinesFile;
						# Calculate number of lines for file
						if (open my $fh, '<', $file) {
							while (sysread $fh, my $buffer, 4096) { $nbrLinesFile += ($buffer =~ tr/\n//); }
							close($fh);
						}
						if ($nbrLinesFile > $nbrLines) { # Split file if number of lines is higher than the number provided
							$$refWin->lblPbCurr->Text($$refSTR{'Splitting'}.' '.$file.'...');
							# Set destination file path
							my @pathParts = split(/\\/, $file);
							my $filename  = pop(@pathParts);
							my @fileParts = split(/\./, $filename);
							my $extension = pop(@fileParts);
							if (scalar(@fileParts)) { $filename  = join('.', @fileParts); } # Filename have extension
							else                    { $extension = undef; }
							my $countLines = 0;
							# First fragment filename
							my $i = 1;
							my $dstFile = "$destFolder\\$filename"."_$i";
							$dstFile .= '.' . $extension if $extension;
							# Read the file to split
							if (open(my $fh, $file)) {
								my $dstFh;
								my $buffer;
								while (<$fh>) {
									# If number of lines has been reached, we start a new file
									if (!$dstFh or $countLines >= $nbrLines) {
										if (/($regex)/) {
											close($dstFh) if $dstFh;
											my $extract = $1;
											my $strp    = DateTime::Format::Strptime->new(pattern => $pattern, zone_map => $refZONE_MAP);
											my $datetimeStr;
											my $dstFile;
											if (my $dt = $strp->parse_datetime($extract)) {
												$dstFile = "$destFolder\\".$dt->strftime("%Y%m%d_%H%M%S").'.txt';
												open($dstFh,">$dstFile");
												flock($dstFh, 2);
												$countLines = 0;
												if ($buffer) {
													print $dstFh $buffer;
													$countLines += ($buffer =~ tr/\n/\n/);
												}
											} else { # Datetime couldn't be parsed, error
												close($fh);
												# Add error message
												last;
											}
										} else { $buffer .= $_; } # Line doesn't contain matching datetime pattern
									}
									print $dstFh $_ if $dstFh;
									$countLines++;
								}
								close($dstFh);
								close($fh);
							}
						}
						$count++;
						$$refWin->lblPbCount->Text("$count / $nbrFiles");
						$$refWin->pb->StepIt();
					}
				}
			# Use incremental number in filename
			} else {
				# Foreach file
				foreach my $file (sort { $a cmp $b } keys %listFiles) {
					my $nbrLinesFile;
					# Calculate number of lines for file
					if (open my $fh, '<', $file) {
						while (sysread $fh, my $buffer, 4096) { $nbrLinesFile += ($buffer =~ tr/\n//); }
						close($fh);
					}
					if ($nbrLinesFile > $nbrLines) { # Split file if number of lines is higher than the number provided
						$$refWin->lblPbCurr->Text($$refSTR{'Splitting'}.' '.$file.'...');
						# Set destination file path
						my @pathParts = split(/\\/, $file);
						my $filename  = pop(@pathParts);
						my @fileParts = split(/\./, $filename);
						my $extension = pop(@fileParts);
						if (scalar(@fileParts)) { $filename  = join('.', @fileParts); } # Filename have extension
						else                    { $extension = undef; }
						my $countLines = 0;
						# First fragment filename
						my $i = 1;
						my $dstFile = "$destFolder\\$filename"."_$i";
						$dstFile   .= '.' . $extension if $extension;
						# Read the file to split
						if (open(my $fh, $file) and open(my $dstFh,">$dstFile")) {
							flock($dstFh, 2);
							while (<$fh>) {
								# If number of lines has been reached, we start a new file
								if ($countLines >= $nbrLines) {
									close($dstFh);
									$i++;
									$dstFile  = "$destFolder\\$filename"."_$i";
									$dstFile .= '.' . $extension if $extension;
									open($dstFh,">$dstFile");
									flock($dstFh, 2);
									$countLines = 0;
								}
								print $dstFh $_;
								$countLines++;
							}
							close($dstFh);
							close($fh);
						}
					}
					$count++;
					$$refWin->lblPbCount->Text("$count / $nbrFiles");
					$$refWin->pb->StepIt();
				}
			}
		# Split by date and time
		} else {
			my $inter  = $$refWin->cbSplitByTimeInter->GetCurSel();
			# Possible values are: 0 = By hour, 1 = By day, 2 = By week, 3 = By month
			my $format = $$refWin->cbSplitTimeFormat->GetString($$refWin->cbSplitTimeFormat->GetCurSel());
			my ($sample, $pattern, $regex, $timezone) = &findInputDTFormat($format) if $format ne $$refSTR{'selectDTFormat'};
			# Foreach file
			if ($pattern and $regex) {
				my $dstFh;
				my $interVal;
				foreach my $file (sort { $a cmp $b } keys %listFiles) {
					$$refWin->lblPbCurr->Text("$$refSTR{'Splitting'} $file".'...');
					# Read the file to split
					if (open(my $fh, $file)) {
						my $i = 0;
						while (<$fh>) {
							$i++;
							# Extract the date and time
							if (/($regex)/) {
								my $extract = $1;
								my $strp    = DateTime::Format::Strptime->new(pattern => $pattern, zone_map => $refZONE_MAP);
								if (my $dt = $strp->parse_datetime($extract)) {
									my $currInterVal;
									if    (!$inter    ) { $currInterVal = $dt->ymd('').'-'.sprintf("%02d", $dt->hour()).'0000';   } # By hour
									elsif ($inter == 1) { $currInterVal = $dt->ymd('');                                           } # By day
									elsif ($inter == 2) { # By week
										my ($year, $number) = $dt->week;
										$currInterVal = $year.'_week_'.sprintf("%02d", $number);
									} 
									elsif ($inter == 3) { $currInterVal = $dt->year().sprintf("%02d", $dt->month()); } # By month
									# Create a new file
									if (!$interVal or $currInterVal ne $interVal) {
										close($dstFh) if $dstFh;
										$interVal = $currInterVal;
										my $dstFile = "$destFolder\\$interVal".'.txt';
										open($dstFh,">>$dstFile");
										flock($dstFh, 2);
									}
									print $dstFh $_;
								} else { # Datetime couldn't be parsed, error
									close($fh);
									# Add error message
									last;
								}
							} elsif ($dstFh) { print $dstFh $_; }
						}
						close($fh);
					}
					$count++;
					$$refWin->lblPbCount->Text("$count / $nbrFiles");
					$$refWin->pb->StepIt();
				}
				close($dstFh) if $dstFh;
			}
		}
		# Open folder in Window Explorer
		if ($$refWin->chOpenSplitDestDir->Checked()) {
			Win32::Process::Create(my $ProcessObj, "$ENV{'WINDIR'}\\explorer.exe", "explorer $destFolder", 0, NORMAL_PRIORITY_CLASS, ".");
		}
	} else { Win32::GUI::MessageBox($$refWin, $$refSTR{'noFile'}, $$refSTR{'error'}, 0x40010); } # No files
  
}  #--- End splitLogs

#--------------------------#
sub loadFileFormatsGrid
#--------------------------#
{
  # Local variables
  my ($jsonFile, $refWinFileFormats, $refSTR) = @_;
  # Grid header
	$$refWinFileFormats->gridFileFormats->SetCellText(0, 1, $$refSTR{'Format'}       );
	$$refWinFileFormats->gridFileFormats->SetCellText(0, 2, $$refSTR{'FileExtension'});
	$$refWinFileFormats->gridFileFormats->SetCellText(0, 3, $$refSTR{'Options'}      );
	$$refWinFileFormats->gridFileFormats->SetCellFormat(0, 1, 1); # Center column headers
	$$refWinFileFormats->gridFileFormats->SetCellFormat(0, 2, 1);
	$$refWinFileFormats->gridFileFormats->SetCellFormat(0, 3, 1);
  # Insert file formats in grid
  $$refWinFileFormats->gridFileFormats->SetRows(13);
  my $refFileFormats = &loadFileFormats($jsonFile, $refSTR);
  foreach my $index (sort { $a <=> $b } keys %{$refFileFormats}) {
		$$refWinFileFormats->gridFileFormats->SetCellType(      $index, 0, 4);
		$$refWinFileFormats->gridFileFormats->SetCellText(      $index, 1, $$refFileFormats{$index}{name});
		$$refWinFileFormats->gridFileFormats->SetCellEditable($index, 1, 0);
		$$refWinFileFormats->gridFileFormats->SetCellText(      $index, 2, $$refFileFormats{$index}{extList});
		if ($$refFileFormats{$index}{name} eq 'Doc' or $$refFileFormats{$index}{name} eq 'Docx') { # Doc or Docx checkbox option
			$$refWinFileFormats->gridFileFormats->SetCellType(    $index, 3, 4);
			$$refWinFileFormats->gridFileFormats->SetCellText(    $index, 3, $$refSTR{'chFiltersUseMSWord'});
			$$refWinFileFormats->gridFileFormats->SetCellCheck(   $index, 3, 1) if $$refFileFormats{$index}{options};
		} elsif ($$refFileFormats{$index}{name} eq $$refSTR{'Unicode'}) { # Unicode combo options
			$$refWinFileFormats->gridFileFormats->SetCellType(    $index, 3, 5);
			$$refWinFileFormats->gridFileFormats->SetCellOptions( $index, 3, ['HTML', $$refSTR{'Other'}]);
			if ($$refFileFormats{$index}{options}) {
				$$refWinFileFormats->gridFileFormats->SetCellText(  $index, 3, $$refFileFormats{$index}{options});
			} else { $$refWinFileFormats->gridFileFormats->SetCellText($index, 3, $$refSTR{'Other'}); }
		} else { $$refWinFileFormats->gridFileFormats->SetCellEditable($index, 3, 0); } # No options for this format
  }
	$$refWinFileFormats->gridFileFormats->SetCellCheck(1, 0, 1); # Plain text is selected by default
	$$refWinFileFormats->gridFileFormats->AutoSize();
	$$refWinFileFormats->gridFileFormats->ExpandLastColumn();
  
}  #--- End loadFileFormatsGrid

#--------------------------#
sub loadFileFormats
#--------------------------#
{
  # Local variables
  my ($jsonFile, $refSTR) = @_;
  my %fileFormats;
  my $refFileFormats = \%fileFormats;
  # If file already exists, load values
  if (-f $jsonFile and open(my $json, $jsonFile)) {
    my $jsonText = <$json>;
    close($json);
    my $jsonObj = JSON->new;
    $refFileFormats = $jsonObj->decode($jsonText);
  # File don't exist, set default values
  } else {
    # Plain text
    $$refFileFormats{1}{name}     = $$refSTR{'PlainText'};
    $$refFileFormats{1}{extList}  = '.*';
    # Unicode
    $$refFileFormats{2}{name}     = $$refSTR{'Unicode'};
    $$refFileFormats{2}{extList}  = '.rtf';
    # Any ASCII
    $$refFileFormats{3}{name}     = $$refSTR{'AnyASCII'};
    $$refFileFormats{3}{extList}  = '.*';
    # Doc
    $$refFileFormats{4}{name}     = 'Doc';
    $$refFileFormats{4}{extList}  = '.doc';
    # Docx
    $$refFileFormats{5}{name}     = 'Docx';
    $$refFileFormats{5}{extList}  = '.docx';
    # Xls
    $$refFileFormats{6}{name}     = 'Xls';
    $$refFileFormats{6}{extList}  = '.xls';
    # Xlsx
    $$refFileFormats{7}{name}     = 'Xlsx';
    $$refFileFormats{7}{extList}  = '.xlsx';
    # Evt
    $$refFileFormats{8}{name}     = 'Evt';
    $$refFileFormats{8}{extList}  = '.evt';
    # Evtx
    $$refFileFormats{9}{name}     = 'Evtx';
    $$refFileFormats{9}{extList}  = '.evtx';
    # Pdf
    $$refFileFormats{10}{name}    = 'Pdf';
    $$refFileFormats{10}{extList} = '.pdf';
    # Msg
    $$refFileFormats{11}{name}    = 'Msg';
    $$refFileFormats{11}{extList} = '.msg';
    # Zip
    $$refFileFormats{12}{name}    = 'Zip';
    $$refFileFormats{12}{extList} = '.zip';
  }
  return($refFileFormats);
  
}  #--- End loadFileFormats

#------------------------------------------------------------------------------#
1;