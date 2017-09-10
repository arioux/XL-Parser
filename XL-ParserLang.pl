#!/usr/bin/perl
# Perl - v: 5.16.3
#------------------------------------------------------------------------------#
# XL-ParserLang.pl  : Strings for XL-Parser
# Website     			: http://le-tools.com/XL-Parser.html
# SourceForge				: https://sourceforge.net/p/xl-parser
# GitHub						: https://github.com/arioux/XL-Parser
# Creation          : 2016-07-15
# Modified          : 2017-09-10
# Author            : Alain Rioux (admin@le-tools.com)
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

#------------------------------------------------------------------------------#
sub loadStr
#------------------------------------------------------------------------------#
{
  # Local variables
  my ($refSTR, $LANG_FILE) = @_;
  # Open and load string values
  open(LANG, $LANG_FILE);
  my @tab = <LANG>;
  close(LANG);
  # Store values  
  foreach (@tab) {
    chomp($_);
    s/[^\w\=\s\.\!\,\-\)\(\']//g;
    my ($key, $value) = split(/ = /, $_);
    $value            = encode('cp1252', $value); # Encode
    $$refSTR{$key}    = $value if $key;
  }
  
}  #--- End loadStr

#------------------------------------------------------------------------------#
sub loadDefaultStr
#------------------------------------------------------------------------------#
{
  # Local variables
  my $refSTR = shift;
  # Set default strings
  # General strings
  $$refSTR{'processRunning'}  = 'Running process';
  $$refSTR{'Options'}         = 'Options';
  $$refSTR{'report'}          = 'report';
  $$refSTR{'selDir'}          = 'Select a folder';
  $$refSTR{'selFiles'}        = 'Select one or multiple files';
  $$refSTR{'selDirReport'}    = 'Select a folder for the report';
  $$refSTR{'selDirDst'}       = 'Select a destination folder';
  $$refSTR{'selFile'}         = 'Select a file';
  $$refSTR{'Filename'}        = 'Filename';
  $$refSTR{'Extension'}       = 'Extension';
  $$refSTR{'Object'}          = 'Object';
  $$refSTR{'Count'}           = 'Count';
  $$refSTR{'Case'}            = 'Match case';
  $$refSTR{'Regex'}           = 'Regex';
  $$refSTR{'Invert'}          = 'Invert';
  $$refSTR{'Include'}         = 'Include';
  $$refSTR{'Resolve'}         = 'Resolve';
  $$refSTR{'To'}              = 'to';
  $$refSTR{'Yes'}             = 'Yes';
  $$refSTR{'No'}              = 'No';
  $$refSTR{'Ok'}              = 'Ok';
  $$refSTR{'Go'}              = 'Go';
  $$refSTR{'Edit'}            = 'Edit';
  $$refSTR{'used'}            = 'Used';
  $$refSTR{'Date'}            = 'Date';
  $$refSTR{'monday'}          = 'Monday';
  $$refSTR{'tuesday'}         = 'Tuesday';
  $$refSTR{'wednesday'}       = 'Wednesday';
  $$refSTR{'thursday'}        = 'Thursday';
  $$refSTR{'friday'}          = 'Friday';
  $$refSTR{'saturday'}        = 'Saturday';
  $$refSTR{'sunday'}          = 'Sunday';
  $$refSTR{'Type'}            = 'Type';
  $$refSTR{'Name'}            = 'Name';
  $$refSTR{'lines'}           = 'lines';
  $$refSTR{'country'}         = 'Country';
  $$refSTR{'countryCode'}     = 'Country code';
  $$refSTR{'region'}          = 'Region';
  $$refSTR{'regionCode'}      = 'Region code';
  $$refSTR{'city'}            = 'City';
  $$refSTR{'postalCode'}      = 'Postal code';
  $$refSTR{'GPScoord'}        = 'GPS coordinates';
  $$refSTR{'tzName'}          = 'Timezone name';
  $$refSTR{'tzOffset'}        = 'Timezone offset';
  $$refSTR{'uaOS'}            = 'OS';
  $$refSTR{'uaBrowser'}       = 'Browser';
  $$refSTR{'uaDevice'}        = 'Device';
  $$refSTR{'uaLang'}          = 'Lang';
  $$refSTR{'brand'}           = 'Brand';
  $$refSTR{'subBrand'}        = 'Sub Brand';
  $$refSTR{'bank'}            = 'Bank';
  $$refSTR{'cardType'}        = 'Card Type';
  $$refSTR{'cardCategory'}    = 'Card Category';
  $$refSTR{'countryName'}     = 'Country Name';
  $$refSTR{'ListingFile'}     = 'Listing files in';
  $$refSTR{'PreProcessing'}   = 'Pre-processing';
  $$refSTR{'Processing'}      = 'Processing';
  $$refSTR{'Searching'}       = 'Searching';
  $$refSTR{'Copying'}         = 'Copying';
  $$refSTR{'Splitting'}       = 'Splitting';
  $$refSTR{'Deleting'}        = 'Deleting';
  $$refSTR{'Downloading'}     = 'Downloading';
  $$refSTR{'Updating'}        = 'Updating';
  $$refSTR{'Reading'}         = 'Reading';
  $$refSTR{'Creating'}        = 'Creating';
  $$refSTR{'Parsing'}         = 'Parsing';
  $$refSTR{'Hashing'}         = 'Hashing';
  $$refSTR{'WritingReport'}   = 'Writing report';
  $$refSTR{'connecting'}      = 'Connecting to';
  $$refSTR{'Started'}         = 'started';
  $$refSTR{'Finished'}        = 'finished';
  $$refSTR{'cancel'}          = 'Cancel';
  $$refSTR{'Close'}           = 'Close';
  $$refSTR{'Select'}          = 'Select';
  $$refSTR{'Export'}          = 'Export';
  $$refSTR{'Delete'}          = 'Delete';
  $$refSTR{'Enable'}          = 'Enable';
  $$refSTR{'cancelled'}       = 'cancelled';
  $$refSTR{'completed'}       = 'The extraction have been completed!';
  $$refSTR{'noResult'}        = 'No result.';
  # Error
  $$refSTR{'error'}           = 'Error';
  $$refSTR{'EndErrors'}       = 'error(s)';
  $$refSTR{'moreFormatMatch'} = 'More than one match.';
  $$refSTR{'formatNotFound'}  = 'Format not found';
  $$refSTR{'invalidFile'}     = 'File is invalid';
  $$refSTR{'invalidDir'}      = 'Folder is invalid';
  $$refSTR{'invalidParams'}   = 'Invalid parameters';
  $$refSTR{'errorReading'}    = 'Error reading';
  $$refSTR{'errorOpening'}    = 'Error opening';
  $$refSTR{'errorWriting'}    = 'Error writing';
  $$refSTR{'errorConnecting'} = 'Error connecting';
  $$refSTR{'errorCopying'}    = 'Error copying';
  $$refSTR{'warning'}         = 'Warning';
  $$refSTR{'maxSizeReached'}  = 'Maximum number of characters has been reached. Your text may have been truncated.';
  $$refSTR{'processRunning'}  = 'A process is already running. Wait until it stops or restart the program.';
  $$refSTR{'errorMsg'}        = 'Error messsage';
  $$refSTR{'noInput'}         = 'No input';
  $$refSTR{'noFile'}          = 'No file for the process!';
  $$refSTR{'errorConversion'} = 'Conversion error';
  $$refSTR{'errorConnection'} = 'Connection error';
  $$refSTR{'invalidInput'}    = 'Invalid input';
  $$refSTR{'noMatch'}         = 'No match';
  $$refSTR{'errorDB'}         = 'Error database';
  $$refSTR{'errorConnectDB'}  = 'Error connecting to database';
  $$refSTR{'errorConRemote'}  = 'Error connecting to remote site';
  $$refSTR{'errorDownload'}   = 'Error downloading the database';
  $$refSTR{'errorCreatingDB'} = 'Error creating the database';
  $$refSTR{'errLoadingDB'}    = 'Error loading database.';
  $$refSTR{'errUpdatingDB'}   = 'Error updating database: ';
  $$refSTR{'errEntryExists'}  = 'Entry exists in database';
  $$refSTR{'errorUnzip'}      = 'Error uncompressing file';
  $$refSTR{'selectedCF'}      = 'Selected custom function';
  $$refSTR{'unknownError'}    = 'Unknown error';
  $$refSTR{'errorOUI_TXT'}    = 'Error with oui.txt file';
  $$refSTR{'errRegex'}        = 'You must enter a valid regex.';
  $$refSTR{'errBy'}           = 'You must enter a valid replacement expression.';
  $$refSTR{'errQuery'}        = 'You must enter a valid query. Error in your query';
  $$refSTR{'errQuote'}        = 'Value could not contain a quote.';
  $$refSTR{'errRegexReplace'} = 'Current error in * Replace *';
  $$refSTR{'errRegexReplaceBy'} = 'Current error in * By *';
  $$refSTR{'errNewLine'}      = 'Error creating new line in grid.';
  $$refSTR{'errSpace'}        = 'There is not enough space on the choosen destination folder.';
  $$refSTR{'warnLookup'}      = 'Nslookup requires an active internet connection. Based on the number of results, it might take a while. You should use this with caution.';
  $$refSTR{'dbExists'}        = 'Database exists in the destination folder, replace it';
  $$refSTR{'errDBFilePath'}   = 'File does not match the database';
  # Main Window
  $$refSTR{'rbInputDir'}         = 'Dir';
  $$refSTR{'chInputDirRecurse'}  = 'Subfolders';
  $$refSTR{'rbInputFiles'}       = 'File(s)';
  $$refSTR{'rbInputClipboard'}   = 'Clipboard';
  $$refSTR{'rbInputDatabase'}    = 'Database';
  # Filters section
  $$refSTR{'FileFilters'}        = 'File Filters';
  $$refSTR{'filterAddTip'}       = 'Add filter';
  $$refSTR{'filterDelTip'}       = 'Delete filter(s)';
  $$refSTR{'filterImportTip'}    = 'Import from file';
  $$refSTR{'filterSaveTip'}      = 'Save current filters in a file';
  $$refSTR{'lblFunctionsT'}      = 'Functions';
  $$refSTR{'btnFormatSetTip'}    = 'Set file format(s)';
  # File Formats
  $$refSTR{'FileFormats'}        = 'File Formats';
  $$refSTR{'Format'}             = 'Format';
  $$refSTR{'FileExtension'}      = 'File extension(s)';
  $$refSTR{'PlainText'}          = 'Plain text';
  $$refSTR{'Unicode'}            = 'Unicode';
  $$refSTR{'AnyASCII'}           = 'Any ASCII';
  $$refSTR{'Other'}              = 'Other';
  $$refSTR{'FileType'}           = 'File type';
  $$refSTR{'chFiltersUseMSWord'} = 'Use MS Word for parsing';
  $$refSTR{'setDate'}             = 'You must enter dates with valid format for this filter.';
  $$refSTR{'setExtList'}          = 'You must enter at least one extension for this filter.';
  # Functions section
  $$refSTR{'Extraction'}          = 'Extraction';
  $$refSTR{'WebLogAnalysis'}      = 'Web log analysis';
  $$refSTR{'SplitLogs'}           = 'Split logs';
  # Expression
  $$refSTR{'Expression'}          = 'Expressions';
  $$refSTR{'SpecObjects'}         = 'Special objects';
  $$refSTR{'Results'}             = 'Results';
  $$refSTR{'extractAddTip'}       = 'Add object to extract';
  $$refSTR{'extractDelTip'}       = 'Delele object(s)';
  $$refSTR{'ExprSaveTip'}         = 'Save current expressions in a file';
  # Special objects
  $$refSTR{'SO_IPv4Addr'}         = 'IPv4 Addresses';
  $$refSTR{'SO_IPv6Addr'}         = 'IPv6 Addresses';
  $$refSTR{'SO_URLs'}             = 'URLs';
  $$refSTR{'SO_Emails'}           = 'Emails';
  $$refSTR{'SO_Hostnames'}        = 'Hostnames';
  $$refSTR{'SO_DomainNames'}      = 'Domain names';
  $$refSTR{'SO_MACAddr'}          = 'MAC Addresses';
  $$refSTR{'SO_CreditCards'}      = 'Credit cards';
  $$refSTR{'SO_NSLookup'}         = 'NS Lookup';
  $$refSTR{'SO_ResolveTLD'}       = 'Resolve TLD';
  $$refSTR{'SO_URL_RemParam'}     = 'Remove parameters';
  $$refSTR{'SO_IPAddr_XLWhoisDB'} = 'Resolve ISP (Whois DB)';
  $$refSTR{'SO_GeoIP'}            = 'Resolve GeoIP';
  $$refSTR{'SO_Emails_Valid'}     = 'Validate email domain';
  $$refSTR{'SO_MACAddr_ResOUI'}   = 'Resolve MAC Address OUI';
  $$refSTR{'SO_CC_ResIC'}         = 'Resolve Issuing company';
  $$refSTR{'SO_addTip'}           = 'Add object or options';
  $$refSTR{'SO_remTip'}           = 'Remove object or option';
  $$refSTR{'lblNotReady'}         = 'Not Ready? Click here';
  $$refSTR{'notReady'}            = 'Not ready';
  $$refSTR{'nextStep'}            = 'Next step';
  $$refSTR{'selectInput'}         = 'You must select a valid input.';
  $$refSTR{'selectReportDir'}     = 'You must select a folder for report.';
  $$refSTR{'setExpr'}             = 'You must set at least one expression to extract.';
  $$refSTR{'setSO'}               = 'You must select at least one object to extract.';
  $$refSTR{'splitLogsBadInput'}   = 'For this function, input must be a file(s) or a folder';
  $$refSTR{'setDestFileSize'}     = 'You must set the destination file size';
  $$refSTR{'setNbrLines'}         = 'You must enter a number of lines';
  $$refSTR{'setInputDTFormat'}    = 'You must select a datetime format';
  $$refSTR{'setDestDir'}          = 'You must set a destination folder.';
  $$refSTR{'setLogFormat'}        = 'You must select a log format.';
  $$refSTR{'setSQLQuery'}         = 'You must set or select a SQL Query.';
  # Results
  $$refSTR{'ResStats'}            = 'Stats';
  $$refSTR{'ResStatsFiles'}       = 'Files';
  $$refSTR{'ResStatsLines'}       = 'Lines';
  $$refSTR{'ResStatsDuration'}    = 'Duration';
  $$refSTR{'Size'}                = 'Size';
  $$refSTR{'b2'}                  = 'b';
  $$refSTR{'Kb2'}                 = 'Kb';
  $$refSTR{'Mb2'}                 = 'Mb';
  $$refSTR{'Gb2'}                 = 'Gb';
  $$refSTR{'ResStatsEntries'}     = 'Number of entries';
  $$refSTR{'ResStatsTimeElapsed'} = 'Time elapsed';
  $$refSTR{'ResStatsTimeLeft'}    = 'Estimated time left';
  $$refSTR{'rbResByExpr'}         = 'By expression';
  $$refSTR{'rbResByObject'}       = 'By object';
  $$refSTR{'openFile'}            = 'Open file(s)';
  $$refSTR{'copyFile'}            = 'Copy file(s)';
  $$refSTR{'showResults'}         = 'Show results for selected item(s)';
  $$refSTR{'NoDuplicates'}        = 'No duplicates';
  $$refSTR{'ResultsOnly'}         = 'Results only';
  $$refSTR{'selectAll'}           = 'Select all';
  $$refSTR{'copySelRow'}          = 'Copy selected row(s)';
  # Log Analysis
  $$refSTR{'createDB'}            = 'Create';
  $$refSTR{'updateDB'}            = 'Update database';
  $$refSTR{'QueryDB'}             = 'Query database';
  $$refSTR{'SearchSA'}            = 'Suspicious activities';
  $$refSTR{'CurrentDatabase'}     = 'Current database';
  $$refSTR{'rbDestDBCurr'}        = 'Update current database';
  $$refSTR{'rbDestDBNew'}         = 'Create a new one';
  $$refSTR{'selectFilters'}       = 'Select Filters';
  $$refSTR{'Filter'}              = 'Filter';
  $$refSTR{'LAFileOrder'}         = 'File order';
  $$refSTR{'SortingFiles'}        = 'Sorting files';
  $$refSTR{'Weekday'}             = 'Weekday';
  $$refSTR{'openLFDB'}            = 'Open the Log format database';
  $$refSTR{'chLASelectDB'}        = 'Select database when finished';
  $$refSTR{'updatedDB'}           = 'The database has been updated';
  $$refSTR{'Category'}            = 'Category';
  $$refSTR{'lblCurrDBLastUpdate'} = 'Last update';
  $$refSTR{'lblCurrDBPeriod'}     = 'Period';
  $$refSTR{'NumberOf'}            = 'Number of';
  $$refSTR{'lblCurrDBRejected'}   = 'Rejected';
  $$refSTR{'lblCurrDBFiltered'}   = 'Filtered';
  $$refSTR{'Filters'}             = 'Filter(s)';
  $$refSTR{'Resolved'}            = 'Resolved';
  $$refSTR{'Useragent'}           = 'Useragent';
  $$refSTR{'Weekdays'}            = 'Weekdays';
  $$refSTR{'lblCurrDBNbrResISP'}  = 'Resolved ISP';
  $$refSTR{'lblCurrDBNbrResGeoIP'} = 'Resolved GeoIP';
  $$refSTR{'lblCurrDBResUAs'}     = 'Resolved UAs';
  $$refSTR{'lblCurrDBResWDs'}     = 'Resolved Weekdays';
  $$refSTR{'curSel'}              = 'Current selection';
  $$refSTR{'All'}                 = 'All';
  $$refSTR{'applyFilters'}        = 'Apply filters';
  $$refSTR{'applyFiltersIP'}      = 'Remove useless IP addresses details';
  $$refSTR{'applyFiltersUA'}      = 'Remove useless useragent details';
  $$refSTR{'getDBInfos'}          = 'Gather updated infos about database';
  $$refSTR{'copyDB'}              = 'Copy database';
  $$refSTR{'resUA'}               = 'Resolve User-agent';
  $$refSTR{'resWeekday'}          = 'Resolve Weekday';
  $$refSTR{'updDBInfos'}          = 'Update database infos';
  $$refSTR{'chLASetReadOnly'}     = 'Set source files to readonly';
  $$refSTR{'chLALogFiltered'}     = 'Log filtered lines';
  $$refSTR{'chLALogRejected'}     = 'Log rejected lines';
  $$refSTR{'chLAIgnoreComments'}  = 'Ignore comments';
  $$refSTR{'curTask'}             = 'Current task';
  $$refSTR{'Query'}               = 'Query';
  $$refSTR{'SelectColumn'}        = 'Select columns';
  $$refSTR{'Columns'}             = 'Columns';
  $$refSTR{'savedQueriesDB'}      = 'Saved queries database';
  $$refSTR{'SelectSaved'}         = 'Select saved';
  $$refSTR{'Save'}                = 'Save';
  $$refSTR{'Reset'}               = 'Reset';
  $$refSTR{'noColumnSel'}         = 'You must select at least one column.';
  $$refSTR{'SavedQuery'}          = 'The query has been saved';
  $$refSTR{'ExecQuery'}           = 'Execute query and create report';
  $$refSTR{'byIPS'}               = 'By IP address';
  $$refSTR{'Activities'}          = 'Activities only';
  $$refSTR{'SaveResults'}         = 'Save results';
  $$refSTR{'SavingResults'}       = 'Saving results';
  $$refSTR{'ResultsSaved'}        = 'Results have been saved';
  $$refSTR{'Indicators'}          = 'Indicators';
  $$refSTR{'Indicator'}           = 'Indicator';
  $$refSTR{'SDSAI1'}              = 'High number of requests';
  $$refSTR{'SDSAI2a'}             = 'Request length (nbr)';
  $$refSTR{'SDSAI2b'}             = 'Request length (max)';
  $$refSTR{'SDSAI3'}              = 'URI Encoding';
  $$refSTR{'SDSAI4'}              = 'HTTP Method';
  $$refSTR{'SDSAI5'}              = 'High number of errors';
  $$refSTR{'SDSAI6'}              = 'SQL query';
  $$refSTR{'SDSAI7'}              = 'Use of quotes';
  $$refSTR{'SDSAI8'}              = 'Directory traversal';
  $$refSTR{'SDSAI9'}              = 'Remote file inclusion';
  $$refSTR{'SDSAI10'}             = 'Admin or login scan';
  $$refSTR{'SDSAI11'}             = 'Web scanner';
  $$refSTR{'SDSAI12'}             = 'No useragent';
  $$refSTR{'SDSAI13'}             = 'Many useragents';
  $$refSTR{'LimitInd'}            = 'Limit';
  $$refSTR{'SaveOptions'}         = 'Save options';
  $$refSTR{'SavedOptions'}        = 'The options have been saved.';
  $$refSTR{'OpenResults'}         = 'Load results';
  $$refSTR{'LoadingResults'}      = 'Loading results';
  $$refSTR{'RefreshFL'}           = 'Rebuild list of files';
  $$refSTR{'MaxResults'}          = 'Max results';
  $$refSTR{'selectIndicator'}     = 'You must select at least one indicator with score and limit not null';
  $$refSTR{'Score'}               = 'Score';
  $$refSTR{'SA_GetRequests'}      = 'Get requests from selected IP(s)';
  $$refSTR{'SA_GetUA'}            = 'Get useragent(s) for selected IP(s)';
  $$refSTR{'SA_ResIPs'}           = 'Resolve/update all IPs (add columns)';
  $$refSTR{'SA_GetUnknownIPs'}    = 'Send unknown IPs to clipboard (ISP)';
  $$refSTR{'SA_GetReqInd'}        = 'Get requests for selected indicator(s)';
  # Split
  $$refSTR{'BySize'}              = 'By file size';
  $$refSTR{'lblSplitBySize'}      = 'Destination file size';
  $$refSTR{'chSplitUseDTFN'}      = 'Use datetime in filename';
  $$refSTR{'ByNbrLines'}          = 'By number of lines';
  $$refSTR{'lblSplitByLinesNbr'}  = 'Number of lines';
  $$refSTR{'ByTime'}              = 'By time';
  $$refSTR{'lblSplitByTime'}      = 'Time interval';
  $$refSTR{'ByHour'}              = 'By hour';
  $$refSTR{'ByDay'}               = 'By day';
  $$refSTR{'ByWeek'}              = 'By week';
  $$refSTR{'ByMonth'}             = 'By month';
  $$refSTR{'lblSplitTimeFormat'}  = 'Time format';
  $$refSTR{'selectDTFormat'}      = 'Select a format';
  $$refSTR{'destination'}         = 'Destination';
  $$refSTR{'destDir'}             = 'Destination folder';
  $$refSTR{'chOpenDstDir'}        = 'Open folder when finished';
  # Footer
  $$refSTR{'Process'}             = 'Process';
  $$refSTR{'StopProcess'}         = 'Stop process';
  $$refSTR{'Configuration'}       = 'Open Settings Window';
  $$refSTR{'btnHelpTip'}          = 'See Documentation';
  # Filters Window
  $$refSTR{'Operator'}            = 'Operator';
  $$refSTR{'OR'}                  = 'OR';
  $$refSTR{'AND'}                 = 'AND';
  $$refSTR{'TypeOp'}              = 'Type Operator';
  $$refSTR{'flags'}               = 'Flags';
  $$refSTR{'searchStr'}           = 'Search';
  $$refSTR{'rbFiltersSize'}       = 'File size';
  $$refSTR{'FilenameOnly'}        = 'Filename only';
  $$refSTR{'rbFiltersLastAccess'} = 'Last accessed';
  $$refSTR{'rbFiltersLastModif'}  = 'Last modified';
  $$refSTR{'Smaller'}             = 'Smaller than';
  $$refSTR{'Equal'}               = 'Equal to';
  $$refSTR{'Bigger'}              = 'Bigger than';
  $$refSTR{'b'}                   = 'Bytes';
  $$refSTR{'Kb'}                  = 'Kbytes';
  $$refSTR{'Mb'}                  = 'Mbytes';
  $$refSTR{'Gb'}                  = 'Gbytes';
  $$refSTR{'Before'}              = 'Before';
  $$refSTR{'After'}               = 'After';
  $$refSTR{'setContains'}         = 'You must enter a keyword or regex for this filter.';
  $$refSTR{'setFileSize'}         = 'You must enter a valid file size for this filter.';
  $$refSTR{'SetAddFilter'}        = 'Add or Edit';
  # Extraction Window
  $$refSTR{'cbLExtractREShorcuts'}    = 'Regex shortcuts';
  $$refSTR{'REShorcuts1'}             = 'Any character';
  $$refSTR{'REShorcuts2'}             = 'A decimal digit';
  $$refSTR{'REShorcuts3'}             = 'Not a decimal digit';
  $$refSTR{'REShorcuts4'}             = 'An alphanumeric';
  $$refSTR{'REShorcuts5'}             = 'Not an alphanumeric';
  $$refSTR{'REShorcuts6'}             = 'A white space';
  $$refSTR{'REShorcuts7'}             = 'Not a white space';
  $$refSTR{'REShorcuts8'}             = 'A tabulation';
  $$refSTR{'REShorcuts9'}             = 'A carriage return';
  $$refSTR{'REShorcuts10'}            = 'A newline';
  $$refSTR{'REShorcuts11'}            = 'A character class';
  $$refSTR{'REShorcuts12'}            = 'A character class (negative)';
  $$refSTR{'REShorcuts13'}            = 'A group to capture';
  $$refSTR{'REShorcuts14'}            = 'A group (no capture)';
  $$refSTR{'REShorcuts15'}            = 'Alternation';
  $$refSTR{'REShorcuts16'}            = 'Beginning of the line';
  $$refSTR{'REShorcuts17'}            = 'End of the line';
  $$refSTR{'REShorcuts18'}            = '0 or more times';
  $$refSTR{'REShorcuts19'}            = '1 or more times';
  $$refSTR{'REShorcuts20'}            = '0 or 1 time';
  $$refSTR{'REShorcuts21'}            = 'Exactly n times';
  $$refSTR{'REShorcuts22'}            = 'At least n times';
  $$refSTR{'REShorcuts23'}            = 'n to m times';
  $$refSTR{'btnExtractExprAddDBTip'}  = 'Add expression to database';
  $$refSTR{'btnExtractExprSaveDBTip'} = 'Save changes to database';
  $$refSTR{'btnExtractExprToolsTip'}  = 'Open regex tool window';
  $$refSTR{'exprHistoAndDB'}          = 'Expression history and database';
  $$refSTR{'exprHistory'}             = 'Expression history';
  $$refSTR{'exprDatabase'}            = 'Expression database';
  $$refSTR{'lblExprHistoryMax'}       = 'Maximum history';  
  $$refSTR{'addedExprDB'}             = 'Expression has been added to expression database';
  $$refSTR{'editedExprDB'}            = 'Expression has been edited in expression database';
  $$refSTR{'exprHistoAddToDB'}        = 'Add to Expression Database';
  $$refSTR{'sendToExprTool'}          = 'Send to Expression tool';
  $$refSTR{'addingEntries'}           = 'Adding entries...';
  $$refSTR{'deletingEntries'}         = 'Deleting entries...';
  # Expression Extraction Options Window
  $$refSTR{'winExprOpt'}              = 'Extraction options';
  $$refSTR{'chExprOptNoDuplicate'}    = 'No duplicate';
  $$refSTR{'Mode'}                    = 'Mode';
  $$refSTR{'rbExprOptSearchByLine'}   = 'Search by line';
  $$refSTR{'rbExprOptSearchByFile'}   = 'Search by file';
  $$refSTR{'lblExprOptMaxResFile'}    = 'By file';
  $$refSTR{'lblExprOptMaxResTot'}     = 'Total';
  $$refSTR{'lblExprOptIncContext'}    = 'Include context';
  $$refSTR{'lblExprOptIncContextLineBefore'} = 'Line(s) before';
  # Expression tool window
  $$refSTR{'winExprTool'}     = 'Expression tool';
  $$refSTR{'lblDataSample'}   = 'Data sample';
  # Log format database
  $$refSTR{'winLFDB'}         = 'Log format database';
  $$refSTR{'btnLFAdd'}        = 'Add a new log format';
  $$refSTR{'btnLFEdit'}       = 'Edit the selected log format';
  $$refSTR{'btnLFDel'}        = 'Remove the selected log format';
  $$refSTR{'addedLFObj'}      = 'Log format object has been added!';
  $$refSTR{'updatedLFObj'}    = 'Log format object has been updated!';
  $$refSTR{'deletedLFObj'}    = 'Log format object has been deleted!';
  # Log format object Window
  $$refSTR{'winLFObj'}        = 'Log format';
  $$refSTR{'LFclientIP'}      = 'remoteIP';
  $$refSTR{'LFHTTPmethod'}    = 'http_method';
  $$refSTR{'LFHTTPreq'}       = 'http_request';
  $$refSTR{'LFHTTPparam'}     = 'http_params';
  $$refSTR{'LFHTTPprot'}      = 'http_protocol';
  $$refSTR{'LFHTTPstatus'}    = 'http_status';
  $$refSTR{'LFsize'}          = 'size';
  $$refSTR{'LFReferer'}       = 'referer';
  $$refSTR{'LFUA'}            = 'useragent';
  $$refSTR{'other'}           = 'other';
  $$refSTR{'SourceFile'}      = 'Source file';
  $$refSTR{'chLFObjHasSpaces'}  = 'Field may contain spaces';
  $$refSTR{'provideLFName'}     = 'You must provide a name for the log format.';
  $$refSTR{'providePatternMin'} = 'You must provide a complete pattern (See doc).';
  # Log format object Window
  # Datetime database
  $$refSTR{'openDTDB'}        = 'Open Datetime database';
  $$refSTR{'guessFormat'}     = 'Guess format';
  $$refSTR{'winDTDB'}         = 'Datetime database';
  $$refSTR{'btnDTAdd'}        = 'Add a new datetime format';
  $$refSTR{'btnDTEdit'}       = 'Edit the selected datetime format';
  $$refSTR{'btnDTDel'}        = 'Remove the selected datetime format';
  $$refSTR{'sample'}          = 'Sample';
  $$refSTR{'pattern'}         = 'Pattern';
  $$refSTR{'useAs'}           = 'Use as';
  $$refSTR{'comment'}         = 'Comment';  
  $$refSTR{'timezone'}        = 'Timezone';
  $$refSTR{'localTimezone'}   = 'Local timezone';
  $$refSTR{'Local'}           = 'Local';  
  $$refSTR{'UTC'}             = 'UTC';
  $$refSTR{'guess'}           = 'Guess';
  $$refSTR{'default'}         = 'Default';
  $$refSTR{'same'}            = 'Same as input';
  $$refSTR{'formatFound'}     = 'Format found';
  $$refSTR{'formatMatch'}     = 'Format match';
  $$refSTR{'addedDTObj'}      = 'Datetime object has been added!';
  $$refSTR{'updatedDTObj'}    = 'Datetime object has been updated!';
  $$refSTR{'deletedDTObj'}    = 'Datetime object has been deleted!';
  # Datetime object Window
  $$refSTR{'winDTObj'}        = 'Datetime object';
  $$refSTR{'btnDTObjFromInput'} = 'Extract from input';
  $$refSTR{'btnLFPatternFromIISLog'} = 'Use IIS header';
  $$refSTR{'useFirstTip'}     = 'Use first item of List 1';
  # Pattern
  $$refSTR{'MonthNameFull'}   = 'Full month name (ex.: January)';
  $$refSTR{'MonthNameAbbr'}   = 'Abbreviated month name (ex.: Jan)';
  $$refSTR{'EquivalentTo'}    = 'Equivalent to';
  $$refSTR{'DayOfTheMonth'}   = 'Day of the month';
  $$refSTR{'pattern7'}        = 'Hour 24H';
  $$refSTR{'pattern8'}        = 'Hour 12H';
  $$refSTR{'Minutes'}         = 'Minutes';
  $$refSTR{'Month'}           = 'Month';
  $$refSTR{'AMorPM'}          = 'AM or PM';
  $$refSTR{'Seconds'}         = 'Seconds';
  $$refSTR{'Year1'}           = 'Year 4-digits (Ex.: 2016)';
  $$refSTR{'Year2'}           = 'Year 2-digits (Ex.: 16)';
  $$refSTR{'TZN'}             = 'Time zone name (UTC)';
  $$refSTR{'TZO'}             = 'Time zone offset (Ex.: -0500)';
  $$refSTR{'matchPattern'}    = 'Match Pattern';
  $$refSTR{'Input'}           = 'Input';
  $$refSTR{'output'}          = 'Output';
  $$refSTR{'both'}            = 'Both';
  $$refSTR{'none'}            = 'None';
  $$refSTR{'add'}             = 'Add';
  $$refSTR{'parsed'}          = 'Parsed';
  $$refSTR{'otherOffset'}     = 'Other, offset';
  $$refSTR{'otherName'}       = 'Other, name';
  $$refSTR{'provideSample'}   = 'You must provide a sample';
  $$refSTR{'providePattern'}  = 'You must provide a pattern';
  # Log Analysis Filters Window
  $$refSTR{'winLAFilters'}    = 'Log Analysis Filters';
  $$refSTR{'LAFiltersDB'}     = 'Log Analysis Filters database';
  $$refSTR{'WhiteList'}       = 'White List';
  $$refSTR{'Regular'}         = 'Regular';
  $$refSTR{'IpList'}          = 'IP list';
  $$refSTR{'DeleteFilterCat'} = 'Delete all filters in';
  # Log Analysis Filter Set Window
  $$refSTR{'winFilterSet'}      = 'Create or Edit a Filter Set';
  $$refSTR{'btnLAFiltersAdd'}   = 'Add a new Filter Set';
  $$refSTR{'btnLAFiltersEdit'}  = 'Edit the selected Filter Set';
  $$refSTR{'btnLAFiltersDel'}   = 'Remove the selected Filter Set';
  $$refSTR{'addedFilterSetDB'}  = 'Filter Set has been added to database';
  $$refSTR{'editedFilterSetDB'} = 'Filter Set has been edited in database';
  $$refSTR{'FilterSetExists'}   = 'Filter Set with this name exists, replace it';
  # Field Filter Window
  $$refSTR{'winFieldFilter'}    = 'Field Filter';
  $$refSTR{'btnFieldFilterAddDBTip'} = 'Add field filter to database';
  $$refSTR{'fieldFilterDB'}     = 'Field Filter database';
  $$refSTR{'addedFilterDB'}     = 'Filter has been added to Field Filter database';
  $$refSTR{'editedFilterDB'}    = 'Filter has been edited in Field Filter database';
  $$refSTR{'filterAddToDBTip'}  = 'Add to Field Filter Database';
  $$refSTR{'selFilter'}         = 'You must select a filter.';
  $$refSTR{'Field'}             = 'Field';
  $$refSTR{'Condition'}         = 'Condition';
  $$refSTR{'Value'}             = 'Value';
  $$refSTR{'isp'}               = 'ISP';
  $$refSTR{'LFUA-t'}            = 'UA Type';
  $$refSTR{'LFUA-os'}           = 'UA OS';
  $$refSTR{'LFUA-b'}            = 'UA Browser';
  $$refSTR{'LFUA-d'}            = 'UA Device';
  $$refSTR{'LFUA-l'}            = 'UA Lang';
  $$refSTR{'is'}                = 'is';
  $$refSTR{'isNot'}             = 'is not';
  $$refSTR{'Contains'}          = 'Contains';
  $$refSTR{'notContain'}        = 'does not contain';
  $$refSTR{'loadValue'}         = 'Load values from DB';
  $$refSTR{'setFilterCat'}      = 'You must enter or select a category.';
  $$refSTR{'setFilterName'}     = 'You must choose a name for this filter set.';
  $$refSTR{'setFilter'}         = 'You must set at least one filter.';
  $$refSTR{'setValue'}          = 'You must provide a value for this filter.';
  # Current Database source files
  $$refSTR{'winLACurrDBFiles'}  = 'Source file(s)';
  $$refSTR{'Path'}              = 'Path';
  $$refSTR{'Exists'}            = 'Exists';
  $$refSTR{'Entries'}           = 'Entries';
  $$refSTR{'FirstEntry'}        = 'First entry';
  $$refSTR{'ChangePath'}        = 'Change path';
  # Report Option window
  $$refSTR{'ReportOpt'}       = 'Report options';
  $$refSTR{'ReportOpt2'}      = 'Build report';
  $$refSTR{'btnReportDirTip'} = 'Select a folder where reports will be saved';
  $$refSTR{'btnOpenDirTip'}   = 'View content directory in Windows Explorer';
  $$refSTR{'chReplace'}       = 'If report exists, replace it';
  $$refSTR{'chOpenReport'}    = 'Open when finished';
  $$refSTR{'chReportOptSeparateReportsExpr'}   = 'One file per expression';
  $$refSTR{'chReportOptSeparateReportsObject'} = 'One file per object';
  $$refSTR{'chReportOptSeparateSheetsExpr'}    = 'One sheet per expression';
  $$refSTR{'chReportOptSeparateSheetsObject'}  = 'One sheet per object';
  $$refSTR{'chReportOptSeparatePagesExpr'}     = 'One page per expression';
  $$refSTR{'chReportOptSeparatePagesObject'}   = 'One page per object';
  $$refSTR{'chReportOptIncHeaders'} = 'Column headers';
  $$refSTR{'chReportOptIncSource'}  = 'Source';
  $$refSTR{'UADetails'}       = 'Useragent details';
  $$refSTR{'DTFormat'}        = 'Datetime format';
  # Save SQL Query Window
  $$refSTR{'winSaveQuery'}    = 'Save query in database';
  # Config Window
  $$refSTR{'winConfig'}       = 'Settings';
  $$refSTR{'database'}        = 'Databases';
  $$refSTR{'general'}         = 'General';
  $$refSTR{'OpenUserDir'}     = 'Open user dir';
  $$refSTR{'checkUpdate'}     = 'Check Update';
  $$refSTR{'AutoUpdateTip'}   = 'Check for update at startup';
  $$refSTR{'defaultLang'}     = 'Default language';
  $$refSTR{'selectDBFile'}    = 'Select the database file';
  $$refSTR{'downloadDB'}      = 'Download the database';
  $$refSTR{'firstStart'}      = 'This is your first use of XL-Parser. Do you want to set default configuration?';
  $$refSTR{'defaultDir'}      = 'Do you want to use default dir';
  $$refSTR{'SetGenOpt'}       = 'Set General Options';
  $$refSTR{'winPb'}           = 'Progress';
  $$refSTR{'winCW'}           = 'Configuration Wizard';
  $$refSTR{'XLWhoisExists'}   = 'Is XL-Whois installed on this system';
  $$refSTR{'configSet'}       = 'XL-Parser has been configured!';
  $$refSTR{'configSetPart'}   = 'Aborted! XL-Parser has been partially configured.';
  # General tab
  $$refSTR{'Tool'}            = 'Tool';
  $$refSTR{'update1'}         = 'You have the latest version installed.';
  $$refSTR{'update2'}         = 'Check for update';
  $$refSTR{'update3'}         = 'Update';
  $$refSTR{'update5'}         = 'is available. Download it';
  $$refSTR{'chFullScreen'}    = 'Start Full Screen';
  $$refSTR{'chRememberPos'}   = 'Remember position';
  $$refSTR{'NsLookupTO1'}     = 'Nslookup timeout';
  $$refSTR{'seconds'}         = 'seconds';
  # Databases tab
  $$refSTR{'currDBDate'}      = 'Current DB date';
  $$refSTR{'remoteDBDate'}    = 'DB date on';
  $$refSTR{'updateAvailable'} = 'An update of the database is available, download';
  $$refSTR{'DBUpToDate'}      = 'Your database is up to date';
  $$refSTR{'createDBTable'}   = 'Create database and table';
  $$refSTR{'ImportExprDB'}    = 'Import data from another database';
  $$refSTR{'dbFile'}          = 'Database file';
  $$refSTR{'createdDB'}       = 'The database has been created';
  $$refSTR{'selPathDB'}       = 'Select the path for the database';
  $$refSTR{'LocateThe'}       = 'Locate the ';
  $$refSTR{'OUIDB'}           = 'OUI (MAC Addresses)';
  $$refSTR{'OUIDB2'}          = 'MAC OUI database';
  $$refSTR{'selMACOUIFile'}   = 'Select the MAC OUI Database file';
  $$refSTR{'importOUIDB'}     = 'Import OUI Database';
  $$refSTR{'importedOUIDB'}   = 'OUI Database successfully imported!';
  $$refSTR{'updatedMACOUI'}   = 'The MACOUI database has been updated';
  $$refSTR{'MACOUINotExist'}  = 'The MAC OUI database (oui.db) does not exist, download';
  $$refSTR{'convertMACOUI'}   = 'Convert MAC OUI Database';
  $$refSTR{'GeoIPDB'}         = 'GeoIP';
  $$refSTR{'GeoIPDB2'}        = 'GeoIP database';
  $$refSTR{'selGeoIPFile'}    = 'Select the GeoIP Database file';
  $$refSTR{'updatedGeoIP'}    = 'The GeoIP database has been updated';
  $$refSTR{'GeoIPNotExist'}   = 'The GeoIP database (GeoLiteCity.dat) does not exist, download';
  $$refSTR{'IINLocalDB'}      = 'IIN (Credit cards)';
  $$refSTR{'IINLocalDB2'}     = 'IIN database';
  $$refSTR{'downloadWarning'} = 'It may take a few minutes';
  $$refSTR{'updatedIINDB'}    = 'The IIN database has been updated';
  # XL-Parser Database tab
  $$refSTR{'btnExprHistoryNewTip'} = 'Create a new Expression history database';
  $$refSTR{'btnExprNewTip'}   = 'Create a new Expression database';
  $$refSTR{'downloadLFDB'}    = 'Downloading Log format database';
  $$refSTR{'LFDBNotExist'}    = 'The Log format database (LF.db) does not exist, download';
  $$refSTR{'updatedLFDB'}     = 'The Log format database has been updated';
  $$refSTR{'btnLAFiltersNewTip'} = 'Create a new Log Analysis Filters database';
  # XL-Toolkit Databases tab
  $$refSTR{'XLWhoisDB'}       = 'ISP (XL-Whois)';
  $$refSTR{'XLWhoisDB2'}      = 'ISP database';
  $$refSTR{'ResTLDDB'}        = 'Resolve TLD database';
  $$refSTR{'ResTLDDBNotExist'} = 'The Resolve TLD database (Resolve TLD.db) does not exist, download';
  $$refSTR{'updatedResTLDDB'}  = 'The Resolve TLD database has been updated';
  $$refSTR{'lblTLDDB'}        = 'TLD database';
  $$refSTR{'btnTLDDBTip'}     = 'Select the TLD database file';
  $$refSTR{'TLDDBNotExist'}   = 'The TLD database (Resolve TLD.db) does not exist, download';
  $$refSTR{'updatedTLDDB'}    = 'The TLD database has been updated';
  $$refSTR{'DTDB'}            = 'Datetime';
  $$refSTR{'DTDBNotExist'}    = 'The Datetime database (DT.db) does not exist, download';
  $$refSTR{'updatedDTDB'}     = 'The Datetime database has been updated';
  # About Window
  $$refSTR{'About'}           = 'About';
  $$refSTR{'Version'}         = 'Version';
  $$refSTR{'Author'}          = 'Author';
  $$refSTR{'TranslatedBy'}    = 'Translated by';
  $$refSTR{'Website'}         = 'Website';
  $$refSTR{'TranslatorName'}  = '-';
  
  }  #--- End loadDefaultStr

#------------------------------------------------------------------------------#
1; 