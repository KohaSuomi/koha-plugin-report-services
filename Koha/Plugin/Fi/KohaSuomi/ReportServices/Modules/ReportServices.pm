package Koha::Plugin::Fi::KohaSuomi::ReportServices::Modules::ReportServices;

#!/usr/bin/perl

# Copyright Koha-Suomi Oy 2022
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;
use Carp;

use Data::Dumper;
use URI::Escape;
use File::Temp;
use File::Basename qw( dirname );
use YAML::XS;
use JSON;

use C4::Context;

use Koha::Plugin::Fi::KohaSuomi::ReportServices::Modules::Chunker;

use Koha::Plugin::Fi::KohaSuomi::ReportServices::Modules::ReportService::Collection;
use Koha::Plugin::Fi::KohaSuomi::ReportServices::Modules::ReportService::Issues;

sub collect_report_data {
    my ($limit, $verbose) = @_;

    my $chunker = Koha::Plugin::Fi::KohaSuomi::ReportServices::Modules::Chunker->new(undef, $limit, undef, $verbose);
    while (my $items = $chunker->get_chunk(undef, $limit)) {
        foreach my $item (@$items) {
            create_data_chunk($item);
        }
    }
}

sub create_data_chunk {
    my ($item) = @_;

    my $data_chunk;
    return $data_chunk;
}

1;