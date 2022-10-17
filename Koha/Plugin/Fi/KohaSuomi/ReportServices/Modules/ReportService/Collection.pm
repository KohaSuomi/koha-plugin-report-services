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

use base qw(Koha::Objects);

sub _type {
    return 'Collection';
}

sub object_class {
    return 'Koha::Plugin::Fi::KohaSuomi::ReportServices::Modules::ReportService::Collection';
}

=head seen_last_time

    In which branch item was last seen.

=cut

sub seen_last_time {
    my ($self, $holdingbranch, $datelastseen) = @_;

    my $branch_last_seen;
    return $branch_last_seen;
}

=head subject_added_entries

    Collect all subject added entries from fields 6xx.

=cut

sub subject_added_entries {
    my ($self, $marc_record, $subject_fields) = @_;

    my $subject_added_entries;
    foreach my $field (@$subject_fields){
        my $entry = $marc_record->subfield($field,'a');
        $subject_added_entries .= $entry unless !$entry;
    }
    return $subject_added_entries;
}

=head is_floating

    Check if item is floating either by floating group settings or float rules.

=cut

sub is_floating {
    my ($self, $itemnumber) = @_;

    my $is_floating = 0;
    return $is_floating;
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