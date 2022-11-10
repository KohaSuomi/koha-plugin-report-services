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

use C4::Context();

use Koha::Plugin::Fi::KohaSuomi::ReportServices::Modules::ReportServices;

my $help;
my ($limit, $timeperiod, $json, $pretty, $csv, $verbose);

GetOptions(
    'h|help'       => \$help,
    'l|limit:i'    => \$limit,
    't|timeperiod' => \$timeperiod,
    'json'         => \$json,
    'pretty'       => \$pretty,
    'csv'          => \$csv,
    'v|verbose'    => \$verbose,
);

my $usage = << 'ENDUSAGE';

This is a script to collect data for report service.

Script has the following parameters :

    -h --help           This helpful message.

    -l --limit          An SQL LIMIT -clause for testing purposes

    -t --timeperiod     In months (not in use yet).

    --json              Build .json file

    --pretty            Build pretty JSON

    --csv               Build .csv file

    -v --verbose        More chatty script.

ENDUSAGE

if ($help) {
    print $usage;
    exit;
}

Koha::Plugin::Fi::KohaSuomi::ReportServices::Modules::ReportServices::collect_report_data($limit, $timeperiod, $json, $pretty, $csv, $verbose);