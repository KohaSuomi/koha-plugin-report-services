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

use Koha::AuthorisedValues;
use Koha::Libraries;

use Koha::Plugin::Fi::KohaSuomi::ReportServices::Modules::Chunker;

use Koha::Plugin::Fi::KohaSuomi::ReportServices::Modules::ReportService::Collection;
use Koha::Plugin::Fi::KohaSuomi::ReportServices::Modules::ReportService::Issue;

sub collect_report_data {
    my ($limit, $timeperiod, $json, $pretty, $csv, $verbose) = @_;

    my $chunker = Koha::Plugin::Fi::KohaSuomi::ReportServices::Modules::Chunker->new(undef, $limit, undef, $verbose);

    my @subject_fields = subject_fields();
    my $libraries = get_libraries();
    my $itemtypes = get_itemtypes();
    my $shelving_locations = get_locations();

    my @data_chunks = ();

    while (my $items = $chunker->get_chunk(undef, $limit)) {
        foreach my $item (@$items) {
            my $data_chunk = create_data_chunk($item, \@subject_fields, $libraries, $itemtypes, $shelving_locations);
            push @data_chunks, $data_chunk;
        }
    }

    if($json){
        my $json_obj = JSON->new();
        $json_obj->pretty unless !$pretty;
        my $json_data= $json_obj->encode(\@data_chunks);
        print $json_data;
    }
}

sub create_data_chunk {
    my ($item, $subject_fields, $libraries, $itemtypes, $shelving_locations) = @_;

    my $collection = Koha::Plugin::Fi::KohaSuomi::ReportServices::Modules::ReportService::Collection->new();
    my $issue = Koha::Plugin::Fi::KohaSuomi::ReportServices::Modules::ReportService::Issue->new();
    my $marcxml = $collection->get_marcxml($item->{biblionumber});
    my $marc_record = eval { MARC::Record::new_from_xml( $marcxml, "utf8", C4::Context->preference('marcflavour') ) };
    if ($@) {
        die $@;
    }

    # Collect subject added entries, how many times item has been checked out etc.
    $item->{subject_added_entries} = $collection->subject_added_entries($marc_record, $subject_fields);
    $item->{checked_out_count} = $collection->times_checked_out($item->{itemnumber});

    my @libraries = keys %$libraries;
    $item->{floats} = $collection->is_floating($item, \@libraries);

    # Collect library name, itemtype description etc.
    $item->{homebranch_pre} = $libraries->{$item->{homebranch}}->{branchname};
    $item->{holdingbranch_pre} = $libraries->{$item->{holdingbranch}}->{branchname};

    $item->{itemtype} = $itemtypes->{$item->{itemtype}};
    $item->{location} = $shelving_locations->{$item->{location}};

    # Handle issues
    my $is = $issue->get_issue($item->{itemnumber});
    unless (!$is){
        $is->{issue_type} = $issue->get_issue_type($is->{borrowernumber}, $item->{itemnumber}, $is->{issuedate});
        $is->{renew_type} = $issue->get_renew_type($is->{borrowernumber}, $item->{itemnumber}, $is->{lastreneweddate});
        $is->{branchcode} = $libraries->{$is->{branchcode}}->{branchname};
    }

    $item->{issue} = $is;

    #delete unneeded values
    delete $item->{issue}->{borrowernumber};
    delete $item->{barcode};

    return $item;
}

sub subject_fields {
    my $dbh = C4::Context->dbh();
    my $query = "SELECT DISTINCT(tagfield) FROM marc_tag_structure WHERE tagfield LIKE '6__'";
    my $sth = $dbh->prepare($query);
    $sth->execute( );

    my @tagfields;
    while ( my $row = $sth->fetchrow_hashref ) {
	    push @tagfields, $row->{tagfield};
    }
    return @tagfields;
}

sub get_libraries {
    my $libraries = Koha::Libraries->search()->unblessed;
    my %libraries_hash;
    foreach my $library (@$libraries){
        $libraries_hash{$library->{branchcode}} = $library;
    }
    return  \%libraries_hash;
}

sub get_itemtypes {
    my $itemtypes = Koha::AuthorisedValues->search( { category => 'MTYPE' } )->unblessed;
    my %itemtypes_hash;
    foreach my $itemtype (@$itemtypes){
        $itemtypes_hash{$itemtype->{authorised_value}} = $itemtype->{lib};
    }
    return  \%itemtypes_hash;
}

sub get_locations {
    my $locations = Koha::AuthorisedValues->search( { category => 'LOC' } )->unblessed;
    my %locations_hash;
    foreach my $location (@$locations){
        $locations_hash{$location->{authorised_value}} = $location->{lib};
    }
    return  \%locations_hash;
}

1;