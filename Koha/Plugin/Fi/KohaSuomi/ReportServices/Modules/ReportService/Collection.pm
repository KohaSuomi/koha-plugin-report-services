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

sub seen_last_time {
    my $branch_last_seen;
    return $branch_last_seen;
}

sub subject_added_entries {
    my @subject_added_entries;
    return @subject_added_entries;
}

sub is_floating {
    my $is_floating;
    return $is_floating;
}

1;