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

use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';
use C4::Context;
use Try::Tiny;
use File::Basename;
use C4::Context;
use Data::Dumper;
use Log::Log4perl;
use Koha::Reports;

my $dbh;

my $module = 'C4::KohaSuomi::Tweaks';
if (try_load($module)) {
  warn "ReportServices C4::KohaSuomi::Tweaks loaded\n";
  $dbh = C4::KohaSuomi::Tweaks->dbh();
  
} else {
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
  } else {
    return(1);
  }
}

sub getReportData {
  
  my $CONFPATH = dirname($ENV{'KOHA_CONF'});
my $KOHAPATH = C4::Context->config('intranetdir');

# Initialize Logger
my $log_conf = $CONFPATH . "/log4perl.conf";
Log::Log4perl::init($log_conf);
my $log = Log::Log4perl->get_logger('sipohttp');
$log->debug("raportteri");
    
    my $c = shift->openapi->valid_input or return;

    return try {
        
        my $sth;
        my $data;
        my $ref;
        
        my $report_id = $c->validation->param('report_id');
        my $report = Koha::Reports->find( $report_id );
        
        $log->debug($report_id);
        
        
        my $sql         = $report->savedsql;
        my $report_name = $report->report_name;
        my $type        = $report->type;
        
        $log->debug($sql);
        
        $sth = $dbh->prepare($sql);

        $sth->execute();

        $ref = $sth->fetchall_arrayref({});
        
        unless ($ref) {
            return $c->render( status  => 404,
                            openapi => { error => "Data not found" } );
        }

        return $c->render( status => 200, openapi => $ref );
    }
    catch {
        $c->unhandled_exception($_);
    }
}





# Hae data tietokannasta sarakkeen nimen kera (select x AS 'xxxx' esim.) käytettäväksi ilman fieldtemplate-määrittelyn tarvetta. Järjestys menee sekaisin (perl-array)
# , { Slice => {} }); 

# sub getagegroups {
#     my $c = shift->openapi->valid_input or return;

#     return try {
        
#         my $dbh = C4::Context->dbh();
#         my $sth;
#         my $ref;

        

#         my $result = $dbh->selectall_arrayref( qq{
#  SELECT branchcode,

# SUM( IF( dateofbirth > DATE_SUB(CURDATE(), INTERVAL 15 YEAR)  ,1,0)) AS '0-14-v.'


# FROM borrowers

# where categorycode IN ('HENKILO', 'LAPSI')

# group by branchcode
# order BY branchcode, dateofbirth
# }, { Slice => {} });

        
#         unless ($result) {
#             return $c->render( status  => 404,
#                             openapi => { error => "Data not found" } );
#         }

#         return $c->render( status => 200, openapi => $result );
#     }
#     catch {
#         $c->unhandled_exception($_);
#     }
# }


1;