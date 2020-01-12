#!/usr/bin/perl
# Perl - v: 5.16.3
#------------------------------------------------------------------------------#
# XL-ParserConfig.pl	: Configuration functions for XL-Parser
# Website     				: http://le-tools.com/XL-Parser.html
# SourceForge					: https://sourceforge.net/p/xl-parser
# GitHub							: https://github.com/arioux/XL-Parser
# Creation						: 2016-07-15
# Modified						: 2020-01-12
# Author							: Alain Rioux (admin@le-tools.com)
#
# Copyright (C) 2016-2020 Alain Rioux (le-tools.com)
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
use GeoIP2::Database::Reader;
use Archive::Tar;
use IO::Uncompress::Unzip qw(unzip $UnzipError);
use Domain::PublicSuffix;

#------------------------------------------------------------------------------#
# Global variables
#------------------------------------------------------------------------------#
my $URL_TOOL        = 'http://le-tools.com/XL-Parser.html#Download';           # Url of the tool
my $URL_VER         = 'http://www.le-tools.com/download/XL-ParserVer.txt';     # Url of the version file
my $MACOUIDB_URL    = 'http://standards-oui.ieee.org/oui.txt';                 # URL of the MAC OUI DB
my $IINDB_URL       = 'http://le-tools.com/download/XL-Tools/IIN.zip';         # URL of the IINDB
my $TLDDB_URL       = 'https://publicsuffix.org/list/effective_tld_names.dat'; # URL of the TLD DB
my $RESTLDDB_URL    = 'http://le-tools.com/download/XL-Tools/Resolve TLD.zip'; # URL of the Resolve TLD DB
my $DTDB_URL        = 'http://le-tools.com/download/XL-Tools/Datetime.zip';    # URL of the DTDB
my $LFDB_URL        = 'http://le-tools.com/download/XL-Parser/LogFormats.zip'; # URL of the LFDB
my $TOTAL_SIZE:shared = 0;                                                     # Total size for download

#--------------------------#
sub saveConfig
#--------------------------#
{
  # Local variables
  my $refConfig   = shift;
  my $CONFIG_FILE = shift;
  # Save configuration hash values
  open(CONFIG,">$CONFIG_FILE");
  flock(CONFIG, 2);
  foreach my $cle (keys %{$refConfig}) { print CONFIG "$cle = $$refConfig{$cle}\n"; }
  close(CONFIG);

}  #--- End saveConfig

#--------------------------#
sub loadConfig
#--------------------------#
{
  # Local variables
  my ($CONFIG_FILE, $USERDIR, $refConfig, $refWinConfig, $refWinExtraction, $refWinDTDB, $refWinReport, $refWin) = @_;
  # Open and load config values
  open(CONFIG, $CONFIG_FILE);
  my @tab = <CONFIG>;
  close(CONFIG);
  foreach (@tab) {
    chomp($_);
    my ($key, $value) = split(/ = /, $_);
    $$refConfig{$key}  = $value if $key;
  }
  # General tab
  if (exists($$refConfig{'TOOL_AUTO_UPDATE'}))      { $$refWinConfig->chAutoUpdate->Checked($$refConfig{'TOOL_AUTO_UPDATE'});           }
  else                                              { $$refWinConfig->chAutoUpdate->Checked(1);                                         } # Default is checked
  # Function options
  if (exists($$refConfig{'FULL_SCREEN'}))           { $$refWinConfig->chFullScreen->Checked($$refConfig{'FULL_SCREEN'});                }
  else                                              { $$refWinConfig->chFullScreen->Checked(0);                                         } # Default is not checked
  if (exists($$refConfig{'REMEMBER_POS'}))          { $$refWinConfig->chRememberPos->Checked($$refConfig{'REMEMBER_POS'});              }
  else                                              { $$refWinConfig->chRememberPos->Checked(0);                                        } # Default is not checked
  if (exists($$refConfig{'GEOIP_LANG'}))						{
    my $index = $$refWinConfig->cbGeoIPLang->FindStringExact($$refConfig{'GEOIP_LANG'});
    $$refWinConfig->cbGeoIPLang->SetCurSel($index);
  } else { $$refConfig{'GEOIP_LANG'} = 'en'; }
  if (exists($$refConfig{'NSLOOKUP_TIMEOUT'}))      { $$refWinConfig->tfLookupTO->Text($$refConfig{'NSLOOKUP_TIMEOUT'});                }
  else                                              { $$refWinConfig->tfLookupTO->Text(10); $$refConfig{'NSLOOKUP_TIMEOUT'} = 10;       } # Default is 10 seconds
  if (exists($$refConfig{'LOCAL_TIMEZONE'}))        { $$refWinConfig->cbLocalTZ->SetCurSel($$refConfig{'LOCAL_TIMEZONE'}); }
  else { # Try to find local timezone, if not found, set to first visible in list
    my $index = 0;
    my $localTZ;
    eval     { $localTZ = DateTime::TimeZone->new(name => 'local'); };
    if (!$@) { $index = $$refWinConfig->cbLocalTZ->FindStringExact($localTZ->{name}); }
		else     { $index = 107; } # Default is America/New_York
    $$refWinConfig->cbLocalTZ->SetCurSel($index);
    $$refConfig{'LOCAL_TIMEZONE'} = $index;
  }
  if (exists($$refConfig{'DEFAULT_LANG'})) {
    my $index = $$refWinConfig->cbDefaultLang->FindStringExact($$refConfig{'DEFAULT_LANG'});
    $$refWinConfig->cbDefaultLang->SetCurSel($index);
  } else {
    $$refWinConfig->cbDefaultLang->SetCurSel($$refWinConfig->cbDefaultLang->FindStringExact('en-US')); # Use default
    $$refConfig{'DEFAULT_LANG'} = 'en-US';
  }
  # MACOUIDB Database location
  if (exists($$refConfig{'MACOUI_DB_AUTO_UPDATE'})) { $$refWinConfig->chMACOUIDBAutoUpt->Checked($$refConfig{'MACOUI_DB_AUTO_UPDATE'}); }
  else                                              { $$refWinConfig->chMACOUIDBAutoUpt->Checked(0);                                    } # Default is not checked
  if (exists($$refConfig{'MACOUI_DB_FILE'}) and
      -f $$refConfig{'MACOUI_DB_FILE'})             { $$refWinConfig->tfMACOUIDB->Text($$refConfig{'MACOUI_DB_FILE'});                  }
  # GeoIPDB Database location
  if (exists($$refConfig{'GEOIP_DB_FILE'}) and
      -f $$refConfig{'GEOIP_DB_FILE'})              { $$refWinConfig->tfGeoIPDB->Text($$refConfig{'GEOIP_DB_FILE'});                    }
	else {
		# Verify if database exists in a default directory
    my $defaultPath = &findXLTKfile('GeoIPDB');
    if (-f $defaultPath and &validGeoIPDB($defaultPath)) {
			$$refConfig{'GEOIP_DB_FILE'} = $defaultPath;
      $$refWinConfig->tfGeoIPDB->Text($defaultPath);
    }
	}
  # IIN Database location
  if (exists($$refConfig{'IIN_DB_FILE'}) and
      -f $$refConfig{'IIN_DB_FILE'})                { $$refWinConfig->tfIINDB->Text($$refConfig{'IIN_DB_FILE'});                        }
  # TLD Database location
  if (exists($$refConfig{'TLD_DB_FILE'}) and
      -f $$refConfig{'TLD_DB_FILE'})                { $$refWinConfig->tfTLDDB->Text($$refConfig{'TLD_DB_FILE'});                        }
  if (exists($$refConfig{'TLD_DB_AUTO_UPDATE'}))    { $$refWinConfig->chTLDDBAutoUpt->Checked($$refConfig{'TLD_DB_AUTO_UPDATE'});       }
  else                                              { $$refWinConfig->chTLDDBAutoUpt->Checked(1);                                       } # Default is checked
  # XL-Parser Databases location
  if (exists($$refConfig{'EXPR_HISTO_DB'}) and
      -f $$refConfig{'EXPR_HISTO_DB'})              { $$refWinConfig->tfExprHistoDB->Text($$refConfig{'EXPR_HISTO_DB'});                }
  if (exists($$refConfig{'EXPR_DB'}) and
      -f $$refConfig{'EXPR_DB'})                    { $$refWinConfig->tfExprDB->Text($$refConfig{'EXPR_DB'});                           }
  # Log format Database location
  if (exists($$refConfig{'LF_DB_FILE'}) and
      -f $$refConfig{'LF_DB_FILE'})                 { $$refWinConfig->tfLFDB->Text($$refConfig{'LF_DB_FILE'});                          }
  # XL-Whois Database location
  if (exists($$refConfig{'XLWHOIS_DB_FILE'}) and
      -f $$refConfig{'XLWHOIS_DB_FILE'})            { $$refWinConfig->tfXLWHOISDB->Text($$refConfig{'XLWHOIS_DB_FILE'});                }
  # Resolve TLD Database location
  if (exists($$refConfig{'RES_TLD_DB_FILE'}) and
      -f $$refConfig{'RES_TLD_DB_FILE'})            { $$refWinConfig->tfResTLDDB->Text($$refConfig{'RES_TLD_DB_FILE'});                 }
  # Datetime Database location
  if (exists($$refConfig{'DT_DB_FILE'}) and
      -f $$refConfig{'DT_DB_FILE'})                 { $$refWinConfig->tfDTDB->Text($$refConfig{'DT_DB_FILE'});                          }
  # Log Analysis Database location
  if (exists($$refConfig{'LAFILTERS_DB_FILE'}) and
      -f $$refConfig{'LAFILTERS_DB_FILE'})          { $$refWinConfig->tfLAFiltersDB->Text($$refConfig{'LAFILTERS_DB_FILE'});            }
  # Saved Queries Database location
  if (exists($$refConfig{'SAVED_QUERIES_DB_FILE'}) and
      -f $$refConfig{'SAVED_QUERIES_DB_FILE'})      { $$refWinConfig->tfSavedQueriesDB->Text($$refConfig{'SAVED_QUERIES_DB_FILE'});     }
  # Extraction window
  # Default report folder
  if (exists($$refConfig{'REPORT_DIR'}) and -d $$refConfig{'REPORT_DIR'}) { $$refWinReport->tfReportDir->Text($$refConfig{'REPORT_DIR'}); }
  else {
		mkdir("$USERDIR\\Reports") if !-d "$USERDIR\\Reports";
		$$refWinReport->tfReportDir->Text("$USERDIR\\Reports");
	} # Default dir
  if (exists($$refConfig{'REPORT_REPLACE_REPORT'})) { $$refWinReport->chReplaceReport->Checked($$refConfig{'REPORT_REPLACE_REPORT'}); }
  else                                              { $$refWinReport->chReplaceReport->Checked(1); 																		} # Default is checked
  if (exists($$refConfig{'REPORT_AUTO_OPEN'}))      { $$refWinReport->chOpenReport->Checked($$refConfig{'REPORT_AUTO_OPEN'}); 				}
  else                                              { $$refWinReport->chOpenReport->Checked(1); 																			} # Default is checked
  
}  #--- End loadConfig

#--------------------------#
sub updateAll
#--------------------------#
{
	# Local variables
	my ($VERSION, $USERDIR, $refHOURGLASS, $refARROW, $refWinConfig, $refConfig, $CONFIG_FILE, $refWinDTDB,
			$refWinLFDB, $refWinLFObj, $refWinPb, $refWin, $refSTR) = @_;
  # Thread 'cancellation' signal handler
  $SIG{'KILL'} = sub {
    # Delete temp files if converting was in progress
    if (-e $$refWinConfig->tfMACOUIDB->Text().'-journal') {
      my $localMACOUIDB = $$refWinConfig->tfMACOUIDB->Text();
      unlink($localMACOUIDB.'-journal');
      unlink($localMACOUIDB);
    }
    $$refWin->ChangeCursor($$refARROW);
    # Turn off progress bar
    $$refWinPb->lblPbCurr->Text('');
    $$refWinPb->lblCount->Text('');
    $$refWinPb->pbWinPb->SetPos(0);
    $$refWinPb->Hide();
    threads->exit();
  };
  # Thread 'die' signal handler
  $SIG{__DIE__} = sub {
    # Delete temp files if converting was in progress
    if (-e $$refWinConfig->tfMACOUIDB->Text().'-journal') {
      my $localMACOUIDB = $$refWinConfig->tfMACOUIDB->Text();
      unlink($localMACOUIDB.'-journal');
      unlink($localMACOUIDB);
    }
    my $errMsg = (split(/ at /,$_[0]))[0];
    chomp($errMsg);
    $errMsg =~ s/[\t\r\n]/ /g;
    $$refWinConfig->ChangeCursor($$refARROW);
    # Turn off progress bar
    $$refWinPb->lblPbCurr->Text('');
    $$refWinPb->lblCount->Text('');
    $$refWinPb->pbWinPb->SetPos(0);
    $$refWinPb->Hide();
    Win32::GUI::MessageBox($$refWinConfig, "$$refSTR{'errorMsg'}: $errMsg", $$refSTR{'Error'}, 0x40010);
  };
  sleep(1);
  &updateTool(    0, $VERSION, $refWinConfig, $refWin, $refSTR) if $$refConfig{'TOOL_AUTO_UPDATE'};	# Update Tool?
	&updateDB(0, 'MACOUI', $$refSTR{'MACOUIDB'}, $$refWinConfig->tfMACOUIDB->Text(), 'ieee.org', 'oui.db', $USERDIR,
						$refHOURGLASS, $refARROW, $refConfig, $CONFIG_FILE, $refWinConfig, $refWinDTDB, $refWinLFDB, $refWinLFObj,
						$refWinPb, $refWin, $refSTR)							if $$refConfig{'MACOUI_DB_AUTO_UPDATE'};			# Update MAC OUI ?
	&updateDB(0, 'TLD', $$refSTR{'lblTLDDB'}, $$refWinConfig->tfTLDDB->Text(), 'publicsuffix.org', 'effective_tld_names.dat',
						$USERDIR, $refHOURGLASS, $refARROW, $refConfig, $CONFIG_FILE, $refWinConfig, $refWinDTDB, $refWinLFDB,
						$refWinLFObj, $refWinPb, $refWin, $refSTR) if $$refConfig{'TLD_DB_AUTO_UPDATE'};				# Update TLDDB ?
  
}  #--- End updateAll

#--------------------------#
sub updateTool
#--------------------------#
{
  # Local variables
  my ($confirm, $VERSION, $refWinConfig, $refWin, $refSTR) = @_;
  # Download the version file  
  my $ua = new LWP::UserAgent;
  $ua->agent("XL-Parser Update $VERSION");
  $ua->default_header('Accept-Language' => 'en');
  my $req = new HTTP::Request GET => $URL_VER;
  my $res = $ua->request($req);
  # Success, compare versions
  if ($res->is_success) {
    my $status  = $res->code;
    my $content = $res->content;
    my $currVer;
    $currVer = $1 if $content =~ /([\d\.]+)/i;
    # No update available
    if ($currVer le $VERSION) {
      Win32::GUI::MessageBox($$refWinConfig, $$refSTR{'update1'}, $$refSTR{'update2'}, 0x40040) if $confirm; # Up to date
    } else {
      my $answer = Win32::GUI::MessageBox($$refWinConfig, "$$refSTR{'Version'} $currVer $$refSTR{'update5'} ?", "$$refSTR{'Update'} XL-Parser", 0x40024); # Download available
      # Download the update
      if ($answer == 6) {
        # Open XL-Parser page with default browser
        $$refWin->ShellExecute('open', $URL_TOOL,'','',1) or
          Win32::GUI::MessageBox($$refWinConfig, Win32::FormatMessage(Win32::GetLastError()), "$$refSTR{'Update'} XL-Parser",0x40010);
      }
    }
  }
  # Error 
  elsif ($confirm) { Win32::GUI::MessageBox($$refWinConfig, $$refSTR{'errorConnection'}.': '.$res->status_line, "$$refSTR{'Update'} XL-Parser",0x40010); }

}  #--- End updateTool

#--------------------------#
sub validSQLiteDB
#--------------------------#
{
  # Local variables
  my $DBFile = shift; # SQLite DB file
	my $table	 = shift; # Table name to check
  if (-f $DBFile) {
    my $dsn = "DBI:SQLite:dbname=$DBFile";
    if (my $dbh = DBI->connect($dsn, undef, undef, { })) {
      if (my $sth = $dbh->table_info(undef, undef, '%', 'TABLE')) {
				my @info = $sth->fetchrow_array;
				$sth->finish();
				return(1) if $info[2] eq $table; # If table exists, database is valid
			}
    }
  }
  return(0);
  
}  #--- End validSQLiteDB

#--------------------------#
sub updateDB
#--------------------------#
{
  # This function may be called in 2 ways
  # 1. User click on the update button ($confirm == 1)
  # 2. Auto update at start up: If database is up to date, we don't show message
  
  # Local variables
	my ($confirm, $db, $dbStr, $localFile, $site, $filename, $USERDIR, $refHOURGLASS, $refARROW, $refConfig, $CONFIG_FILE,
			$refWinConfig, $refWinDTDB, $refWinLFDB, $refWinLFObj, $refWinPb, $refWin, $refSTR) = @_;
  # if $confirm == 1, show message
	my $url;
	if		($db eq 'MACOUI') { $url = $MACOUIDB_URL; }
	elsif ($db eq 'TLD'		) { $url = $TLDDB_URL; 		}
  # Check if update available or necessary
  my $refWinH = $refWin;
  $refWinH    = $refWinConfig if $confirm;
  my ($upToDate, $return, $dateLocalFile, $dateRemoteFile) = &checkUpdate($confirm, $refWinH, $localFile, $url, $refHOURGLASS, $refARROW,
																																					$refConfig, $refWinConfig, $refWinPb, $refSTR);
  # Values for $upToDate
  # 0: Database doesn't exist  
  # 1: Database is up to date
  # 2: Database is outdated
  # 3: Error connection
  # 4: Unknown error
  # Database is outdated or doesn't exist
  if (!$upToDate or $upToDate == 2) {
    my $msg;
    if ($dateLocalFile and $dateRemoteFile) {
      Encode::from_to($dateRemoteFile, 'utf8', 'iso-8859-1');
      $msg = "$$refSTR{'currDBDate'}: $dateLocalFile\n$$refSTR{'remoteDBDate'} $site: $dateRemoteFile\n\n$$refSTR{'updateAvailable'}?";
    } else { $msg .= "$dbStr ($filename) $$refSTR{'NotExistDownload'}?"; }
    my $answer = Win32::GUI::MessageBox($$refWinH, $msg, "$$refSTR{'Update'} $dbStr", 0x1024);
    # Answer is No (7)
    if ($answer == 7) { return(0); }
    # Answer is Yes (6), download the update
    else {
      $$refWinH->ChangeCursor($$refHOURGLASS);
			if      ($db eq 'GeoIP') {
				if ($localFile) { $localFile =~ s/\\[^\\]+$//; }
				else            { $localFile = $USERDIR;       }
			}
			my ($status, $return) = &downloadDB($refWinH, $db, $dbStr, $localFile, $site, $refHOURGLASS, $refARROW, $refConfig,
																					$CONFIG_FILE, $refWinConfig, $refWinDTDB, $refWinLFDB, $refWinLFObj, $refWinPb, $refWin, $refSTR);
      if ($status) {
        $$refWinH->ChangeCursor($$refARROW);
        Win32::GUI::MessageBox($$refWinH, "$dbStr $$refSTR{'HasBeenUpdated'}", "$$refSTR{'Update'} $dbStr", 0x40040);
      } else {
        $$refWinH->ChangeCursor($$refARROW);
        $msg = "$$refSTR{'errorDownload'} $dbStr..." if !$msg;
        Win32::GUI::MessageBox($$refWinH, $msg, $$refSTR{'Error'}, 0x40010);
      }
    }
  # DB is up to date, show message if $confirm == 1
  } elsif ($upToDate == 1) {
    if ($confirm) {
      Encode::from_to($dateRemoteFile, 'utf8', 'iso-8859-1');
      my $msg = "$$refSTR{'currDBDate'}: $dateLocalFile\n$$refSTR{'remoteDBDate'} $site: $dateRemoteFile\n\n$$refSTR{'DBUpToDate'}!";
      Win32::GUI::MessageBox($$refWinH, $msg, "$$refSTR{'Update'} $dbStr", 0x40040);
    }
  # Connection error, show message if $confirm == 1
  } elsif (($upToDate == 3 or $upToDate == 4) and $confirm) {
    if ($upToDate == 3) { Win32::GUI::MessageBox($$refWinH, "$$refSTR{'errorConnection'}: $return", $$refSTR{'Error'}, 0x40010); }
    else                { Win32::GUI::MessageBox($$refWinH, "$$refSTR{'unknownError'}: $return", $$refSTR{'Error'}   , 0x40010); }
  }

}  #--- End updateDB

#--------------------------#
sub checkUpdate
#--------------------------#
{
  # Local variables
  my ($confirm, $refWinH, $localFile, $url, $refHOURGLASS, $refARROW, $refConfig, $refWinConfig, $refWinPb, $refSTR) = @_;
  my $lastModifDate;
  # File doesn't exist or invalid
  return(0, undef, undef, undef) if !$localFile or !-f $localFile;
  # Check date of local file
  my $localFileT = DateTime->from_epoch(epoch => (stat($localFile))[9]);
  if ($confirm) {
    # Set the progress bar
    $$refWinH->ChangeCursor($$refHOURGLASS);
    $$refWinPb->Text($$refSTR{'Update'});
    $$refWinPb->lblPbCurr->Text($$refSTR{'update2'}.'...');
    $$refWinPb->pbWinPb->SetRange(0, 1);
    $$refWinPb->pbWinPb->SetPos(0);
    $$refWinPb->pbWinPb->SetStep(1);
    $$refWinPb->Center($$refWinH);
    $$refWinPb->Show();
  }
  # Check date of the remote file
  my $ua = LWP::UserAgent->new;
  $ua->agent($$refConfig{'USERAGENT'});
  $ua->timeout($$refConfig{'NSLOOKUP_TIMEOUT'});
  $ua->default_header('Accept-Language' => 'en');
  my $req = HTTP::Request->new(HEAD => $url);
  my $res    = $ua->request($req);
  my $return = $res->status_line;
  if ($confirm) {
    # Turn off progress bar
    $$refWinH->ChangeCursor($$refARROW);
    $$refWinPb->lblPbCurr->Text('');
    $$refWinPb->lblCount->Text('');
    $$refWinPb->pbWinPb->SetPos(0);
    $$refWinPb->Hide();
  }
  if ($res->code == 200) {
    $lastModifDate = $res->header('last-modified');
    $TOTAL_SIZE    = $res->header('content_length');
  } else { return(3, $return, undef, undef); } # Error connection
  # Compare local et remote file date
  my $strp2 = DateTime::Format::Strptime->new(pattern => '%a, %d %b %Y %T %Z');
  if (my $lastModifT = $strp2->parse_datetime($lastModifDate)) {
		$localFileT->set_hour(0); $localFileT->set_minute(0); $localFileT->set_second(0);
		$lastModifT->set_hour(0); $lastModifT->set_minute(0); $lastModifT->set_second(0);
    my $cmp = DateTime->compare($localFileT, $lastModifT);
    if ($cmp > -1) { return(1, $return, $localFileT->ymd(), $lastModifT->ymd()); } # Database is up to date 
    else           { return(2, $return, $localFileT->ymd(), $lastModifT->ymd()); } # Database is outdated
  } else           { return(3, $return, undef             , undef             ); } # Connection error

}  #--- End checkUpdate

#--------------------------#
sub downloadDB
#--------------------------#
{
  # Local variables
  my ($refCurrWin, $db, $dbStr, $localFile, $site, $refHOURGLASS, $refARROW, $refConfig, $CONFIG_FILE, $refWinConfig,
			$refWinDTDB, $refWinLFDB, $refWinLFObj, $refWinPb, $refWin, $refSTR) = @_;
	my $url;
	if		($db eq 'MACOUI') { $url = $MACOUIDB_URL; }
	elsif ($db eq 'DT'		) { $url = $DTDB_URL;			}
	elsif ($db eq 'IIN'		) { $url = $IINDB_URL;		}
	elsif ($db eq 'LF'		) { $url = $LFDB_URL;			}
	elsif ($db eq 'TLD'		) { $url = $TLDDB_URL;		}
	elsif ($db eq 'ResTLD') { $url = $RESTLDDB_URL; }
  # Start an agent
  my $ua = LWP::UserAgent->new;
  $ua->agent($$refConfig{'USERAGENT'});
  $ua->timeout($$refConfig{'NSLOOKUP_TIMEOUT'});
  $ua->default_header('Accept-Language' => 'en');
  # Set the progress bar
  $$refCurrWin->ChangeCursor($$refHOURGLASS);
  $$refWinPb->Text("$$refSTR{'Download'} $dbStr...");
  $$refWinPb->lblPbCurr->Text("$$refSTR{'Connecting'} $site...");
  $$refWinPb->lblCount->Text("0 %");
  $$refWinPb->pbWinPb->SetRange(0, 100);
  $$refWinPb->pbWinPb->SetPos(0);
  $$refWinPb->pbWinPb->SetStep(1);
  $$refWinPb->Center($$refCurrWin);
  $$refWinPb->Show();
  # Check size of the remote file
  if (!$TOTAL_SIZE) {
    my $req    = new HTTP::Request HEAD => $url;
    my $res    = $ua->request($req);
    my $return = $res->status_line;
    if ($res->code == 200) { $TOTAL_SIZE = $res->header('content_length'); }
    else {
      # Turn off progress bar
      $$refCurrWin->ChangeCursor($$refARROW);
      $$refWinPb->lblPbCurr->Text('');
      $$refWinPb->lblCount->Text('');
      $$refWinPb->pbWinPb->SetPos(0);
      $$refWinPb->Hide();
      $TOTAL_SIZE = 0;
      return(0, $$refSTR{'errorConnection'});
    }
  }
  # Download the file
  my $errorMsg;
  if ($TOTAL_SIZE) {
    my $downloadData;
    # Download the file
    $$refWinPb->Text("$$refSTR{'Download'} $dbStr...");
    $$refWinPb->lblPbCurr->Text("$$refSTR{'Download'} $dbStr...");
    my $response = $ua->get($url, ':content_cb' => sub {
      # Local variables
      my ($data, $response, $protocol) = @_;
      $downloadData       .= $data;                                     # Downloaded data
      my $totalDownloaded  = length($downloadData);                     # Size of downloaded data
      my $completed        = int($totalDownloaded / $TOTAL_SIZE * 100); # Pourcentage of download completed
      $$refWinPb->pbWinPb->SetPos($completed);    # Set the progress bar
      $$refWinPb->lblCount->Text("$completed %"); # Indicate purcentage
    }, ':read_size_hint' => 32768);
    if ($response and $response->is_success) {
      # Save data in a file
      if ($db eq 'MACOUI') {
				my $ouiFileTemp = $localFile . '.txt';
				open(OUI_TEMP,">$ouiFileTemp");
				print OUI_TEMP $downloadData;
				close(OUI_TEMP);
				$downloadData = undef;
				$TOTAL_SIZE = 0;
				# Convert the downloaded data into a SQLite database
				$errorMsg = &importMACOUIDatabase($localFile, $ouiFileTemp, $refWinConfig, $refConfig, $CONFIG_FILE, $refWinPb, $refSTR);
			} elsif ($db eq 'DT') {
				my $DTDB_ZIP = $localFile . '.zip';
				if (open(ZIP,">$DTDB_ZIP")) {
					binmode(ZIP);
					print ZIP $downloadData;
					close(ZIP);
					# Uncompress DTDB ZIP
					my ($error, $msg);
					$TOTAL_SIZE = 0;
					if (unzip $DTDB_ZIP => $localFile, BinModeOut => 1) {
						if (&validSQLiteDB($localFile, 'DT')) {
							unlink $DTDB_ZIP;
							$$refWinConfig->tfDTDB->Text($localFile);
							$$refConfig{'DT_DB_FILE'} = $localFile;
							&saveConfig($refConfig, $CONFIG_FILE);
							# Load the Datetime database
							&createWinDTDB(1) if !$$refWinDTDB;
							&loadDTDB;
							&cbInputDTFormatAddITems();
							$$refWinLFObj->cbLFObjDT->SetCurSel(0);
							$$refWin->cbSplitTimeFormat->SetCurSel(0);
							&cbOutputDTFormatAddITems();
						} else { $errorMsg = "$$refSTR{'errorMsg'}: $$refSTR{'invalidFile'}"; }
					} else { $errorMsg = "$$refSTR{'errorMsg'}: $UnzipError"; }
				}
			} elsif ($db eq 'IIN') {
				my $IINDB_ZIP = $localFile . '.zip';
				if (open(ZIP,">$IINDB_ZIP")) {
					binmode(ZIP);
					print ZIP $downloadData;
					close(ZIP);
					# Uncompress IINDB ZIP
					$TOTAL_SIZE = 0;
					if (unzip $IINDB_ZIP => $localFile, BinModeOut => 1) {
						if (&validSQLiteDB($localFile, 'IIN')) {
							unlink $IINDB_ZIP;
							$$refWinConfig->tfIINDB->Text($localFile);
							$$refConfig{'IIN_DB_FILE'} = $localFile;
							&saveConfig($refConfig, $CONFIG_FILE);
						} else { $errorMsg = "$$refSTR{'errorMsg'}: $$refSTR{'invalidFile'}"; }
					} else { $errorMsg = "$$refSTR{'errorMsg'}: $UnzipError"; }
				}
			} elsif ($db eq 'LF') {
				my $LFDB_ZIP = $localFile . '.zip';
				if (open(ZIP,">$LFDB_ZIP")) {
					binmode(ZIP);
					print ZIP $downloadData;
					close(ZIP);
					# Uncompress LFDB ZIP
					$TOTAL_SIZE = 0;
					if (unzip $LFDB_ZIP => $localFile, BinModeOut => 1) {
						if (&validSQLiteDB($localFile, 'LF')) {
							unlink $LFDB_ZIP;
							$$refWinConfig->tfLFDB->Text($localFile);
							$$refConfig{'LF_DB_FILE'} = $localFile;
							&saveConfig($refConfig, $CONFIG_FILE);
							# Load the Log format database
							if (!$$refWinLFDB) {
								&createWinLFDB(0);
								&createWinLFObj() if !$$refWinLFObj;
							}
							&loadLFDB($localFile, $refWinLFDB, $refCurrWin, $refSTR);
							&cbInputLFFormatAddITems();
							$$refWin->cbLF->SetCurSel(0);
						} else { $errorMsg = "$$refSTR{'errorMsg'}: $$refSTR{'invalidFile'}"; }
					} else { $errorMsg = "$$refSTR{'errorMsg'}: $UnzipError"; }
				}
			} elsif ($db eq 'TLD') {
        if (open(TLDDB,">$localFile")) {
          print TLDDB $downloadData;
          close(TLDDB);
          # Vaidate file
          if (-f $localFile) {
            $$refWinConfig->tfTLDDB->Text($localFile);
            $$refConfig{'TLD_DB_FILE'} = $localFile;
						&saveConfig($refConfig, $CONFIG_FILE);
          } else { $errorMsg = "$$refSTR{'errDownloading'} $dbStr..."; }
				}
			} elsif ($db eq 'ResTLD') {
				my $ResTLDDB_ZIP = $localFile . '.zip';
				if (open(ZIP,">$ResTLDDB_ZIP")) {
					binmode(ZIP);
					print ZIP $downloadData;
					close(ZIP);
					# Uncompress ResTLDDB ZIP
					$TOTAL_SIZE = 0;
					if (unzip $ResTLDDB_ZIP => $localFile, BinModeOut => 1) {
						if (&validSQLiteDB($localFile, 'DATA')) {
							unlink $ResTLDDB_ZIP;
							$$refWinConfig->tfResTLDDB->Text($localFile);
							$$refConfig{'RES_TLD_DB_FILE'} = $localFile;
							&saveConfig($refConfig, $CONFIG_FILE);
						} else { $errorMsg = "$$refSTR{'errorMsg'}: $$refSTR{'invalidFile'}"; }
					} else { $errorMsg = "$$refSTR{'errorMsg'}: $UnzipError"; }
				}
      }
      $downloadData = undef;
      if (!$errorMsg) {
        # Turn off progress bar
        $$refCurrWin->ChangeCursor($$refARROW);
        $$refWinPb->lblPbCurr->Text('');
        $$refWinPb->lblCount->Text('');
        $$refWinPb->pbWinPb->SetPos(0);
        $$refWinPb->Hide();
        $TOTAL_SIZE = 0;
        return(1);
      }
    } else { $errorMsg = "$$refSTR{'errorDownload'} $dbStr..."; }
  } else { $errorMsg = "$$refSTR{'errorDownload'} $dbStr..."; }
  if ($errorMsg) {
    # Turn off progress bar
    $$refCurrWin->ChangeCursor($$refARROW);
    $$refWinPb->lblPbCurr->Text('');
    $$refWinPb->lblCount->Text('');
    $$refWinPb->pbWinPb->SetPos(0);
    $$refWinPb->Hide();
    $TOTAL_SIZE = 0;
    return(0, $errorMsg);
  }
  $TOTAL_SIZE = 0;
  
}  #--- End downloadDB

#--------------------------#
sub importMACOUIDatabase
#--------------------------#
{
  # Local variables
  my ($localMACOUIDB, $ouiFileTemp, $refWinConfig, $refConfig, $CONFIG_FILE, $refWinPb, $refSTR) = @_;
  my %oui;
  # Set Progress Bar
  $$refWinPb->Text("$$refSTR{'Convert'} $$refSTR{'MACOUIDB'}");
  $$refWinPb->lblPbCurr->Text('');
  $$refWinPb->lblCount->Text('');
  $$refWinPb->pbWinPb->SetPos(0);
  # Open the oui file and store prefix and minimal info about organization
  open my $ouiFH, '<', $ouiFileTemp;
  while (<$ouiFH>) {
    if (/((?:[a-fA-F0-9]{2}\-){2}[a-fA-F0-9]{2})\s+\(hex\)\t+([^\n\r]+)(?:$|[\n\r])/) {
      my $prefix    = $1;
      my $oui       = $2;
      $prefix       =~ s/\-//g;
      $oui{$prefix} = $oui;
    }
  }
  close($ouiFH);
  my $nbrOUI = scalar(keys %oui);
  if ($nbrOUI) {
    if (-f $localMACOUIDB) { # Delete last database file
      unlink($localMACOUIDB);
      $$refWinConfig->tfMACOUIDB->Text('');
    }
    # Create the database and the table
    $$refWinPb->lblPbCurr->Text($$refSTR{'createDBTable'}.'...');
    my $dsn = "DBI:SQLite:dbname=$localMACOUIDB";
    if (my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 0 })) {
      # Create the table
      my $stmt = qq(CREATE TABLE IF NOT EXISTS MACOUI
                    (prefix VARCHAR(8)    NOT NULL,
                     org    VARCHAR(150)  NOT NULL,
                     PRIMARY KEY(prefix)));
      if (my $rv = $dbh->do($stmt)) {
        # Add data
        my $curr = 0;
        $$refWinPb->lblCount->Text("0 / $nbrOUI");
        $$refWinPb->pbWinPb->SetRange(0, $nbrOUI);
        $$refWinPb->pbWinPb->SetPos(0);
        $$refWinPb->pbWinPb->SetStep(1);
        my $sth = $dbh->prepare('INSERT OR REPLACE INTO MACOUI (prefix,org) VALUES(?,?)');
        foreach my $prefix (keys %oui) {
          $$refWinPb->lblPbCurr->Text("$$refSTR{'Inserting'} $prefix...");
          my $rv = $sth->execute($prefix, $oui{$prefix});
          $curr++;
          $dbh->commit() if $curr % 1000 == 0;
          # Update progress bar
          $$refWinPb->lblCount->Text("$curr / $nbrOUI");
          $$refWinPb->pbWinPb->StepIt();
        }
      }
      $dbh->commit();
      $dbh->disconnect();
      # Turn off progress bar
      $$refWinPb->lblPbCurr->Text('');
      $$refWinPb->lblCount->Text('');
      $$refWinPb->pbWinPb->SetPos(0);
      $$refWinPb->Hide();
      # Final message
      if (&validSQLiteDB($localMACOUIDB, 'MACOUI')) {
        unlink($ouiFileTemp);
        $$refWinConfig->tfMACOUIDB->Text($localMACOUIDB);
        $$refConfig{'MACOUI_DB_FILE'} = $localMACOUIDB;
        &saveConfig($refConfig, $CONFIG_FILE);
        $$refWinConfig->tfMACOUIDB->Text($localMACOUIDB);
        return();
      } else { return("$$refSTR{'errorMsg'}: $$refSTR{'errorCreatingDB'}..."); }
    } else {
      # Turn off progress bar
      $$refWinPb->lblPbCurr->Text('');
      $$refWinPb->lblCount->Text('');
      $$refWinPb->pbWinPb->SetPos(0);
      $$refWinPb->Hide();
      return("$$refSTR{'errorMsg'}: $$refSTR{'errorConnectDB'}...");
    }
  } else {
    # Turn off progress bar
    $$refWinPb->lblPbCurr->Text('');
    $$refWinPb->lblCount->Text('');
    $$refWinPb->pbWinPb->SetPos(0);
    $$refWinPb->Hide();
    return("$$refSTR{'errorMsg'}: $$refSTR{'errorOUI_TXT'}...");
  }

}  #--- End importMACOUIDatabase

#--------------------------#
sub validGeoIPDB
#--------------------------#
{
  # Local variables
  my $GeoIPDBFile = shift;
  if (-e $GeoIPDBFile) {
		eval { MaxMind::DB::Reader->new(file => $GeoIPDBFile) };
    if (!$@) { return(1); }
		else		 { return(0); }
  } else { return(0); }
  
}  #--- End validGeoIPDB

#--------------------------#
sub createExprHistoDB
#--------------------------#
{
  # Local variables
  my $exprHistoDBFile = shift;
  # Create a new database
	$exprHistoDBFile = encode('utf8', $exprHistoDBFile);
  my $dsn = "DBI:SQLite:dbname=$exprHistoDBFile";
  my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 }) or return(0);
  # Create main table
  # Date: Date and time when last used (unixtime)
  my $stmt = qq(CREATE TABLE IF NOT EXISTS EXPR_HISTO_DB
                (date       INT           NOT NULL,
                 matchcase  INT           NOT NULL,
                 regex      INT           NOT NULL,
                 invert     INT           NOT NULL,
                 expr       VARCHAR(255)  NOT NULL,
                 comment    VARCHAR(255),
                 PRIMARY KEY (expr)));
  my $rv = $dbh->do($stmt);
  $dbh->disconnect();
  return(0) if $rv < 0;
  return(1);
  
}  #--- End createExprHistoDB

#--------------------------#
sub loadExprHistoDB
#--------------------------#
{
  # Local variables
	my ($exprHistoDBFile, $refWinExtraction, $timezone, $refWin, $refSTR) = @_;
  if (-f $exprHistoDBFile) {
    # Connect to DB
		$exprHistoDBFile = encode('utf8', $exprHistoDBFile);
    my $dsn = "DBI:SQLite:dbname=$exprHistoDBFile";
    my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 })
              or Win32::GUI::MessageBox($$refWin, $$refSTR{'errorConnectDB'}.$DBI::errstr, $$refSTR{'Error'}, 0x40010);
    # Check if EXPR_HISTO_DB table exists
    my $sth;
    eval { $sth = $dbh->table_info(undef, undef, '%', 'TABLE'); };
    if ($@) {
      Win32::GUI::MessageBox($$refWin, $$refSTR{'errorConnectDB'}.$DBI::errstr, $$refSTR{'Error'}, 0x40010);
      return(0);
    }
    my @info = $sth->fetchrow_array;
    $sth->finish();
    if ($info[2] and $info[2] eq 'EXPR_HISTO_DB') { # If table EXPR_HISTO_DB exists, than load data
      my $all = $dbh->selectall_arrayref('SELECT * FROM EXPR_HISTO_DB ORDER BY date DESC');
      # Database: table = EXPR_HISTO_DB, Fields = date, matchcase, regex, invert, expr, comment
      # Feed the grid
      my $i = 1;
      $$refWinExtraction->gridExprHistory->SetRows(scalar(@$all)+1);
      foreach my $row (@$all) {
        my (@values) = @$row;
        my $dt = DateTime->from_epoch(epoch => $values[0]); # Convert unixtime
        $dt->set_time_zone($timezone);
        $$refWinExtraction->gridExprHistory->SetCellText($i, 0, $dt->strftime('%F %T')); # Date
        $$refWinExtraction->gridExprHistory->SetCellType($i, 1, 4);
        $$refWinExtraction->gridExprHistory->SetCellType($i, 2, 4);
        $$refWinExtraction->gridExprHistory->SetCellType($i, 3, 4);
        if ($values[1]) { $$refWinExtraction->gridExprHistory->SetCellCheck($i, 1, 1);  } # Case
        else            { $$refWinExtraction->gridExprHistory->SetCellCheck($i, 1, 0);  }
        if ($values[2]) { $$refWinExtraction->gridExprHistory->SetCellCheck($i, 2, 1);  } # Regex
        else            { $$refWinExtraction->gridExprHistory->SetCellCheck($i, 2, 0);  }
        if ($values[3]) { $$refWinExtraction->gridExprHistory->SetCellCheck($i, 3, 1);  } # Invert
        else            { $$refWinExtraction->gridExprHistory->SetCellCheck($i, 3, 0);  }
        $$refWinExtraction->gridExprHistory->SetCellText($i, 4, $values[4]); # expr
        if ($values[4]) { $$refWinExtraction->gridExprHistory->SetCellText($i, 5, $values[5]); } # comment
        $$refWinExtraction->gridExprHistory->SetCellEditable($i, 0, 0);
        $$refWinExtraction->gridExprHistory->SetCellEditable($i, 1, 0);
        $$refWinExtraction->gridExprHistory->SetCellEditable($i, 2, 0);
        $$refWinExtraction->gridExprHistory->SetCellEditable($i, 3, 0);
        $$refWinExtraction->gridExprHistory->SetCellEditable($i, 4, 0);
        $$refWinExtraction->gridExprHistory->SetCellEditable($i, 5, 0);
        $i++;
      }
      # Refresh grid
      $$refWinExtraction->gridExprHistory->AutoSizeColumns();
      $$refWinExtraction->gridExprHistory->ExpandLastColumn();
      $dbh->disconnect();
      return(1);
    } else { Win32::GUI::MessageBox($$refWin, $$refSTR{'errorDB'}, $$refSTR{'Error'}, 0x40010); return(0); }
  } else { return(0); }

}  #--- End loadExprHistoDB

#--------------------------#
sub createExprDB
#--------------------------#
{
  # Local variables
  my $exprDBFile = shift;
  # Create a new database
	$exprDBFile = encode('utf8', $exprDBFile);
  my $dsn 		= "DBI:SQLite:dbname=$exprDBFile";
  my $dbh 		= DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 }) or return(0);
  # Create main table
  # used: Number of times that expression has been used (most used are displayed first)
  my $stmt = qq(CREATE TABLE IF NOT EXISTS EXPR_DB
                (used       INT           NOT NULL,
                 matchcase  INT           NOT NULL,
                 regex      INT           NOT NULL,
                 invert     INT           NOT NULL,
                 expr       VARCHAR(255)  NOT NULL,
                 comment    VARCHAR(255),
                 PRIMARY KEY (expr)));
  my $rv = $dbh->do($stmt);
  return(0) if $rv < 0;
  $dbh->disconnect();
  return(1);
  
}  #--- End createExprDB

#--------------------------#
sub loadExprDB
#--------------------------#
{
  # Local variables
	my ($exprHistoDBFile, $refWinExtraction, $refWin, $refSTR) = @_;
  if (-f $exprHistoDBFile) {
    # Connect to DB
		$exprHistoDBFile = encode('utf8', $exprHistoDBFile);
    my $dsn 				 = "DBI:SQLite:dbname=$exprHistoDBFile";
    my $dbh 				 = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 })
										 or Win32::GUI::MessageBox($$refWin, $$refSTR{'errorConnectDB'}.$DBI::errstr, $$refSTR{'Error'}, 0x40010);
    # Check if EXPR_DB table exists
    my $sth;
    eval { $sth = $dbh->table_info(undef, undef, '%', 'TABLE'); };
    if ($@) {
      Win32::GUI::MessageBox($$refWin, $$refSTR{'errorConnectDB'}.$DBI::errstr, $$refSTR{'Error'}, 0x40010);
      return(0);
    }
    my @info = $sth->fetchrow_array;
    $sth->finish();
    if ($info[2] and $info[2] eq 'EXPR_DB') { # If table EXPR_DB exists, than load data
      my $all = $dbh->selectall_arrayref("SELECT * FROM EXPR_DB ORDER BY used DESC");
      # Database: table = EXPR_DB, Fields = used, matchcase, regex, invert, expr, comment
      # Feed the grid
      my $i = 1;
      $$refWinExtraction->gridExprDatabase->SetRows(scalar(@$all)+1);
      foreach my $row (@$all) {
        my (@values) = @$row;
        $$refWinExtraction->gridExprDatabase->SetCellText($i, 0, $values[0]); # Used
        $$refWinExtraction->gridExprDatabase->SetCellType($i, 1, 4);
        $$refWinExtraction->gridExprDatabase->SetCellType($i, 2, 4);
        $$refWinExtraction->gridExprDatabase->SetCellType($i, 3, 4);
        if ($values[1]) { $$refWinExtraction->gridExprDatabase->SetCellCheck($i, 1, 1);  } # Case
        else            { $$refWinExtraction->gridExprDatabase->SetCellCheck($i, 1, 0);  }
        if ($values[2]) { $$refWinExtraction->gridExprDatabase->SetCellCheck($i, 2, 1);  } # Regex
        else            { $$refWinExtraction->gridExprDatabase->SetCellCheck($i, 2, 0);  }
        if ($values[3]) { $$refWinExtraction->gridExprDatabase->SetCellCheck($i, 3, 1);  } # Invert
        else            { $$refWinExtraction->gridExprDatabase->SetCellCheck($i, 3, 0);  }
        $$refWinExtraction->gridExprDatabase->SetCellText($i, 4, $values[4]); # expr
        if ($values[4]) { $$refWinExtraction->gridExprDatabase->SetCellText($i, 5, $values[5]); } # comment
        $$refWinExtraction->gridExprDatabase->SetCellEditable($i, 0, 0);
        $$refWinExtraction->gridExprDatabase->SetCellEditable($i, 1, 1);
        $$refWinExtraction->gridExprDatabase->SetCellEditable($i, 2, 1);
        $$refWinExtraction->gridExprDatabase->SetCellEditable($i, 3, 1);
        $$refWinExtraction->gridExprDatabase->SetCellEditable($i, 4, 0);
        $$refWinExtraction->gridExprDatabase->SetCellEditable($i, 5, 1);
        $i++;
      }
      # Refresh grid
      $$refWinExtraction->gridExprDatabase->AutoSizeColumns();
      $$refWinExtraction->gridExprDatabase->ExpandLastColumn();
      $dbh->disconnect();
      return(1);
    } else { Win32::GUI::MessageBox($$refWin, $$refSTR{'errorDB'}, $$refSTR{'Error'}, 0x40010); return(0); }
  } else { return(0); }

}  #--- End loadExprDB

#--------------------------#
sub validTLDDB
#--------------------------#
{
  # Local variables
  my $TLDdbFile = shift;
  my $TLDDB = Domain::PublicSuffix->new({ 'data_file' => $TLDdbFile });
  return(1) if $TLDDB->get_root_domain('www.google.com');
  return(0);
  
}  #--- End validTLDDB

#------------------------------------------------------------------------------#
1;