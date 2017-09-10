#!/usr/bin/perl
# Perl - v: 5.16.3
#------------------------------------------------------------------------------#
# XL-ParserConfig.pl	: Configuration functions for XL-Parser
# Website     				: http://le-tools.com/XL-Parser.html
# SourceForge					: https://sourceforge.net/p/xl-parser
# GitHub							: https://github.com/arioux/XL-Parser
# Creation						: 2016-07-15
# Modified						: 2017-09-10
# Author							: Alain Rioux (admin@le-tools.com)
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
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use IO::Uncompress::Unzip qw(unzip $UnzipError);
use Domain::PublicSuffix;

#------------------------------------------------------------------------------#
# Global variables
#------------------------------------------------------------------------------#
my $URL_TOOL        = 'http://le-tools.com/XL-Parser.html#Download';           # Url of the tool
my $URL_VER         = 'http://www.le-tools.com/download/XL-ParserVer.txt';     # Url of the version file
my $MACOUIDB_URL    = 'http://standards-oui.ieee.org/oui.txt';                 # URL of the MAC OUI DB
my $GEOIPDB_URL     = 'http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz'; # URL of the GeoIP DB
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
  my $CONFIG_FILE = shift;
  my $refConfig   = shift;
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
  if (exists($$refConfig{'GEOIP_DB_AUTO_UPDATE'}))  { $$refWinConfig->chGeoIPDBAutoUpt->Checked($$refConfig{'GEOIP_DB_AUTO_UPDATE'});   }
  else                                              { $$refWinConfig->chGeoIPDBAutoUpt->Checked(1);                                     } # Default is checked
  if (exists($$refConfig{'GEOIP_DB_FILE'}) and
      -f $$refConfig{'GEOIP_DB_FILE'})              { $$refWinConfig->tfGeoIPDB->Text($$refConfig{'GEOIP_DB_FILE'});                    }
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
	my ($VERSION, $USERDIR, $refHOURGLASS, $refARROW, $CONFIG_FILE, $refConfig, $refWinConfig, $refWinPb, $refWin, $refSTR) = @_;
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
    Win32::GUI::MessageBox($$refWinConfig, "$$refSTR{'errorMsg'}: $errMsg", $$refSTR{'error'}, 0x40010);
  };
  # Update Tool ?
  sleep(1);
  &updateTool(   	0, $VERSION, $refWinConfig, $refWin, $refSTR) if $$refConfig{'TOOL_AUTO_UPDATE'};
  # Update GeoIP DB ?
  &updateGeoIPDB(	0, $VERSION, $USERDIR, $refHOURGLASS, $refARROW, $CONFIG_FILE, $refConfig, $refWinConfig,
									$refWinPb, $refWin, $refSTR) if $$refConfig{'GEOIP_DB_AUTO_UPDATE'};
  # Update MACOUI DB ?
  &updateMACOUIDB(0, $VERSION, $USERDIR, $refHOURGLASS, $refARROW, $CONFIG_FILE, $refConfig, $refWinConfig,
									$refWinPb, $refWin, $refSTR) if ($$refConfig{'MACOUI_DB_AUTO_UPDATE'});
  
}  #--- End updateAll

#--------------------------#
sub updateTool
#--------------------------#
{
  # Local variables
  my ($confirm, $VERSION, $refWinConfig, $refWin, $refSTR) = @_;
  # Download the version file  
  my $ua = new LWP::UserAgent;
  $ua->agent("XL-FileTools Update $VERSION");
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
      my $answer = Win32::GUI::MessageBox($$refWinConfig, "$$refSTR{'Version'} $currVer $$refSTR{'update5'} ?", $$refSTR{'update3'}, 0x40024); # Download available
      # Download the update
      if ($answer == 6) {
        # Open Firefox to XL-FileTools page
        $$refWin->ShellExecute('open', $URL_TOOL,'','',1) or
          Win32::GUI::MessageBox($$refWinConfig, Win32::FormatMessage(Win32::GetLastError()), "$$refSTR{'update3'} XL-FileTools",0x40010);
      }
    }
  }
  # Error 
  elsif ($confirm) { Win32::GUI::MessageBox($$refWinConfig, $$refSTR{'errorConnection'}.': '.$res->status_line, "$$refSTR{'update3'} XL-FileTools",0x40010); }

}  #--- End updateTool

#--------------------------#
sub validMACOUIDB
#--------------------------#
{
  # Local variables
  my $MACOUIDBFile = shift;
  if (-f $MACOUIDBFile) {
    # Connect to DB
		$MACOUIDBFile = encode('utf8', $MACOUIDBFile);
    my $dsn = "DBI:SQLite:dbname=$MACOUIDBFile";
    if (my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 })) {
      my $sth;
      eval { $sth = $dbh->table_info(undef, undef, '%', 'TABLE'); };
      return(0) if $@;
      # If table MACOUI exists, database is valid
      my @info = $sth->fetchrow_array;
      $sth->finish();
      return(1) if $info[2] eq 'MACOUI';
    }
  }
  return(0);
  
}  #--- End validMACOUIDB

#--------------------------#
sub updateMACOUIDB
#--------------------------#
{
  # This function may be called in 2 ways
  # 1. User click on the update button ($confirm == 1)
  # 2. Auto update at start up: If database is up to date, we don't show message
	my ($confirm, $VERSION, $USERDIR, $refHOURGLASS, $refARROW, $CONFIG_FILE, $refConfig, $refWinConfig,
			$refWinPb, $refWin, $refSTR) = @_;
  my ($upToDate, $return, $dateLocalFile, $dateRemoteFile) = &checkDateMACOUIDB($confirm, $refConfig, $refWinConfig);
  # Values for $upToDate
  # 0: MAC OUI Database doesn't exist
  # 1: Database is up to date
  # 2: Database is outdated
  # 3: Error connection
  # 4: Unknown error

  # MAC OUI Database is outdated or doesn't exist
  if (!$upToDate or $upToDate == 2) {
    my $msg;
    if ($dateLocalFile and $dateRemoteFile) {
      Encode::from_to($dateRemoteFile, 'utf8', 'iso-8859-1');
      $msg = "$$refSTR{'currDBDate'}: $dateLocalFile\n$$refSTR{'remoteDBDate'} ieee.org: $dateRemoteFile\n\n$$refSTR{'updateAvailable'} ?";
    } else { $msg = "$$refSTR{'MACOUINotExist'} ?"; }
    my $answer = Win32::GUI::MessageBox($$refWin, $msg, $$refSTR{'update3'}.' '.$$refSTR{'OUIDB2'}, 0x1024);
    # Answer is No (7)
    if ($answer == 7) { return(0); }
    # Answer is Yes, download the update
    else {
      my $return = &downloadMACOUIDB($$refWinConfig->tfMACOUIDB->Text(), $USERDIR, $refHOURGLASS, $refARROW,
																		 $CONFIG_FILE, $refConfig, $refWinConfig, $refWinPb, $refWin, $refSTR); # $return contains error msg if any
      if ($return) { Win32::GUI::MessageBox($$refWin, $return, $$refSTR{'error'}, 0x40010);                     }
      else         { Win32::GUI::MessageBox($$refWin, $$refSTR{'updatedMACOUI'}, "XL-Parser $VERSION", 0x40040); }
    }
  # MAC OUI is up to date, show message if $confirm == 1
  } elsif ($upToDate == 1) {
    if ($confirm) {
      Encode::from_to($dateRemoteFile, 'utf8', 'iso-8859-1');
      Win32::GUI::MessageBox($$refWin, "$$refSTR{'currDBDate'}: $dateLocalFile\n$$refSTR{'remoteDBDate'} ieee.org: ".
                                       "$dateRemoteFile\n\n$$refSTR{'DBUpToDate'} !", $$refSTR{'update3'}.' '.$$refSTR{'OUIDB2'}, 0x40040);
    }
  # Connection error, show message if $confirm == 1
  } elsif (($upToDate == 3 or $upToDate == 4) and $confirm) {
    if ($upToDate == 3) { Win32::GUI::MessageBox($$refWin, "$$refSTR{'errorConnection'}: $return", $$refSTR{'error'}, 0x40010); }
    else                { Win32::GUI::MessageBox($$refWin, "$$refSTR{'unknownError'}: $return", $$refSTR{'error'}   , 0x40010); }
  }

}  #--- End updateMACOUIDB

#--------------------------#
sub checkDateMACOUIDB
#--------------------------#
{
  # Local variables
  my ($confirm, $refConfig, $refWinConfig) = @_;
  my $localMACOUIDB  = $$refWinConfig->tfMACOUIDB->Text();
  my $lastModifDate;
  # MAC OUI Database doesn't exist or invalid file
  return(0, undef, undef, undef) if !$localMACOUIDB or !-f $localMACOUIDB;
  # Check date of local file
  my $localFileT  = DateTime->from_epoch(epoch => (stat($localMACOUIDB))[9]);
  # Check date of the remote file
  my $ua = new LWP::UserAgent;
  $ua->agent($$refConfig{'USERAGENT'});
  $ua->default_header('Accept-Language' => 'en');
  my $req    = new HTTP::Request HEAD => $MACOUIDB_URL;
  my $res    = $ua->request($req);
  my $return = $res->status_line;
  if ($res->code == 200) {
    $lastModifDate = $res->header('last-modified');
    $TOTAL_SIZE    = $res->header('content_length');
  } else { return(3, $return, undef, undef); } # Error connection
  # Compare local et remote file date
  my $strp2 = DateTime::Format::Strptime->new(pattern => '%a, %d %b %Y %T %Z');
  if (my $lastModifT = $strp2->parse_datetime($lastModifDate)) {
    my $cmp = DateTime->compare($localFileT, $lastModifT);
    if ($cmp > -1) { return(1, $return, $localFileT->ymd(), $lastModifT->ymd()); } # MACOUIDB is up to date 
    else           { return(2, $return, $localFileT->ymd(), $lastModifT->ymd()); } # MACOUIDB is outdated
  } else           { return(3, $return, undef             , undef             ); } # Connection error

}  #--- End checkDateMACOUIDB

#--------------------------#
sub downloadMACOUIDB
#--------------------------#
{
  # Local variables
  my ($localMACOUIDB, $USERDIR, $refHOURGLASS, $refARROW, $CONFIG_FILE, $refConfig,
			$refWinConfig, $refWinPb, $refWin, $refSTR) = @_;
  $localMACOUIDB = "$USERDIR\\oui.db" if !$localMACOUIDB; # Default location
  # Set the progress bar
  $$refWin->ChangeCursor($$refHOURGLASS);
  $$refWinPb->Text($$refSTR{'Downloading'}.' '.$$refSTR{'OUIDB2'}.'...');
  $$refWinPb->lblPbCurr->Text($$refSTR{'connecting'}.' ieee.org...');
  $$refWinPb->lblCount->Text("0 %");
  $$refWinPb->pbWinPb->SetRange(0, 100);
  $$refWinPb->pbWinPb->SetPos(0);
  $$refWinPb->pbWinPb->SetStep(1);
  $$refWinPb->Center($$refWin);
  $$refWinPb->Show();
  # Start an agent
  my $ua = new LWP::UserAgent;
  $ua->agent($$refConfig{'USERAGENT'});
  $ua->default_header('Accept-Language' => 'en');
  # Check size of the remote file
  if (!$TOTAL_SIZE) {
    my $req    = new HTTP::Request HEAD => $MACOUIDB_URL;
    my $res    = $ua->request($req);
    my $return = $res->status_line;
    if ($res->code == 200) { $TOTAL_SIZE = $res->header('content_length'); }
    else {
      # Turn off progress bar
      $$refWin->ChangeCursor($$refARROW);
      $$refWinPb->lblPbCurr->Text('');
      $$refWinPb->lblCount->Text('');
      $$refWinPb->pbWinPb->SetPos(0);
      $$refWinPb->Hide();
      return("$$refSTR{'errorMsg'}: $$refSTR{'errorConRemote'}...");
    }
  }
  # Download the file
  if ($TOTAL_SIZE) {
    my $downloadData;
    # Download the file
    $$refWinPb->lblPbCurr->Text($$refSTR{'Downloading'}.' '.$$refSTR{'OUIDB2'}.'. '.$$refSTR{'downloadWarning'}.'...');
    my $response = $ua->get($MACOUIDB_URL, ':content_cb' => sub {
      # Local variables
      my ($data, $response, $protocol) = @_;
      $downloadData       .= $data;                                     # Downloaded data
      my $totalDownloaded  = length($downloadData);                     # Size of downloaded data
      my $completed        = int($totalDownloaded / $TOTAL_SIZE * 100); # Pourcentage of download completed
      $$refWinPb->pbWinPb->SetPos($completed);    # Set the progress bar
      $$refWinPb->lblCount->Text("$completed %"); # Indicate purcentage
    }, ':read_size_hint' => 32768);
    # Save data in a temp file
    my $ouiFileTemp = $localMACOUIDB . '.txt';
    if ($response and $response->is_success) {
      open(OUI_TEMP,">$ouiFileTemp");
      print OUI_TEMP $downloadData;
      close(OUI_TEMP);
    }
    $downloadData = undef;
    # Convert the downloaded data into a SQLite database
    if (-T $ouiFileTemp) {
      $TOTAL_SIZE = 0;
      return(&importMACOUIDatabase(1, $localMACOUIDB, $ouiFileTemp, $refARROW, $CONFIG_FILE,
																	 $refConfig, $refWinConfig, $refWinPb, $refWin, $refSTR));
    }
  } else {
    # Turn off progress bar
    $$refWin->ChangeCursor($$refARROW);
    $$refWinPb->lblPbCurr->Text('');
    $$refWinPb->lblCount->Text('');
    $$refWinPb->pbWinPb->SetPos(0);
    $$refWinPb->Hide();
    return("$$refSTR{'errorMsg'}: $$refSTR{'errorDownload'}...");
  }  
  $TOTAL_SIZE = 0;
  
}  #--- End downloadMACOUIDB

#--------------------------#
sub importMACOUIDatabase
#--------------------------#
{
  # This function may be called in 2 ways
  # 1. User click on the import button using a local oui.txt
  # 2. Database is downloaded
  # Return error or return 0 if successful
  my ($winPbStatus, $localMACOUIDB, $ouiFileTemp, $refARROW, $CONFIG_FILE, $refConfig, $refWinConfig, $refWinPb, $refWin, $refSTR) = @_;
	# If $winPbStatus == 1, WinPb is already displayed
  # $localMACOUIDB = Destination file
  # $ouiFileTemp   = oui.txt file
  my %oui;
  # Show Progress Window
  if (!$winPbStatus) {
    $$refWinPb->Center($$refWin);
    $$refWinPb->Show();
  }
  # Set Progress Bar
  $$refWinPb->Text($$refSTR{'convertMACOUI'});
  $$refWinPb->lblPbCurr->Text('');
  $$refWinPb->lblCount->Text('');
  $$refWinPb->pbWinPb->SetPos(0);
  # Open the oui file and store prefix and minimal info about organization
  open my $ouiFH, '<', $ouiFileTemp;
  while (<$ouiFH>) {
    if (/((?:[a-fA-F0-9]{2}\-){2}[a-fA-F0-9]{2})\s+\(hex\)\t+([^\n\r]+)(?:$|[\n\r])/) {
      my $prefix = $1;
      my $oui    = $2;
      $prefix =~ s/\-//g;
      $oui{$prefix} = $oui;
    }
  }
  close($ouiFH);
  my $nbrOUI = scalar(keys %oui);
  if ($nbrOUI) {
		if (-e $localMACOUIDB) { # Delete last database file
			unlink($localMACOUIDB);
			$$refWinConfig->tfMACOUIDB->Text('');
		}
		# Create the database and the table
    $$refWinPb->lblPbCurr->Text($$refSTR{'createDBTable'}.'...');
		$localMACOUIDB = encode('utf8', $localMACOUIDB);
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
        my $sth = $dbh->prepare('INSERT OR REPLACE INTO MACOUI (prefix,org) values(?,?)');
        foreach my $prefix (keys %oui) {
          $$refWinPb->lblPbCurr->Text("$$refSTR{'add'} $prefix...");
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
      $$refWin->ChangeCursor($$refARROW);
      $$refWinPb->lblPbCurr->Text('');
      $$refWinPb->lblCount->Text('');
      $$refWinPb->pbWinPb->SetPos(0);
      $$refWinPb->Hide();
      # Final message
      if (&validMACOUIDB($localMACOUIDB)) {
        unlink($ouiFileTemp);
        $$refWinConfig->tfMACOUIDB->Text($localMACOUIDB);
        $$refConfig{'MACOUI_DB_FILE'} = $localMACOUIDB;
        &saveConfig($CONFIG_FILE, $refConfig);
        $$refWinConfig->tfMACOUIDB->Text($localMACOUIDB);
        return(0);
      } else { return("$$refSTR{'errorMsg'}: $$refSTR{'errorCreatingDB'}..."); }
    } else {
      # Turn off progress bar
      $$refWin->ChangeCursor($$refARROW);
      $$refWinPb->lblPbCurr->Text('');
      $$refWinPb->lblCount->Text('');
      $$refWinPb->pbWinPb->SetPos(0);
      $$refWinPb->Hide();
      return("$$refSTR{'errorMsg'}: $$refSTR{'errorConnectDB'}...");
    }
  } else {
    # Turn off progress bar
    $$refWin->ChangeCursor($$refARROW);
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
  if (-f $GeoIPDBFile and my $gi = Geo::IP->open($GeoIPDBFile)) { return(1) if $gi->database_info; }
  return(0);
  
}  #--- End validGeoIPDB

#--------------------------#
sub updateGeoIPDB
#--------------------------#
{
  # This function may be called in 2 ways
  # 1. User click on the update button ($confirm == 1)
  # 2. Auto update at start up: If database is up to date, we don't show message
	my ($confirm, $VERSION, $USERDIR, $refHOURGLASS, $refARROW, $CONFIG_FILE, $refConfig, $refWinConfig,
			$refWinPb, $refWin, $refSTR) = @_;
  my ($upToDate, $return, $dateLocalFile, $dateRemoteFile) = &checkDateGeoIPDB($confirm, $refConfig, $refWinConfig);
  # Values for $upToDate
  # 0: GeoIP Database doesn't exist  
  # 1: Database is up to date
  # 2: Database is outdated
  # 3: Error connection
  # 4: Unknown error

  # GeoIP Database is outdated or doesn't exist
  if (!$upToDate or $upToDate == 2) {
    my $msg;
    if ($dateLocalFile and $dateRemoteFile) {
      Encode::from_to($dateRemoteFile, 'utf8', 'iso-8859-1');
      $msg = "$$refSTR{'currDBDate'}: $dateLocalFile\n$$refSTR{'remoteDBDate'} Maxmind: $dateRemoteFile\n\n$$refSTR{'updateAvailable'} ?";
    } else { $msg = "$$refSTR{'GeoIPNotExist'} ?"; }
    my $answer = Win32::GUI::MessageBox($$refWin, $msg, $$refSTR{'update3'}.' '.$$refSTR{'GeoIPDB2'}, 0x1024);
    # Answer is No (7)
    if ($answer == 7) { return(0); }
    # Answer is Yes, download the update
    else {
      my $return = &downloadGeoIPDB($$refWinConfig->tfGeoIPDB->Text(), $USERDIR, $refHOURGLASS, $refARROW,
																		$CONFIG_FILE, $refConfig, $refWinConfig, $refWinPb, $refWin, $refSTR); # $return contains error msg if any
      if ($return) { Win32::GUI::MessageBox($$refWin, $return, $$refSTR{'error'}, 0x40010);                    }
      else         { Win32::GUI::MessageBox($$refWin, $$refSTR{'updatedGeoIP'}, "XL-Parser $VERSION", 0x40040); }
    }
  # GeoIP is up to date, show message if $confirm == 1
  } elsif ($upToDate == 1) {
    if ($confirm) {
      Encode::from_to($dateRemoteFile, 'utf8', 'iso-8859-1');
      Win32::GUI::MessageBox($$refWin, "$$refSTR{'currDBDate'}: $dateLocalFile\n$$refSTR{'remoteDBDate'} Maxmind: ".
                                       "$dateRemoteFile\n\n$$refSTR{'DBUpToDate'} !", $$refSTR{'update3'}.' '.$$refSTR{'GeoIPDB2'}, 0x40040);
    }
  # Connection error, show message if $confirm == 1
  } elsif (($upToDate == 3 or $upToDate == 4) and $confirm) {
    if ($upToDate == 3) { Win32::GUI::MessageBox($$refWin, "$$refSTR{'errorConnection'}: $return", $$refSTR{'error'}, 0x40010); }
    else                { Win32::GUI::MessageBox($$refWin, "$$refSTR{'unknownError'}: $return", $$refSTR{'error'}   , 0x40010); }
  }

}  #--- End updateGeoIPDB

#--------------------------#
sub checkDateGeoIPDB
#--------------------------#
{
  # Local variables
  my ($confirm, $refConfig, $refWinConfig) = @_;
  my $localGeoIPDB = $$refWinConfig->tfGeoIPDB->Text();
  my $lastModifDate;
  # MAC OUI Database doesn't exist or invalid file
  return(0, undef, undef, undef) if !$localGeoIPDB or !-f $localGeoIPDB;
  # Check date of local file
	my $localFileT  = DateTime->from_epoch(epoch => (stat($localGeoIPDB))[9]);
  # Check date of the remote file
  my $ua = new LWP::UserAgent;
  $ua->agent($$refConfig{'USERAGENT'});
  $ua->default_header('Accept-Language' => 'en');
  my $req    = new HTTP::Request HEAD => $GEOIPDB_URL;
  my $res    = $ua->request($req);
  my $return = $res->status_line;
  if ($res->code == 200) {
    $lastModifDate = $res->header('last-modified');
    $TOTAL_SIZE    = $res->header('content_length');
  } else { return(3, $return, undef, undef); } # Error connection
  # Compare local et remote file date
  my $strp2 = DateTime::Format::Strptime->new(pattern => '%a, %d %b %Y %T %Z');
  if (my $lastModifT = $strp2->parse_datetime($lastModifDate)) {
    my $cmp = DateTime->compare($localFileT, $lastModifT);
    if ($cmp > -1) { return(1, $return, $localFileT->ymd(), $lastModifT->ymd()); } # GeoIPDB is up to date 
    else           { return(2, $return, $localFileT->ymd(), $lastModifT->ymd()); } # GeoIPDB is outdated
  } else           { return(3, $return, undef             , undef             ); } # Connection error

}  #--- End checkDateGeoIPDB

#--------------------------#
sub downloadGeoIPDB
#--------------------------#
{
  # Local variables
  my ($localGeoIPDB, $USERDIR, $refHOURGLASS, $refARROW, $CONFIG_FILE, $refConfig,
			$refWinConfig, $refWinPb, $refWin, $refSTR) = @_;
  $localGeoIPDB = "$USERDIR\\GeoLiteCity.dat" if !$localGeoIPDB; # Default location
  # Start an agent
  my $ua = new LWP::UserAgent;
  $ua->agent($$refConfig{'USERAGENT'});
  $ua->default_header('Accept-Language' => 'en');
  # Set the progress bar
  $$refWin->ChangeCursor($$refHOURGLASS);
  $$refWinPb->Text($$refSTR{'Downloading'}.' '.$$refSTR{'GeoIPDB2'});
  $$refWinPb->lblPbCurr->Text($$refSTR{'connecting'}.' Maxmind...');
  $$refWinPb->lblCount->Text("0 %");
  $$refWinPb->pbWinPb->SetRange(0, 100);
  $$refWinPb->pbWinPb->SetPos(0);
  $$refWinPb->pbWinPb->SetStep(1);
  $$refWinPb->Center($$refWin);
  $$refWinPb->Show();
  # Check size of the remote file
  if (!$TOTAL_SIZE) {
    my $req    = new HTTP::Request HEAD => $GEOIPDB_URL;
    my $res    = $ua->request($req);
    my $return = $res->status_line;
    if ($res->code == 200) { $TOTAL_SIZE = $res->header('content_length'); }
    else {
      # Turn off progress bar
      $$refWin->ChangeCursor($$refARROW);
      $$refWinPb->lblPbCurr->Text('');
      $$refWinPb->lblCount->Text('');
      $$refWinPb->pbWinPb->SetPos(0);
      $$refWinPb->Hide();
      return("$$refSTR{'errorMsg'}: $$refSTR{'errorConRemote'}...");
    }
  }
  # Download the file
  if ($TOTAL_SIZE) {
    my $downloadData;
    # Download the file
    $$refWinPb->lblPbCurr->Text($$refSTR{'Downloading'}.' '.$$refSTR{'GeoIPDB2'}.'...');
    my $response = $ua->get($GEOIPDB_URL, ':content_cb' => sub {
      # Local variables
      my ($data, $response, $protocol) = @_;
      $downloadData       .= $data;                                     # Downloaded data
      my $totalDownloaded  = length($downloadData);                     # Size of downloaded data
      my $completed        = int($totalDownloaded / $TOTAL_SIZE * 100); # Pourcentage of download completed
      $$refWinPb->pbWinPb->SetPos($completed);    # Set the progress bar
      $$refWinPb->lblCount->Text("$completed %"); # Indicate purcentage
    });
    # Save data in a temp file
    my $GeoIPGZIP = $localGeoIPDB . '.gz';
    if ($response and $response->is_success) {
      open(GEOIPGZ,">$GeoIPGZIP");
      binmode(GEOIPGZ);
      print GEOIPGZ $downloadData;
      close(GEOIPGZ);
    }
    $downloadData = undef;
    # Uncompress GEOIP GZIP
    my ($error, $msg);
    if (-e $GeoIPGZIP) {
      $TOTAL_SIZE = 0;
      if (gunzip $GeoIPGZIP => $localGeoIPDB, BinModeOut => 1) {
        if (&validGeoIPDB($localGeoIPDB)) {
          unlink $GeoIPGZIP;
          $$refWinConfig->tfGeoIPDB->Text($localGeoIPDB);
          $$refConfig{'GEOIP_DB_FILE'} = $localGeoIPDB;
          &saveConfig($CONFIG_FILE, $refConfig);
        } else { $error = 1; $msg = "$$refSTR{'errorMsg'}: $$refSTR{'invalidFile'}"; }
      } else { $error = 1; $msg = "$$refSTR{'errorMsg'}: $GunzipError"; }
    } else { $error = 1; $msg = "$$refSTR{'errorMsg'}: $$refSTR{'errorDownload'}..."; }
    # Turn off progress bar
    $$refWin->ChangeCursor($$refARROW);
    $$refWinPb->lblPbCurr->Text('');
    $$refWinPb->lblCount->Text('');
    $$refWinPb->pbWinPb->SetPos(0);
    $$refWinPb->Hide();
    # Final message
    if ($error) { return($msg); } # Error
    else        { return(0);    }
  } else {
    # Turn off progress bar
    $$refWin->ChangeCursor($$refARROW);
    $$refWinPb->lblPbCurr->Text('');
    $$refWinPb->lblCount->Text('');
    $$refWinPb->pbWinPb->SetPos(0);
    $$refWinPb->Hide();
    return("$$refSTR{'errorMsg'}: $$refSTR{'errorDownload'}...");
  }
  $TOTAL_SIZE = 0;
  
}  #--- End downloadGeoIPDB

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
              or Win32::GUI::MessageBox($$refWin, $$refSTR{'errorConnectDB'}.$DBI::errstr, $$refSTR{'error'}, 0x40010);
    # Check if EXPR_HISTO_DB table exists
    my $sth;
    eval { $sth = $dbh->table_info(undef, undef, '%', 'TABLE'); };
    if ($@) {
      Win32::GUI::MessageBox($$refWin, $$refSTR{'errorConnectDB'}.$DBI::errstr, $$refSTR{'error'}, 0x40010);
      return(0);
    }
    my @info = $sth->fetchrow_array;
    $sth->finish();
    if ($info[2] eq 'EXPR_HISTO_DB') { # If table EXPR_HISTO_DB exists, than load data
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
    } else { Win32::GUI::MessageBox($$refWin, $$refSTR{'errorDB'}, $$refSTR{'error'}, 0x40010); return(0); }
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
										 or Win32::GUI::MessageBox($$refWin, $$refSTR{'errorConnectDB'}.$DBI::errstr, $$refSTR{'error'}, 0x40010);
    # Check if EXPR_DB table exists
    my $sth;
    eval { $sth = $dbh->table_info(undef, undef, '%', 'TABLE'); };
    if ($@) {
      Win32::GUI::MessageBox($$refWin, $$refSTR{'errorConnectDB'}.$DBI::errstr, $$refSTR{'error'}, 0x40010);
      return(0);
    }
    my @info = $sth->fetchrow_array;
    $sth->finish();
    if ($info[2] eq 'EXPR_DB') { # If table EXPR_DB exists, than load data
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
    } else { Win32::GUI::MessageBox($$refWin, $$refSTR{'errorDB'}, $$refSTR{'error'}, 0x40010); return(0); }
  } else { return(0); }

}  #--- End loadExprDB

#--------------------------#
sub validExprHistoDB
#--------------------------#
{
  # Local variables
  my $exprHistoDBFile = shift;
  if (-f $exprHistoDBFile) {
    # Connect to DB
		$exprHistoDBFile = encode('utf8', $exprHistoDBFile);
    my $dsn 				 = "DBI:SQLite:dbname=$exprHistoDBFile";
    if (my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 })) {
      my $sth;
      eval { $sth = $dbh->table_info(undef, undef, '%', 'TABLE'); };
      return(0) if $@;
      # If table EXPR_HISTO_DB exists, database is valid
      my @info = $sth->fetchrow_array;
      $sth->finish();
      return(1) if $info[2] eq 'EXPR_HISTO_DB';
    }
  }
  return(0);
  
}  #--- End validExprHistoDB

#--------------------------#
sub validExprDB
#--------------------------#
{
  # Local variables
  my $exprDBFile = shift;
  if (-f $exprDBFile) {
    # Connect to DB
		$exprDBFile = encode('utf8', $exprDBFile);
    my $dsn = "DBI:SQLite:dbname=$exprDBFile";
    if (my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 })) {
      my $sth;
      eval { $sth = $dbh->table_info(undef, undef, '%', 'TABLE'); };
      return(0) if $@;
      # If table EXPR_DB exists, database is valid
      my @info = $sth->fetchrow_array;
      $sth->finish();
      return(1) if $info[2] eq 'EXPR_DB';
    }
  }
  return(0);
  
}  #--- End validExprDB

#--------------------------#
sub validLFDB
#--------------------------#
{
  # Local variables
  my $LFDBFile = shift;
  if (-f $LFDBFile) {
    # Connect to DB
		$LFDBFile = encode('utf8', $LFDBFile);
    my $dsn 	= "DBI:SQLite:dbname=$LFDBFile";
    if (my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 })) {
      my $sth;
      eval { $sth = $dbh->table_info(undef, undef, '%', 'TABLE'); };
      return(0) if $@;
      # If table LF exists, database is valid
      my @info = $sth->fetchrow_array;
      $sth->finish();
      return(1) if $info[2] eq 'LF';
    }
  }
  return(0);
  
}  #--- End validLFDB

#--------------------------#
sub downloadLFDB
#--------------------------#
{
  # Local variables
  my ($localMACOUIDB, $USERDIR, $refHOURGLASS, $refARROW, $CONFIG_FILE, $refConfig,
			$refWinConfig, $refWinLFDB, $refWinLFObj, $refWinPb, $refWin, $refSTR) = @_;
  my $localLFDB = shift; # Default location
  # Show progress window
  $$refWin->ChangeCursor($$refHOURGLASS);
  $$refWinPb->Text($$refSTR{'downloadLFDB'});
  $$refWinPb->lblPbCurr->Text($$refSTR{'connecting'}.' le-tools.com...');
  $$refWinPb->lblCount->Text("0 %");
  $$refWinPb->pbWinPb->SetRange(0, 100);
  $$refWinPb->pbWinPb->SetPos(0);
  $$refWinPb->pbWinPb->SetStep(1);
  $$refWinPb->Center($$refWin);
  $$refWinPb->Show();
  # Start an agent
  my $ua = new LWP::UserAgent;
  $ua->agent($$refConfig{'USERAGENT'});
  $ua->default_header('Accept-Language' => 'en');
  # Check size of the remote file
  my $req    = new HTTP::Request HEAD => $LFDB_URL;
  my $res    = $ua->request($req);
  my $return = $res->status_line;
  if ($res->code == 200) { $TOTAL_SIZE = $res->header('content_length'); }
  else {
    # Hide progress window
    $$refWin->ChangeCursor($$refARROW);
    $$refWinPb->lblPbCurr->Text('');
    $$refWinPb->lblCount->Text('');
    $$refWinPb->pbWinPb->SetPos(0);
    $$refWinPb->Hide();
    return("$$refSTR{'errorMsg'}: $$refSTR{'errorConRemote'}...");
  }
  # Download the file
  if ($TOTAL_SIZE) {
    my $downloadData;
    # Download the file
    $$refWinPb->lblPbCurr->Text($$refSTR{'downloadLFDB'}.'...');
    my $response = $ua->get($LFDB_URL, ':content_cb' => sub {
      # Local variables
      my ($data, $response, $protocol) = @_;
      $downloadData       .= $data;                                     # Downloaded data
      my $totalDownloaded  = length($downloadData);                     # Size of downloaded data
      my $completed        = int($totalDownloaded / $TOTAL_SIZE * 100); # Pourcentage of download completed
      $$refWinPb->pbWinPb->SetPos($completed);    # Set the progress bar
      $$refWinPb->lblCount->Text("$completed %"); # Indicate purcentage
    });
    # Save data in a temp file
    my $LFDB_ZIP = $localLFDB."\.zip";
    if ($response and $response->is_success) {
      open(ZIP,">$LFDB_ZIP");
      binmode(ZIP);
      print ZIP $downloadData;
      close(ZIP);
    } else {
      # Hide progress window
      $$refWin->ChangeCursor($$refARROW);
      $$refWinPb->lblPbCurr->Text('');
      $$refWinPb->lblCount->Text('');
      $$refWinPb->pbWinPb->SetPos(0);
      $$refWinPb->Hide();
      return("$$refSTR{'errorMsg'}: $$refSTR{'errorConRemote'}...");
    }
    # Uncompress LFDB ZIP
    my ($error, $msg);
    if (-e $LFDB_ZIP) {
      $TOTAL_SIZE = 0;
      if (unzip $LFDB_ZIP => $localLFDB, BinModeOut => 1) {
        if (&validLFDB($localLFDB)) {
          unlink $LFDB_ZIP;
          $$refWinConfig->tfLFDB->Text($localLFDB);
          $$refConfig{'LF_DB_FILE'} = $localLFDB;
          &saveConfig($CONFIG_FILE, $refConfig);
          # Load the Log format database
					if (!$$refWinLFDB) {
						&createWinLFDB(0);
						&createWinLFObj() if !$$refWinLFObj;
					}
          &loadLFDB($localLFDB, $refWinLFDB, $refWin, $refSTR);
          &cbInputLFFormatAddITems();
          $$refWin->cbLF->SetCurSel(0);
        } else { $error = 1; $msg = "$$refSTR{'errorMsg'}: $$refSTR{'invalidFile'}"; }
      } else { $error = 1; $msg = "$$refSTR{'errorMsg'}: $UnzipError"; }
    } else { $error = 1; $msg = "$$refSTR{'errorMsg'}: $$refSTR{'errorDownload'}..."; }
    # Turn off progress bar
    $$refWin->ChangeCursor($$refARROW);
    $$refWinPb->lblPbCurr->Text('');
    $$refWinPb->lblCount->Text('');
    $$refWinPb->pbWinPb->SetPos(0);
    $$refWinPb->Hide();
    # Final message
    if ($error) { return($msg); } # Error
    else        { return(0);    }
  } else {
    # Hide progress window
    $$refWin->ChangeCursor($$refARROW);
    $$refWinPb->lblPbCurr->Text('');
    $$refWinPb->lblCount->Text('');
    $$refWinPb->pbWinPb->SetPos(0);
    $$refWinPb->Hide();
    return("$$refSTR{'errorMsg'}: $$refSTR{'errorDownload'}...");
  }

}  #--- End downloadLFDB

#--------------------------#
sub validXLWHOISDB
#--------------------------#
{
  # Local variables
  my $XLWHOISDBFile = shift;
  if (-f $XLWHOISDBFile) {
    # Connect to DB
		$XLWHOISDBFile = encode('utf8', $XLWHOISDBFile);
    my $dsn 			 = "DBI:SQLite:dbname=$XLWHOISDBFile";
    if (my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 })) {
      my $sth;
      eval { $sth = $dbh->table_info(undef, undef, '%', 'TABLE'); };
      return(0) if $@;
      # If table WHOIS_DB exists, database is valid
      my @info = $sth->fetchrow_array;
      $sth->finish();
      return(1) if $info[2] eq 'WHOIS_DB';
    }
  }
  return(0);
  
}  #--- End validXLWHOISDB

#--------------------------#
sub validIINDB
#--------------------------#
{
  # Local variables
  my $IINDBFile = shift;
  if (-f $IINDBFile) {
    # Connect to DB
    my $dsn = "DBI:SQLite:dbname=$IINDBFile";
    if (my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 })) {
      my $sth;
      eval { $sth = $dbh->table_info(undef, undef, '%', 'TABLE'); };
      return(0) if $@;
      # If table IIN exists, database is valid
      my @info = $sth->fetchrow_array;
      $sth->finish();
      return(1) if $info[2] eq 'IIN';
    }
  }
  return(0);
  
}  #--- End validIINDB

#--------------------------#
sub downloadIINDB
#--------------------------#
{
  # Local variables
  my ($localIINDB, $USERDIR, $refHOURGLASS, $refARROW, $CONFIG_FILE, $refConfig,
			$refWinConfig, $refWinPb, $refWin, $refSTR) = @_;
  # Show progress window
  $$refWin->ChangeCursor($$refHOURGLASS);
  $$refWinPb->Text($$refSTR{'Downloading'}.' '.$$refSTR{'IINLocalDB2'});
  $$refWinPb->lblPbCurr->Text($$refSTR{'connecting'}.' le-tools.com...');
  $$refWinPb->lblCount->Text("0 %");
  $$refWinPb->pbWinPb->SetRange(0, 100);
  $$refWinPb->pbWinPb->SetPos(0);
  $$refWinPb->pbWinPb->SetStep(1);
  $$refWinPb->Center($$refWin);
  $$refWinPb->Show();
  # Start an agent
  my $ua = new LWP::UserAgent;
  $ua->agent($$refConfig{'USERAGENT'});
  $ua->default_header('Accept-Language' => 'en');
  # Check size of the remote file
  my $req    = new HTTP::Request HEAD => $IINDB_URL;
  my $res    = $ua->request($req);
  my $return = $res->status_line;
  if ($res->code == 200) { $TOTAL_SIZE = $res->header('content_length'); }
  else {
    # Hide progress window
    $$refWin->ChangeCursor($$refARROW);
    $$refWinPb->lblPbCurr->Text('');
    $$refWinPb->lblCount->Text('');
    $$refWinPb->pbWinPb->SetPos(0);
    $$refWinPb->Hide();
    return("$$refSTR{'errorMsg'}: $$refSTR{'errorConRemote'}...");
  }
  # Download the file
  if ($TOTAL_SIZE) {
    my $downloadData;
    # Download the file
    $$refWinPb->lblPbCurr->Text($$refSTR{'Downloading'}.' '.$$refSTR{'IINLocalDB2'}.'...');
    my $response = $ua->get($IINDB_URL, ':content_cb' => sub {
      # Local variables
      my ($data, $response, $protocol) = @_;
      $downloadData       .= $data;                                     # Downloaded data
      my $totalDownloaded  = length($downloadData);                     # Size of downloaded data
      my $completed        = int($totalDownloaded / $TOTAL_SIZE * 100); # Pourcentage of download completed
      $$refWinPb->pbWinPb->SetPos($completed);    # Set the progress bar
      $$refWinPb->lblCount->Text("$completed %"); # Indicate purcentage
    });
    # Save data in a temp file
    my $IINDB_ZIP = $localIINDB."\.zip";
    if ($response and $response->is_success) {
      open(ZIP,">$IINDB_ZIP");
      binmode(ZIP);
      print ZIP $downloadData;
      close(ZIP);
    } else {
      # Hide progress window
      $$refWin->ChangeCursor($$refARROW);
      $$refWinPb->lblPbCurr->Text('');
      $$refWinPb->lblCount->Text('');
      $$refWinPb->pbWinPb->SetPos(0);
      $$refWinPb->Hide();
      return("$$refSTR{'errorMsg'}: $$refSTR{'errorConRemote'}...");
    }
    # Uncompress IINDB ZIP
    my ($error, $msg);
    if (-e $IINDB_ZIP) {
      $TOTAL_SIZE = 0;
      if (unzip $IINDB_ZIP => $localIINDB, BinModeOut => 1) {
        if (&validIINDB($localIINDB)) {
          unlink $IINDB_ZIP;
          $$refWinConfig->tfIINDB->Text($localIINDB);
          $$refConfig{'IIN_DB_FILE'} = $localIINDB;
          &saveConfig($CONFIG_FILE, $refConfig);
        } else { $error = 1; $msg = "$$refSTR{'errorMsg'}: $$refSTR{'invalidFile'}"; }
      } else { $error = 1; $msg = "$$refSTR{'errorMsg'}: $UnzipError"; }
    } else { $error = 1; $msg = "$$refSTR{'errorMsg'}: $$refSTR{'errorDownload'}..."; }
    # Turn off progress bar
    $$refWin->ChangeCursor($$refARROW);
    $$refWinPb->lblPbCurr->Text('');
    $$refWinPb->lblCount->Text('');
    $$refWinPb->pbWinPb->SetPos(0);
    $$refWinPb->Hide();
    # Final message
    if ($error) { return($msg); } # Error
    else        { return(0);    }
  } else {
    # Hide progress window
    $$refWin->ChangeCursor($$refARROW);
    $$refWinPb->lblPbCurr->Text('');
    $$refWinPb->lblCount->Text('');
    $$refWinPb->pbWinPb->SetPos(0);
    $$refWinPb->Hide();
    return("$$refSTR{'errorMsg'}: $$refSTR{'errorDownload'}...");
  }

}  #--- End downloadIINDB

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

#--------------------------#
sub updateTLDDB
#--------------------------#
{
  # Local variables
	my ($confirm, $VERSION, $localTLDDB, $refHOURGLASS, $refARROW, $CONFIG_FILE, $refConfig, $refWinConfig, $refWinPb, $refWin,
			$refSTR) = @_;
  my ($upToDate, $return, $dateLocalFile, $dateRemoteFile) = &checkDateTLDDB($confirm, $localTLDDB, $refConfig, $refWinConfig);
  # Values for $upToDate
  # 0: Whois Server Database doesn't exist  
  # 1: Database is up to date
  # 2: Database is outdated
  # 3: Error connection
  # 4: Unknown error

  # TLD Database is outdated or doesn't exist
  if (!$upToDate or $upToDate == 2) {
    my $msg;
    if ($dateLocalFile and $dateRemoteFile) {
      Encode::from_to($dateRemoteFile, 'utf8', 'iso-8859-1');
      $msg = "$$refSTR{'currDBDate'}: $dateLocalFile\n$$refSTR{'remoteDBDate'} publicsuffix.org: $dateRemoteFile\n\n$$refSTR{'updateAvailable'} ?";
    } else { $msg = "$$refSTR{'TLDDBNotExist'} ?"; }
    my $answer = Win32::GUI::MessageBox($$refWin, $msg, $$refSTR{'update3'}.' '.$$refSTR{'lblTLDDB'}, 0x1024);
    # Answer is No (7)
    if ($answer == 7) { return(0); }
    # Answer is Yes, download the update
    else { &downloadTLDDB(1, $VERSION, $localTLDDB, $refHOURGLASS, $refARROW, $CONFIG_FILE, $refConfig,
													$refWinConfig, $refWinPb, $refWin, $refSTR); }
  # TLDDB is up to date, show message if $confirm == 1
  } elsif ($upToDate == 1) {
    if ($confirm) {
      Encode::from_to($dateRemoteFile, 'utf8', 'iso-8859-1');
      Win32::GUI::MessageBox($$refWin, "$$refSTR{'currDBDate'}: $dateLocalFile\n$$refSTR{'remoteDBDate'} publicsuffix.org: ".
                                       "$dateRemoteFile\n\n$$refSTR{'DBUpToDate'} !", $$refSTR{'updateTLDDB'}, 0x40040);
    }
  # Connection error, show message if $confirm == 1
  } elsif (($upToDate == 3 or $upToDate == 4) and $confirm) {
    if ($upToDate == 3) { Win32::GUI::MessageBox($$refWin, "$$refSTR{'errConnection'}: $return", $$refSTR{'error'}, 0x40010); }
    else                { Win32::GUI::MessageBox($$refWin, "$$refSTR{'errUnknown'}: $return", $$refSTR{'error'}   , 0x40010); }
  }

}  #--- End updateTLDDB

#--------------------------#
sub checkDateTLDDB
#--------------------------#
{
  # Local variables
  my ($confirm, $localTLDDB, $refConfig, $refWinConfig) = @_;
  my $lastModifDate;
  # TLD Database doesn't exist or invalid file
  return(0, undef, undef, undef) if !$localTLDDB or !-f $localTLDDB;
  # Check date of local file
	my $localFileT  = DateTime->from_epoch(epoch => (stat($localTLDDB))[9]);
  # Check date of the remote file
  my $ua = new LWP::UserAgent;
  $ua->agent($$refConfig{'USERAGENT'});
  #$ua->timeout($CONFIG{'NSLOOKUP_TIMEOUT'});
  $ua->default_header('Accept-Language' => 'en');
  my $req    = new HTTP::Request HEAD => $TLDDB_URL;
  my $res    = $ua->request($req);
  my $return = $res->status_line;
  if ($res->code == 200) {
    $lastModifDate = $res->header('last-modified');
    $TOTAL_SIZE    = $res->header('content_length');
  } else { return(3, $return, undef, undef); } # Error connection
  # Compare local et remote file date
  my $strp2 = DateTime::Format::Strptime->new(pattern => '%a, %d %b %Y %T %Z');
  if (my $lastModifT = $strp2->parse_datetime($lastModifDate)) {
    my $cmp = DateTime->compare($localFileT, $lastModifT);
    if ($cmp > -1) { return(1, $return, $localFileT->ymd(), $lastModifT->ymd()); } # TLDDB is up to date 
    else           { return(2, $return, $localFileT->ymd(), $lastModifT->ymd()); } # TLDDB is outdated
  } else           { return(3, $return, undef             , undef             ); } # Connection error

}  #--- End checkDateTLDDB

#--------------------------#
sub downloadTLDDB
#--------------------------#
{
  # Local variables
  my ($confirm, $VERSION, $localTLDDB, $refHOURGLASS, $refARROW, $CONFIG_FILE, $refConfig, $refWinConfig,
			$refWinPb, $refWin, $refSTR) = @_;
	# If $confirm == 1, show status in a popup, else return status
  # Start an agent
  my $ua = new LWP::UserAgent;
  $ua->agent($$refConfig{'USERAGENT'});
  $ua->timeout($$refConfig{'NSLOOKUP_TIMEOUT'});
  $ua->default_header('Accept-Language' => 'en');
  # Set the progress bar
  $$refWin->ChangeCursor($$refHOURGLASS);
  $$refWinPb->lblPbCurr->Text($$refSTR{'connecting'}.' publicsuffix.org...');
  $$refWinPb->lblCount->Text("0 %");
  $$refWinPb->pbWinPb->SetRange(0, 100);
  $$refWinPb->pbWinPb->SetPos(0);
  $$refWinPb->pbWinPb->SetStep(1);
  $$refWinPb->Center($$refWin);
  $$refWinPb->Show();
  # Check size of the remote file
  if (!$TOTAL_SIZE) {
    my $req    = new HTTP::Request HEAD => $TLDDB_URL;
    my $res    = $ua->request($req);
    my $return = $res->status_line;
    if ($res->code == 200) { $TOTAL_SIZE = $res->header('content_length'); }
    else {
      # Turn off progress bar
      $$refWin->ChangeCursor($$refARROW);
      $$refWinPb->lblPbCurr->Text('');
      $$refWinPb->lblCount->Text('');
      $$refWinPb->pbWinPb->SetPos(0);
      &winPb_Terminate;
      if ($confirm) {
        Win32::GUI::MessageBox($$refWin, "$$refSTR{'errorMsg'}: $$refSTR{'errConnection'}...", $$refSTR{'error'}, 0x40010);
      } else { return($$refSTR{'errConnection'}); }
    }
  }
  # Download the file
  if ($TOTAL_SIZE) {
    my $downloadData;
    # Download the file
    $$refWinPb->Text($$refSTR{'Downloading'}.' '.$$refSTR{'lblTLDDB'}.'...');
    $$refWinPb->lblPbCurr->Text($$refSTR{'Downloading'}.' '.$$refSTR{'lblTLDDB'}.'...');
    my $response = $ua->get($TLDDB_URL, ':content_cb' => sub {
      # Local variables
      my ($data, $response, $protocol) = @_;
      $downloadData       .= $data;                                     # Downloaded data
      my $totalDownloaded  = length($downloadData);                     # Size of downloaded data
      my $completed        = int($totalDownloaded / $TOTAL_SIZE * 100); # Pourcentage of download completed
      $$refWinPb->pbWinPb->SetPos($completed);    # Set the progress bar
      $$refWinPb->lblCount->Text("$completed %"); # Indicate purcentage
    });
    # Save data in a file
    if ($response and $response->is_success) {
      open(TLDDB,">$localTLDDB");
      print TLDDB $downloadData;
      close(TLDDB);
    }
    $downloadData = undef;
    # Finished
    if (-T $localTLDDB) {
      # Turn off progress bar
      $$refWin->ChangeCursor($$refARROW);
      $$refWinPb->lblPbCurr->Text('');
      $$refWinPb->lblCount->Text('');
      $$refWinPb->pbWinPb->SetPos(0);
      &winPb_Terminate;
      # Update Config
      $$refWinConfig->tfTLDDB->Text($localTLDDB);
      $$refConfig{'TLD_DB_FILE'} = $localTLDDB;
      if ($confirm) {
        &saveConfig($CONFIG_FILE, $refConfig);
        Win32::GUI::MessageBox($$refWinConfig, $$refSTR{'updatedTLDDB'}, "XL-Parser $VERSION", 0x40040);
      }
    } else {
      # Turn off progress bar
      $$refWin->ChangeCursor($$refARROW);
      $$refWinPb->lblPbCurr->Text('');
      $$refWinPb->lblCount->Text('');
      $$refWinPb->pbWinPb->SetPos(0);
      &winPb_Terminate;
      if ($confirm) {
        Win32::GUI::MessageBox($$refWin, "$$refSTR{'errorMsg'}: $$refSTR{'errDownloadTLDDB'}...", $$refSTR{'error'}, 0x40010);
      } else { return($$refSTR{'errDownloadTLDDB'}); }
    }
  } else {
    # Turn off progress bar
    $$refWin->ChangeCursor($$refARROW);
    $$refWinPb->lblPbCurr->Text('');
    $$refWinPb->lblCount->Text('');
    $$refWinPb->pbWinPb->SetPos(0);
    &winPb_Terminate;
    if ($confirm) {
      Win32::GUI::MessageBox($$refWin, "$$refSTR{'errorMsg'}: $$refSTR{'errDownloadTLDDB'}...", $$refSTR{'error'}, 0x40010);
    } else { return($$refSTR{'errDownloadTLDDB'}); }
  }
  $TOTAL_SIZE = 0;
  
}  #--- End downloadTLDDB

#--------------------------#
sub validResTLDDB
#--------------------------#
{
  # Local variables
  my $resTLDDBFile = shift;
  if (-f $resTLDDBFile) {
    # Connect to DB
		$resTLDDBFile = encode('utf8', $resTLDDBFile);
    my $dsn 			= "DBI:SQLite:dbname=$resTLDDBFile";
    if (my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 })) {
      my $sth;
      eval { $sth = $dbh->table_info(undef, undef, '%', 'TABLE'); };
      return(0) if $@;
      # If table DATA exists, database is valid
      my @info = $sth->fetchrow_array;
      $sth->finish();
      return(1) if $info[2] eq 'DATA';
    }
  }
  return(0);
  
}  #--- End validResTLDDB

#--------------------------#
sub downloadResTLDDB
#--------------------------#
{
  # Local variables
  my ($localResTLDDB, $USERDIR, $refHOURGLASS, $refARROW, $CONFIG_FILE, $refConfig, $refWinConfig,
			$refWinPb, $refWin, $refSTR) = @_;
  # Show progress window
  $$refWin->ChangeCursor($$refHOURGLASS);
  $$refWinPb->Text($$refSTR{'Downloading'}.' '.$$refSTR{'ResTLDDB'});
  $$refWinPb->lblPbCurr->Text($$refSTR{'connecting'}.' le-tools.com...');
  $$refWinPb->lblCount->Text("0 %");
  $$refWinPb->pbWinPb->SetRange(0, 100);
  $$refWinPb->pbWinPb->SetPos(0);
  $$refWinPb->pbWinPb->SetStep(1);
  $$refWinPb->Center($$refWin);
  $$refWinPb->Show();
  # Start an agent
  my $ua = new LWP::UserAgent;
  $ua->agent($$refConfig{'USERAGENT'});
  $ua->default_header('Accept-Language' => 'en');
  # Check size of the remote file
  my $req    = new HTTP::Request HEAD => $RESTLDDB_URL;
  my $res    = $ua->request($req);
  my $return = $res->status_line;
  if ($res->code == 200) { $TOTAL_SIZE = $res->header('content_length'); }
  else {
    # Hide progress window
    $$refWin->ChangeCursor($$refARROW);
    $$refWinPb->lblPbCurr->Text('');
    $$refWinPb->lblCount->Text('');
    $$refWinPb->pbWinPb->SetPos(0);
    $$refWinPb->Hide();
    return("$$refSTR{'errorMsg'}: $$refSTR{'errorConRemote'}...");
  }
  # Download the file
  if ($TOTAL_SIZE) {
    my $downloadData;
    # Download the file
    $$refWinPb->lblPbCurr->Text($$refSTR{'Downloading'}.' '.$$refSTR{'ResTLDDB'}.'...');
    my $response = $ua->get($RESTLDDB_URL, ':content_cb' => sub {
      # Local variables
      my ($data, $response, $protocol) = @_;
      $downloadData       .= $data;                                     # Downloaded data
      my $totalDownloaded  = length($downloadData);                     # Size of downloaded data
      my $completed        = int($totalDownloaded / $TOTAL_SIZE * 100); # Pourcentage of download completed
      $$refWinPb->pbWinPb->SetPos($completed);    # Set the progress bar
      $$refWinPb->lblCount->Text("$completed %"); # Indicate purcentage
    });
    # Save data in a temp file
    my $resTLDDB_ZIP = $localResTLDDB."\.zip";
    if ($response and $response->is_success) {
      open(ZIP,">$resTLDDB_ZIP");
      binmode(ZIP);
      print ZIP $downloadData;
      close(ZIP);
    } else {
      # Hide progress window
      $$refWin->ChangeCursor($$refARROW);
      $$refWinPb->lblPbCurr->Text('');
      $$refWinPb->lblCount->Text('');
      $$refWinPb->pbWinPb->SetPos(0);
      $$refWinPb->Hide();
      return("$$refSTR{'errorMsg'}: $$refSTR{'errorConRemote'}...");
    }
    # Uncompress TLDDB ZIP
    my ($error, $msg);
    if (-e $resTLDDB_ZIP) {
      $TOTAL_SIZE = 0;
      if (unzip $resTLDDB_ZIP => $localResTLDDB, BinModeOut => 1) {
        if (&validResTLDDB($localResTLDDB)) {
          unlink $resTLDDB_ZIP;
          $$refWinConfig->tfResTLDDB->Text($localResTLDDB);
          $$refConfig{'RES_TLD_DB_FILE'} = $localResTLDDB;
          &saveConfig($CONFIG_FILE, $refConfig);
        } else { $error = 1; $msg = "$$refSTR{'errorMsg'}: $$refSTR{'invalidFile'}"; }
      } else { $error = 1; $msg = "$$refSTR{'errorMsg'}: $UnzipError"; }
    } else { $error = 1; $msg = "$$refSTR{'errorMsg'}: $$refSTR{'errorDownload'}..."; }
    # Turn off progress bar
    $$refWin->ChangeCursor($$refARROW);
    $$refWinPb->lblPbCurr->Text('');
    $$refWinPb->lblCount->Text('');
    $$refWinPb->pbWinPb->SetPos(0);
    $$refWinPb->Hide();
    # Final message
    if ($error) { return($msg); } # Error
    else        { return(0);    }
  } else {
    # Hide progress window
    $$refWin->ChangeCursor($$refARROW);
    $$refWinPb->lblPbCurr->Text('');
    $$refWinPb->lblCount->Text('');
    $$refWinPb->pbWinPb->SetPos(0);
    $$refWinPb->Hide();
    return("$$refSTR{'errorMsg'}: $$refSTR{'errorDownload'}...");
  }

}  #--- End downloadResTLDDB

#--------------------------#
sub validDTDB
#--------------------------#
{
  # Local variables
  my $DTDBFile = shift;
  if (-f $DTDBFile) {
    # Connect to DB
		$DTDBFile = encode('utf8', $DTDBFile);
    my $dsn 	= "DBI:SQLite:dbname=$DTDBFile";
    if (my $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1, AutoCommit => 1 })) {
      my $sth;
      eval { $sth = $dbh->table_info(undef, undef, '%', 'TABLE'); };
      return(0) if $@;
      # If table DT exists, database is valid
      my @info = $sth->fetchrow_array;
      $sth->finish();
      return(1) if $info[2] eq 'DT';
    }
  }
  return(0);
  
}  #--- End validDTDB

#--------------------------#
sub downloadDTDB
#--------------------------#
{
  # Local variables
  my ($localDTDB, $USERDIR, $refHOURGLASS, $refARROW, $CONFIG_FILE, $refConfig, $refWinConfig,
			$refWinLFObj, $refWinDTDB, $refWinReport, $refWinPb, $refWin, $refSTR) = @_;
	&createWinDTDB(0) if !$$refWinDTDB;
  # Show progress window
  $$refWin->ChangeCursor($$refHOURGLASS);
  $$refWinPb->Text($$refSTR{'Downloading'}.' '.$$refSTR{'winDTDB'});
  $$refWinPb->lblPbCurr->Text($$refSTR{'connecting'}.' le-tools.com...');
  $$refWinPb->lblCount->Text("0 %");
  $$refWinPb->pbWinPb->SetRange(0, 100);
  $$refWinPb->pbWinPb->SetPos(0);
  $$refWinPb->pbWinPb->SetStep(1);
  $$refWinPb->Center($$refWin);
  $$refWinPb->Show();
  # Start an agent
  my $ua = new LWP::UserAgent;
  $ua->agent($$refConfig{'USERAGENT'});
  $ua->default_header('Accept-Language' => 'en');
  # Check size of the remote file
  my $req    = new HTTP::Request HEAD => $DTDB_URL;
  my $res    = $ua->request($req);
  my $return = $res->status_line;
  if ($res->code == 200) { $TOTAL_SIZE = $res->header('content_length'); }
  else {
    # Hide progress window
    $$refWin->ChangeCursor($$refARROW);
    $$refWinPb->lblPbCurr->Text('');
    $$refWinPb->lblCount->Text('');
    $$refWinPb->pbWinPb->SetPos(0);
    $$refWinPb->Hide();
    return("$$refSTR{'errorMsg'}: $$refSTR{'errorConRemote'}...");
  }
  # Download the file
  if ($TOTAL_SIZE) {
    my $downloadData;
    # Download the file
    $$refWinPb->lblPbCurr->Text($$refSTR{'Downloading'}.' '.$$refSTR{'winDTDB'}.'...');
    my $response = $ua->get($DTDB_URL, ':content_cb' => sub {
      # Local variables
      my ($data, $response, $protocol) = @_;
      $downloadData       .= $data;                                     # Downloaded data
      my $totalDownloaded  = length($downloadData);                     # Size of downloaded data
      my $completed        = int($totalDownloaded / $TOTAL_SIZE * 100); # Pourcentage of download completed
      $$refWinPb->pbWinPb->SetPos($completed);    # Set the progress bar
      $$refWinPb->lblCount->Text("$completed %"); # Indicate purcentage
    });
    # Save data in a temp file
    my $DTDB_ZIP = $localDTDB."\.zip";
    if ($response and $response->is_success) {
      open(ZIP,">$DTDB_ZIP");
      binmode(ZIP);
      print ZIP $downloadData;
      close(ZIP);
    } else {
      # Hide progress window
      $$refWin->ChangeCursor($$refARROW);
      $$refWinPb->lblPbCurr->Text('');
      $$refWinPb->lblCount->Text('');
      $$refWinPb->pbWinPb->SetPos(0);
      $$refWinPb->Hide();
      return("$$refSTR{'errorMsg'}: $$refSTR{'errorConRemote'}...");
    }
    # Uncompress DTDB ZIP
    my ($error, $msg);
    if (-e $DTDB_ZIP) {
      $TOTAL_SIZE = 0;
      if (unzip $DTDB_ZIP => $localDTDB, BinModeOut => 1) {
        if (&validDTDB($localDTDB)) {
          unlink $DTDB_ZIP;
          $$refWinConfig->tfDTDB->Text($localDTDB);
          $$refConfig{'DT_DB_FILE'} = $localDTDB;
          &saveConfig($CONFIG_FILE, $refConfig);
          # Load the Datetime database
          &loadDTDB;
          &cbInputDTFormatAddITems();
          $$refWinLFObj->cbLFObjDT->SetCurSel(0);
          $$refWin->cbSplitTimeFormat->SetCurSel(0);
          &cbOutputDTFormatAddITems();
          $$refWinReport->cbOutputDTFormat->SetCurSel(0);
        } else { $error = 1; $msg = "$$refSTR{'errorMsg'}: $$refSTR{'invalidFile'}"; }
      } else { $error = 1; $msg = "$$refSTR{'errorMsg'}: $UnzipError"; }
    } else { $error = 1; $msg = "$$refSTR{'errorMsg'}: $$refSTR{'errorDownload'}..."; }
    # Turn off progress bar
    $$refWin->ChangeCursor($$refARROW);
    $$refWinPb->lblPbCurr->Text('');
    $$refWinPb->lblCount->Text('');
    $$refWinPb->pbWinPb->SetPos(0);
    $$refWinPb->Hide();
    # Final message
    if ($error) { return($msg); } # Error
    else        { return(0);    }
  } else {
    # Hide progress window
    $$refWin->ChangeCursor($$refARROW);
    $$refWinPb->lblPbCurr->Text('');
    $$refWinPb->lblCount->Text('');
    $$refWinPb->pbWinPb->SetPos(0);
    $$refWinPb->Hide();
    return("$$refSTR{'errorMsg'}: $$refSTR{'errorDownload'}...");
  }

}  #--- End downloadDTDB

#------------------------------------------------------------------------------#
1;