package Koha::Plugin::Fi::KohaSuomi::ReportServices::Modules::Chunker;

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

use Koha::Items;

=head SYNOPSIS

ItemChunker is based on BiblioChunker made for Vaara-kirjastot 2015.

=cut

sub new {
    my ($class, $starting_position, $limit, $chunk_size, $verbose, $startdate, $enddate) = @_;
    my $self = {};

    my $items_count = Koha::Items->search()->count();

    $self->{starting_position} = $starting_position || 0;
    $self->{limit} = $limit || $items_count;

    $chunk_size = 10000 unless $chunk_size;
    # unless chunk_size is greater than limit use limit as chunk_size
    $chunk_size = $limit unless !$limit || $chunk_size <= $limit;

    $self->{chunk_size} = $chunk_size;
    $self->{position} = {
        start => $self->{starting_position},
        end => $self->{starting_position} + $self->{chunk_size},
        page => 1,
    };
    $self->{verbose} = $verbose || 0;
    $self->{startdate} = $startdate;
    $self->{enddate} = $enddate;
    bless($self, $class);
    return $self;
}

sub get_chunk {
    my ($self) = @_;
    return $self->_get_chunk();
}

sub _get_chunk {
    my ($self) = @_;
    my @cc = caller(0);

    if ($self->{verbose} > 0) {
        print ' #'.DateTime->now()->iso8601()."# ".$cc[3]." is getting new chunk ".$self->{position}->{page}.", ".$self->{position}->{start}."-".$self->{position}->{end}." #\n" if $self->{verbose} > 0;
    }

    unless ($self->_is_chunk_within_bounds()) {
        return undef;
    }
    my $dbh = C4::Context->dbh();
    my $query = "SELECT i.itemnumber, i.biblionumber, i.homebranch, i.location, i.notforloan, i.itype,
    i.holdingbranch, i.datelastseen, i.cn_sort, i.price, i.issues as issues_total, i.dateaccessioned,
    i.barcode, bi.isbn, b.title, b.author, b.copyrightdate, bde.primary_language, bde.itemtype, bde.cn_class
    FROM items i
    LEFT JOIN biblioitems bi ON (i.biblioitemnumber = bi.biblioitemnumber)
    LEFT JOIN biblio b ON (bi.biblionumber = b.biblionumber)
    LEFT JOIN koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements bde ON (b.biblionumber = bde.biblionumber)";
    $query .= " WHERE (i.timestamp BETWEEN ? AND ?
    OR b.timestamp BETWEEN ? AND ?)" if $self->{startdate} && $self->{enddate};
    $query .= " LIMIT ?, ?";

    my $sth = $dbh->prepare($query);
    my @params = ();
    push @params, $self->{startdate}, $self->{enddate}, $self->{startdate}, $self->{enddate} if $self->{startdate} && $self->{enddate};
    push @params, $self->_get_position();

    $sth->execute( @params );
    if ($sth->err) {
        die $cc[3]."():> ".$sth->errstr;
    }
    my $chunk = $sth->fetchall_arrayref({});
    if (ref $chunk eq 'ARRAY' && scalar(@$chunk)) {
        $self->_increment_position();
        return $chunk;
    }
    else {
        my $next_available_itemnumber = $self->_get_next_id();
        if ($next_available_itemnumber) {
            $self->_increment_position($next_available_itemnumber);
            return $self->get_chunk();
        }
        else {
            return undef;
        }
    }
    return (ref $chunk eq 'ARRAY' && scalar(@$chunk)) ? $chunk : undef;
}

sub _get_position {
    my ($self) = @_;
    return ($self->{position}->{start}, $self->{chunk_size});
}

sub _increment_position {
    my ($self) = @_;
    $self->{position}->{start} += $self->{chunk_size};
    $self->{position}->{end}  += $self->{chunk_size};
    $self->{position}->{page}++;
}

sub _is_chunk_within_bounds {
    my ($self) = @_;

    if ($self->{limit} < $self->{position}->{end}) {
        if ($self->{limit} > ($self->{position}->{end} - $self->{chunk_size})) {
            $self->{position}->{end} = $self->{limit};
            return 1;
        }
        else {
            return 0;
        }
    }
    else {
        return 1;
    }
}

1;