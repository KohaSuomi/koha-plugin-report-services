use strict;
use warnings;

use Test::More;
use t::lib::TestBuilder;
use t::lib::Mocks;
use Test::Mojo;
use JSON;
use FindBin;
use Koha::Database;
use Koha::Report;
use Koha::Reports;
use C4::Context;

use lib "$FindBin::Bin/../../../../../..";

my $schema = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;
$schema->storage->txn_begin;

t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

my $t = Test::Mojo->new('Koha::REST::V1');

sub setup_reports_fixture_data {
    my $new_report_1  = Koha::Report->new(
        {
            report_name => 'report_name_for_test_1',
            savedsql    => 'SELECT "I wrote a report"',
        }
    )->store;

    my $new_report_2 = Koha::Report->new(
        {
            report_name => 'report_name_for_test_2',
            savedsql    => 'SELECT "Another report"',
        }
    )->store;

    return ($new_report_1, $new_report_2);
}

require_ok('Koha::Plugin::Fi::KohaSuomi::ReportServices::ReportsController');

subtest '_dbh uses C4::KohaSuomi::Tweaks when available' => sub {
	no warnings 'redefine';

	my $tweaks_called = 0;

	local *Koha::Plugin::Fi::KohaSuomi::ReportServices::ReportsController::try_load = sub { return 1; };
	local *C4::KohaSuomi::Tweaks::dbh = sub {
		$tweaks_called++;
		return 'replica_dbh';
	};
	local *C4::Context::dbh = sub { return 'context_dbh'; };

	my $dbh = Koha::Plugin::Fi::KohaSuomi::ReportServices::ReportsController::_dbh();

	is( $dbh, 'replica_dbh', '_dbh returns replica handle from Tweaks' );
	is( $tweaks_called, 1, 'Tweaks dbh was called exactly once' );
};

subtest '_dbh falls back to C4::Context->dbh when Tweaks is unavailable' => sub {
	no warnings 'redefine';

	local *Koha::Plugin::Fi::KohaSuomi::ReportServices::ReportsController::try_load = sub { return 0; };
	local *C4::Context::dbh = sub { return 'context_dbh'; };

	my $dbh = Koha::Plugin::Fi::KohaSuomi::ReportServices::ReportsController::_dbh();

	is( $dbh, 'context_dbh', '_dbh uses C4::Context fallback handle' );
};

subtest 'Fetch report data with authorized report ID' => sub {
    plan tests => 7;

    my ($new_report_1, $new_report_2) = setup_reports_fixture_data();

    # Create a test patron with a password and permissions
    my $patron = $builder->build_object({
        class => 'Koha::Patrons',
        value => { flags => 1 }    # Set a flag to indicate this patron has permissions to access the report data
    });
    my $password = 'thePassword123';
    $patron->set_password({ password => $password, skip_validation => 1 });

    # Get the patron's userid
    my $userid    = $patron->userid;

    # Get report IDs
    my $report_id_1 = $new_report_1->id;
    my $report_id_2 = $new_report_2->id;

    my $borrowernumber = $patron->borrowernumber;

    my $allowed_report_ids = <<YAML;
$borrowernumber:
  - $report_id_1
YAML
    Koha::Plugin::Fi::KohaSuomi::ReportServices->new()->store_data({
        allowed_report_ids => $allowed_report_ids,
    });
    my $allowed_report_ids_from_storage = Koha::Plugin::Fi::KohaSuomi::ReportServices->new()->retrieve_data('allowed_report_ids');
    is( $allowed_report_ids_from_storage, $allowed_report_ids, 'Allowed report IDs should be stored and retrievable' );
    
    # Get report data with authentication
    my $get_response = $t->get_ok("//$userid:$password@/api/v1/contrib/kohasuomi/reportservices/reports?report_id=$report_id_1")
        ->status_is(200)
        ->json_is('/0/I wrote a report', 'I wrote a report', 'Response should contain the expected report data' );

    
    # POST request to get report data should also work
    my $post_response = $t->post_ok("//$userid:$password@/api/v1/contrib/kohasuomi/reportservices/reports" => form => { report_id => $report_id_1 })
        ->status_is(200)
        ->json_is('/0/I wrote a report', 'I wrote a report', 'POST request should also return the expected report data' );
};

subtest 'Fetch report data with invalid requests' => sub {
    plan tests => 6;

    my ($new_report_1, $new_report_2) = setup_reports_fixture_data();

    # Create a test patron with a password and permissions
    my $patron = $builder->build_object({
        class => 'Koha::Patrons',
        value => { flags => 1 }    # Set a flag to indicate this patron has permissions to access the report data
    });
    my $password = 'thePassword123';
    $patron->set_password({ password => $password, skip_validation => 1 });

    # Get the patron's userid
    my $userid    = $patron->userid;

    # Get report IDs
    my $report_id_1 = $new_report_1->id;
    my $report_id_2 = $new_report_2->id;

    my $borrowernumber = $patron->borrowernumber;

    my $allowed_report_ids = <<YAML;
$borrowernumber:
  - $report_id_1
YAML
    Koha::Plugin::Fi::KohaSuomi::ReportServices->new()->store_data({
        allowed_report_ids => $allowed_report_ids,
    });
    # Attempt to get data for a report ID that is not allowed
    my $response = $t->get_ok("//$userid:$password@/api/v1/contrib/kohasuomi/reportservices/reports?report_id=$report_id_2")
        ->status_is(403)
        ->json_is('/error', 'Forbidden', 'Response should indicate forbidden access for unauthorized report ID' );
    
    # Attempt to get data for a non-existent report ID
    my $non_existent_report_id = 999999; # Assuming this ID does not exist in the test database
    my $response_non_existent = $t->get_ok("//$userid:$password@/api/v1/contrib/kohasuomi/reportservices/reports?report_id=$non_existent_report_id")
        ->status_is(403)
        ->json_is('/error', 'Forbidden', 'Response should indicate forbidden access for non-existent report ID' );
};

subtest 'Fetch data with parameterized report' => sub {
    plan tests => 3;

    my $report = Koha::Report->new(
        {
            report_name => 'report_name_for_test_parameterized',
            savedsql    => 'SELECT borrowernumber FROM borrowers WHERE borrowernumber IN <<Test|list>>',
        }
    )->store;
    my $report_id = $report->id;

    # Create a test patron with a password and permissions
    my $patron = $builder->build_object({
        class => 'Koha::Patrons',
        value => { flags => 1 }    # Set a flag to indicate this patron has permissions to access the report data
    });
    my $password = 'thePassword123';
    $patron->set_password({ password => $password, skip_validation => 1 });

    # Get the patron's userid
    my $userid    = $patron->userid;

    my $borrowernumber = $patron->borrowernumber;

    my $allowed_report_ids = <<YAML;
$borrowernumber:
  - $report_id
YAML
    Koha::Plugin::Fi::KohaSuomi::ReportServices->new()->store_data({
        allowed_report_ids => $allowed_report_ids,
    });
    # Get report data with authentication and parameter
    my $response = $t->get_ok("//$userid:$password@/api/v1/contrib/kohasuomi/reportservices/reports?report_id=$report_id&param1=$borrowernumber")
        ->status_is(200)
        ->json_is('/0/borrowernumber', $borrowernumber, 'Response should contain the expected borrowernumber from the parameterized report' );
};

subtest 'Returns 503 when DB ping fails' => sub {
    plan tests => 3;

    my ($new_report_1, undef) = setup_reports_fixture_data();

    my $patron = $builder->build_object({
        class => 'Koha::Patrons',
        value => { flags => 1 }
    });
    my $password = 'thePassword123';
    $patron->set_password({ password => $password, skip_validation => 1 });

    my $userid         = $patron->userid;
    my $borrowernumber = $patron->borrowernumber;
    my $report_id_1    = $new_report_1->id;

    my $allowed_report_ids = <<YAML;
$borrowernumber:
  - $report_id_1
YAML
    Koha::Plugin::Fi::KohaSuomi::ReportServices->new()->store_data({
        allowed_report_ids => $allowed_report_ids,
    });

    {
        no warnings 'redefine';
        local *Koha::Plugin::Fi::KohaSuomi::ReportServices::ReportsController::_dbh = sub {
            return bless {}, 'Local::PingFailDbh';
        };
        local *Local::PingFailDbh::ping = sub { return 0; };

        $t->get_ok("//$userid:$password@/api/v1/contrib/kohasuomi/reportservices/reports?report_id=$report_id_1")
            ->status_is(503)
            ->json_is('/error', 'Connection unavailable');
    }
};

subtest 'Pagination parameters are handled correctly' => sub {
    plan tests => 4;

    my $report = Koha::Report->new(
        {
            report_name => 'report_name_for_test_pagination',
            savedsql    => 'WITH RECURSIVE numbers AS (SELECT 1 AS number UNION ALL SELECT number + 1 FROM numbers WHERE number < 50) SELECT number FROM numbers', # Generate 50 rows of data
        }
    )->store;
    my $report_id = $report->id;

    my $patron = $builder->build_object({
        class => 'Koha::Patrons',
        value => { flags => 1 }
    });
    my $password = 'thePassword123';
    $patron->set_password({ password => $password, skip_validation => 1 });

    my $userid         = $patron->userid;
    my $borrowernumber = $patron->borrowernumber;

    my $allowed_report_ids = <<YAML;
$borrowernumber:
  - $report_id
YAML
    Koha::Plugin::Fi::KohaSuomi::ReportServices->new()->store_data({
        allowed_report_ids => $allowed_report_ids,
    });

    my $response = $t->get_ok("//$userid:$password@/api/v1/contrib/kohasuomi/reportservices/reports?report_id=$report_id&_page=2&_per_page=10")
        ->status_is(200)
        ->json_is('/0/number', 11, 'First item on page 2 should be 11')
        ->json_is('/9/number', 20, 'Last item on page 2 should be 20');
};

# Rollback the transaction, so we don't leave test data in the database
$schema->storage->txn_rollback;

done_testing();
