package Koha::Plugin::Fi::KohaSuomi::ReportServices::Modules::ReportService::Collection;

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

use C4::Context;

use C4::Biblio;
use C4::Circulation;

use Koha::Libraries;

use base qw(Koha::Objects);

sub _type {
    return 'Collection';
}

sub object_class {
    return 'Koha::Plugin::Fi::KohaSuomi::ReportServices::Modules::ReportService::Collection';
}

=head subject_added_entries

    Collect all subject added entries from fields 6xx.

=cut

sub subject_added_entries {
    my ($self, $marc_record, $subject_fields) = @_;

    my $subject_added_entries;
    my @entries;
    foreach my $field ($marc_record->fields()) {
        my $tag = $field->tag;
        if(grep( /^$tag$/, @$subject_fields )){
            my $entry = $field->subfield('a');
            push @entries, $entry;
        }
    }
    $subject_added_entries = join(',', @entries) unless !@entries;

    return $subject_added_entries;
}

=head is_floating

    Check if item is floating either by floating group settings or float rules.

=cut

sub is_floating {
    my ($self, $item, $libraries) = @_;

    foreach my $library (@$libraries){
        my $hbr = C4::Circulation::GetBranchItemRule($item->{homebranch}, $item->{itemtype})->{'returnbranch'} || "homebranch";
        my $validate_float = Koha::Libraries->find( $item->{homebranch} )->validate_float_sibling({ branchcode => $library });
        return 1 if $hbr eq "returnbylibrarygroup" && $validate_float;

        my $validate_floatrules = C4::Circulation::_validate_floatrules({ barcode => $item->{barcode}, branch => $library });
        return 1 if $validate_floatrules && $validate_floatrules eq "float";
    }

    return 0;
}

=head times_checked_out

    How many times has item been checked out during last year.

=cut

sub times_checked_out {
    my ($self, $itemnumber) = @_;

    my $dbh = C4::Context->dbh();
    my $query = "SELECT * FROM statistics
    WHERE itemnumber = ?
    AND statistics.type = 'issue'
    AND statistics.datetime < (DATE_SUB(CURDATE(), INTERVAL 1 YEAR))";
    my $sth = $dbh->prepare($query);
    $sth->execute( $itemnumber );

    return $sth->rows;
}

=head get_marcxml

    Get items MARC as XML.

=cut

sub get_marcxml {
    my ($self, $biblionumber) = @_;
    my $marcxml = _getDeletedXmlBiblio( $biblionumber ) || C4::Biblio::GetXmlBiblio( $biblionumber );
    return $marcxml;
}

=head _getDeletedXmlBiblio

    Again an ugly copypaste of GetXmlBiblio since GetDeletedXmlBiblio doesn't exists on community version.

=cut

sub _getDeletedXmlBiblio {
    my ($biblionumber) = @_;
    my $dbh = C4::Context->dbh;
    return unless $biblionumber;
    my ($marcxml) = $dbh->selectrow_array(
        q|
        SELECT metadata
        FROM deletedbiblio_metadata
        WHERE biblionumber=?
            AND format='marcxml'
            AND `schema`=?
    |, undef, $biblionumber, C4::Context->preference('marcflavour')
    );
    return $marcxml;
}

1;