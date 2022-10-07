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
    my ($class, $starting_itemnumber, $ending_itemnumber, $page_size, $verbose) = @_;
    my $self = {};
    $self->{starting_itemnumber} = $starting_itemnumber || 0;
    $self->{ending_itemnumber} = $ending_itemnumber || 99999999999;
    $self->{page_size} = $page_size  || 10000;
    $self->{position} = {
        start => $self->{starting_itemnumber},
        end => $self->{starting_itemnumber} + $self->{page_size},
        page => 1,
    };
    $self->{verbose} = $verbose || 0;
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
    my $query = "SELECT i.itemnumber, i.biblionumber, i.homebranch, i.location, i.notforloan,
    i.holdingbranch, i.datelastseen, i.cn_sort, i.price, i.issues, i.dateaccessioned, bi.isbn,
    b.title, b.author, b.copyrightdate, bde.primary_language, bde.itemtype
    FROM items i
    LEFT JOIN biblioitems bi ON (i.biblioitemnumber = bi.biblioitemnumber)
    LEFT JOIN biblio b ON (bi.biblionumber = b.biblionumber)
    LEFT JOIN koha_plugin_fi_kohasuomi_okmstats_biblio_data_elements bde ON (b.biblionumber = bde.biblioitemnumber)
    WHERE i.itemnumber >= ? AND i.itemnumber < ?";

    my $sth = $dbh->prepare($query);
    $sth->execute( $self->_get_position() );
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
    return ($self->{position}->{start}, $self->{position}->{end});
}

sub _increment_position {
    my ($self, $new_start) = @_;
    if ($new_start) {
        $self->{position}->{start} = $new_start;
        $self->{position}->{end}   = $self->{position}->{start} + $self->{page_size};
    }
    else {
        $self->{position}->{start} += $self->{page_size};
        $self->{position}->{end}   += $self->{page_size};
    }
    $self->{position}->{page}++;
}

sub _get_next_id {
    my ($self) = @_;

    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare("SELECT MIN(itemnumber) FROM items WHERE itemnumber > ?");
    my @pos = $self->_get_position();
    $sth->execute( $pos[0] );
    if ($sth->err) {
        my @cc = caller(0);
        die $cc[3]."():> ".$sth->errstr;
    }
    my ($itemnumber) = $sth->fetchrow();
    return $itemnumber;
}

sub _is_chunk_within_bounds {
    my ($self) = @_;

    if ($self->{ending_itemnumber} < $self->{position}->{end}) {
        if ($self->{ending_itemnumber} > ($self->{position}->{end} - $self->{page_size})) {
            $self->{position}->{end} = $self->{ending_itemnumber};
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