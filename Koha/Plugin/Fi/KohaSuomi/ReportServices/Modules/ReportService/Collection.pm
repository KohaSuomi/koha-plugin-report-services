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

use Koha::CirculationRules;
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
            push @entries, $entry if $entry;
        }
    }
    $subject_added_entries = join(';', @entries) unless !@entries;

    return $subject_added_entries;
}

=head is_floating

    Check if item is floating either by floating group settings or float rules.

=cut

sub is_floating_by_float_groups {
    my ($self, $item, $libraries) = @_;

    my $hbr = Koha::CirculationRules->get_return_branch_policy($item);
    my $item_float_groups = _float_groups($item->homebranch);
    my $validate_float = 0;
    if($item_float_groups){
        foreach my $library (@$libraries){
            my $library_float_groups = _float_groups($library);
            foreach my $item_float_group (@$item_float_groups){
                if ( grep( /^$item_float_group$/, @$library_float_groups ) ) {
                    $validate_float = 1;
                }
            }
        }
    }
    return 1 if $hbr eq "returnbylibrarygroup" && $validate_float;
    return 0;
}

sub is_floating_by_float_rules {
    my ($self, $item, $libraries) = @_;

    my $biblioitem = Koha::Biblioitems->find({ biblionumber => $item->biblionumber});
    my $yaml = C4::Context->preference('FloatRules');
    my $rules = YAML::XS::Load(Encode::encode_utf8($yaml));
    return 0 unless $rules || !$item->barcode;

    my $item_homebranch = $item->homebranch;
    while(my($branches_key, $rule) = each %$rules) {
        my $wildcard = $branches_key =~ m/%/ ? 1 : 0;
        my @branches = split(/[%-<>]+/, $branches_key);
        my $from_branch = $branches[0];
        my $to_branch = $branches[1];

        if($item_homebranch =~ m/^$from_branch/ || $item_homebranch =~ m/^$to_branch/){
            my $checkrules;
            foreach my $current_branch (@$libraries){
                if($current_branch =~ m/^$from_branch/ || $current_branch =~ m/^$to_branch/){
                    if($branches_key =~ m/->/){
                        if($wildcard){
                            $checkrules = 1 if $current_branch =~ m/^$from_branch/ && $item_homebranch =~ m/^$to_branch/;
                        } else {
                            $checkrules = 1 if $current_branch eq $from_branch && $item_homebranch eq $to_branch;
                        }
                    } elsif($branches_key =~ m/<>/){
                        if($wildcard){
                            $checkrules = 1 if ( $current_branch =~ m/^$from_branch/ && $item_homebranch =~ m/^$to_branch/ )
                            || ( $current_branch =~ m/^$to_branch/ && $item_homebranch =~ m/^$from_branch/ );
                        } else {
                            $checkrules = 1 if ( $current_branch eq $from_branch && $item_homebranch eq $to_branch )
                            || ( $current_branch eq $to_branch && $item_homebranch eq $from_branch );
                        }
                    }

                    if($checkrules){
                        my $evalCondition = '';
                        if (my @rule = $rule =~ /(\w+)\s+(ne|eq|=~|<|>|==|!=)\s+(\S+)\s*(and|or|xor|&&|\|\|)?/ig) {
                            $evalCondition .= '||' if $evalCondition ne '';
                            $evalCondition .= '(';
                            for (my $i=0 ; $i<scalar(@rule) ; $i+=4) {
                                my $column = $rule[$i];
                                my $operator = $rule[$i+1];
                                my $value = $rule[$i+2];
                                my $join = $rule[$i+3] || '';
                                $evalCondition .= $column eq "itemtype"
                                ? join(' ',"\$biblioitem->$column",$operator,"$value",$join,'')
                                : join(' ',"\$item->$column",$operator,"$value",$join,'');
                            }
                            $evalCondition .= ')';
                        }
                        #Prevent spamming undef warnings to logs
                        no warnings 'uninitialized';

                        my $ok = eval("return 1 if($evalCondition);");
                        if ( $ok && $evalCondition ) {
                            return 1;
                        } else {
                            return 0;
                        };
                    }
                }
            }
        }
    }
}

=head _float_groups

    Fetch float groups for library.

=cut

sub _float_groups {
    my ($branch) = @_;

    my $dbh = C4::Context->dbh();

    my $library_groups_query = "SELECT id FROM library_groups WHERE ft_local_float_group = 1";
    my $sth = $dbh->prepare($library_groups_query);
    $sth->execute();
    my $library_group_ids = $sth->fetchall_arrayref({});

    if(scalar @$library_group_ids > 0){
        my @ids;
        foreach my $id (@{$library_group_ids}){
            push @ids, $id->{id};
        }
        my $query =
        "SELECT parent_id FROM library_groups
        WHERE branchcode = ?
        AND parent_id
        IN(". join(',', map {"'$_'"} @ids).")";
        $sth = $dbh->prepare($query);
        $sth->execute( $branch );
        my $ids = $sth->fetchall_arrayref({});

        my @float_group_ids;
        foreach my $id (@{$ids}){
            push @float_group_ids, $id->{parent_id};
        }

        return \@float_group_ids;
    } else {
        return 0;
    }
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

    Again an ugly copypaste of GetXmlBiblio since GetDeletedXmlBiblio doesn't exists in community version.

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