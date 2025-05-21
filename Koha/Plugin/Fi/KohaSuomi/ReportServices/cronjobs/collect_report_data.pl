#!/usr/bin/perl

# Copyright KohaSuomi
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;

use Modern::Perl;
use open qw( :std :encoding(UTF-8) );
binmode( STDOUT, ":encoding(UTF-8)" );

use Getopt::Long;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

use C4::Context();
use C4::KohaSuomi::SFTP;

use Koha::Plugins;

use Koha::Plugin::Fi::KohaSuomi::ReportServices::Modules::ReportServices;

my $help;
my ($limit, $timeperiod, $json, $pretty, $csv, $verbose, $path, $test);

GetOptions(
    'h|help'         => \$help,
    'l|limit:i'      => \$limit,
    't|timeperiod:s' => \$timeperiod,
    'json'           => \$json,
    'pretty'         => \$pretty,
    'csv'            => \$csv,
    'v|verbose'      => \$verbose,
    'p|path=s'       => \$path,
    'test'         => \$test
);

my $usage = << 'ENDUSAGE';

This is a script to collect data for report service.

Script has the following parameters :

    -h --help           This helpful message.

    -l --limit          An SQL LIMIT -clause for testing purposes

    -t --timeperiod     The timeperiod definition. Supported formats are:
                        -"yesterday": whole previous day
                        - "lastmonth": whole previous month
                        -"YYYY-MM-DD-YYYY-MM-DD": start to end, inclusive

    --json              Build .json file

    --pretty            Build pretty JSON

    --csv               Build .csv file

    -v --verbose        More chatty script.

    -p --path           MANDATORY! File path for sftp config.

    --test           Mark data send as test data.

ENDUSAGE

if ($help) {
    print $usage;
    exit;
}

if(!$path) {
    print "Define config file output path for sftp\n";
    exit;
}

my $output_directory = $ARGV[0];

if ( !-d $output_directory || !-w $output_directory ) {
   print "ERROR: You must specify a valid and writeable directory to dump the print notices in.\n";
   print $usage;
   exit;
}

my $result = Koha::Plugin::Fi::KohaSuomi::ReportServices::Modules::ReportServices::collect_report_data($limit, $timeperiod, $json, $pretty, $csv, $verbose);

my $today = Koha::DateUtils::dt_from_string()->ymd;

my $configfile = eval { YAML::XS::LoadFile($path) };
print "Could not find config file from path ".$path."!\n" unless $configfile;
exit;

my $tmppath = $output_directory ."tmp/";
my $archivepath = $output_directory.'archived/';

my $fileformat = $json ? ".json" : ".csv";
my $filename = $test ? "test_koha_reportservice_".$today.$fileformat : "koha_reportservice_".$today.$fileformat;

if( $result ){
    open(my $fh, '>', $tmppath.$filename);
    print $fh $result;
    close $fh;
    print "Wrote report file ".$filename."\n";

    chdir $tmppath;
    my @json_files = <*.json>;
    my $zip = Archive::Zip->new();
    my $zip_file = $test ? "test_koha_reportservice_".$today. ".zip" : "koha_reportservice_".$today. ".zip";

    foreach my $json_file (@json_files) {
        $zip->addFile( $json_file );
    }

    unless ( $zip->writeToFileNamed($tmppath . $zip_file) == AZ_OK ) {
        die 'error creating zip-file';
    }

    foreach my $json_file (@json_files) {
        unlink $json_file;
    }

    my @zipfiles = <*.zip>;

    my ( $succes ) = C4::KohaSuomi::SFTP::sftp_transfer( \@zipfiles, $configfile, $tmppath, $archivepath );
    if( $succes ) {
        print "File ".$filename." send!\n";
    }
} else {
    print "Found nothing to send!";
}