package Koha::Plugin::Fi::KohaSuomi::ReportServices::Modules::ReportService::Issue;

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

use Koha::DateUtils qw( dt_from_string );

use base qw(Koha::Objects);

sub _type {
    return 'Issue';
}

sub object_class {
    return 'Koha::Plugin::Fi::KohaSuomi::ReportServices::Modules::ReportService::Issue';
}

sub get_issue {
    my ($self, $itemnumber) = @_;

    my $dbh = C4::Context->dbh();
    my $query = "SELECT i.issue_id, i.issuedate, i.branchcode, i.borrowernumber,
    i.lastreneweddate, b.firstname, b.dateofbirth, b.categorycode, b. address, b.zipcode
    FROM issues i
    LEFT JOIN borrowers b ON (i.borrowernumber = b.borrowernumber)
    WHERE itemnumber = ?";
    my $sth = $dbh->prepare($query);
    $sth->execute( $itemnumber );

    my $issue;
    while ( my $row = $sth->fetchrow_hashref ) {
        $issue = $row unless !$row;
    }
    return $issue;
}

sub get_issue_type {
    my ($self, $borrowernumber, $itemnumber, $issuedate) = @_;

    $issuedate = dt_from_string($issuedate)->date;

    my $dbh = C4::Context->dbh();
    my $query = "SELECT interface FROM action_logs
    WHERE module = 'CIRCULATION' AND action = 'ISSUE'
    AND object = ? AND info = ? AND DATE(timestamp) = ?";
    my $sth = $dbh->prepare($query);
    $sth->execute( $borrowernumber, $itemnumber, $issuedate );

    my $issue_type;
    while ( my $row = $sth->fetchrow_hashref ) {
        $issue_type = $row->{interface} unless !$row;
    }
    return $issue_type;
}

sub get_renew_type {
    my ($self, $borrowernumber, $itemnumber, $lastreneweddate) = @_;

    $lastreneweddate = dt_from_string($lastreneweddate)->date;

    my $dbh = C4::Context->dbh();
    my $query = "SELECT interface FROM action_logs
    WHERE module = 'CIRCULATION' AND action = 'RENEWAL'
    AND object = ? AND info = ? AND DATE(timestamp) = ?
    ORDER BY timestamp DESC LIMIT 1";
    my $sth = $dbh->prepare($query);
    $sth->execute( $borrowernumber, $itemnumber, $lastreneweddate );

    my $renew_type;
    while ( my $row = $sth->fetchrow_hashref ) {
        $renew_type = $row->{interface} unless !$row;
    }
    return $renew_type;
}

1;