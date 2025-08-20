package Koha::Plugin::Fi::KohaSuomi::ReportServices::ReportsController;

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

use utf8;
use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';
use C4::Context;
use Try::Tiny;
use File::Basename;
use C4::Context;
use Data::Dumper;
use Log::Log4perl;
use Koha::Reports;
use Koha::Plugin::Fi::KohaSuomi::ReportServices;
use YAML::XS;
use Koha::OAuth;

my $dbh;

my $module = 'C4::KohaSuomi::Tweaks';
if (try_load($module)) {
    warn "ReportServices C4::KohaSuomi::Tweaks loaded\n";
    $dbh = C4::KohaSuomi::Tweaks->dbh();

}
else {
    warn "ReportServices C4::KohaSuomi::Tweaks not loaded\n";
    $dbh = C4::Context->dbh();
}

#This gets called from REST api

sub try_load {

    my $mod = shift;

    eval("use $mod");

    if ($@) {

        #print "\$@ = $@\n";
        return(0);
    }
    else {
        return(1);
    }
}

sub _d { my ($s) = @_; utf8::decode($s); $s }

sub decode_keys {
    my ($hash) = @_;
    return { map { _d($_) => $hash->{$_} } keys(%$hash) };
}

sub getReportData {

    my ( $self, $args ) = @_;

    my $CONFPATH = dirname($ENV{'KOHA_CONF'});
    my $KOHAPATH = C4::Context->config('intranetdir');

    # Initialize Logger
    my $log_conf = $CONFPATH . "/log4perl.conf";
    Log::Log4perl::init($log_conf);
    my $log = Log::Log4perl->get_logger('api');

    my $c = shift->openapi->valid_input or return;

    my $user = $c->stash('koha.user');

    my $sth;
    my $ref;

    return try {

        my $allowed_report_ids = Koha::Plugin::Fi::KohaSuomi::ReportServices->new()->retrieve_data('allowed_report_ids');
        my $report_id = $c->validation->param('report_id');

        my %config = %{ Load($allowed_report_ids)};
        #$log->info(Dumper(%config));
        #$log->info(Dumper($config{$user->borrowernumber}));

        if (exists $config{$user->borrowernumber}) {
            #$log->info("Borrowernumber found in config");

            if ( ( grep( /^$report_id$/, @{$config{$user->borrowernumber}} ) ) ) {
                #$log->info("Report id found in config");
            }
            else {
                $log->error("Report id not found in config");

                return $c->render(
                    status  => 403,
                    openapi => { error => "Forbidden" }
                );
            }
        }
        else {
            $log->error("Borrowernumber not found in config");

            return $c->render(
                status  => 403,
                openapi => { error => "Forbidden" }
            );
        }

        #config ok

        #$log->info(Dumper(%config));

        my (@param_names, @sql_params);

        push(@sql_params,$c->validation->param('param1'));
        push(@sql_params,$c->validation->param('param2'));
        push(@sql_params,$c->validation->param('param3'));
        push(@sql_params,$c->validation->param('param4'));
        push(@sql_params,$c->validation->param('param5'));

        my $report = Koha::Reports->find( $report_id );

        unless ($report) {
            $log->error("No such report");
            return $c->render(
                status  => 404,
                openapi => { error => "Data not found" }
            );
        }

        my $sql         = $report->savedsql;
        my $report_name = $report->report_name;
        my $type        = $report->type;

        ( $sql, undef ) = $report->prep_report( \@param_names, \@sql_params );

        $log->info(("API user " . $user->borrowernumber). " " . $user->firstname . " " . $user->surname . " requested report: ReportServices API running Report with id " . $report_id . "\n");

        $sth = $dbh->prepare($sql);

        $sth->execute();
        $ref = $sth->fetchall_arrayref({});

        $_ = decode_keys($_) for @$ref;

        $sth->finish();
        $dbh->disconnect();

        unless ($ref) {
            return $c->render(
                status  => 404,
                openapi => { error => "Data not found" }
            );
        }

        $log->info("Finished with report id ". $report_id .". Passing result to endpoint.");

        return $c->render( status => 200, openapi => $ref );

    }

    catch {
        $dbh->disconnect();
        $c->unhandled_exception($_);
    }
}

1;