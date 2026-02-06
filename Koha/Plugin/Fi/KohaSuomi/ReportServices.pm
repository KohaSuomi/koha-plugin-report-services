package Koha::Plugin::Fi::KohaSuomi::ReportServices;

## It's good practice to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);
## We will also need to include any Koha libraries we want to access
use C4::Context;
use utf8;

## Here we set our plugin version
our $VERSION = "1.0.1";

my $lang = C4::Languages::getlanguage() || 'en';
my $name = "";
my $description = "";
if ( $lang eq 'sv-SE' ) {
    $name = "Rapporteringstjänst";
    $description = "Ett plugin för insamling och överföring av statistikdata från Koha till en extern rapporteringstjänst. (Lokala databaser, endast vid behov)";
} elsif ( $lang eq 'fi-FI' ) {
    $name = "Raportointi palvelu";
    $description = "Plugin tilastotietojen keräämiseen ja lähettämiseen Kohasta ulkoiseen raportointipalveluun. (Paikalliskannat, vain tarvittaessa)";
} else {
    $name = "Report Service";
    $description = "A plugin for collecting and sending statistical data from Koha to an external reporting service.";
}

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => $name,
    author          => 'Lari Strand, Emmi Takkinen',
    date_authored   => '2022-10-07',
    date_updated    => '2025-11-06',
    minimum_version => '21.11',
    maximum_version => '',
    version         => $VERSION,
    description     => $description,
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual 
    my $self = $class->SUPER::new($args);

    return $self;
}
## This is the 'install' method. Any database tables or other setup that should
## be done when the plugin if first installed should be executed in this method.
## The installation method should always return true if the installation succeeded
## or false if it failed.
sub install() {
    my ( $self, $args ) = @_;

    return 1;
}

## This is the 'upgrade' method. It will be triggered when a newer version of a
## plugin is installed over an existing older version of a plugin
sub upgrade {
    my ( $self, $args ) = @_;

    return 1;
}

## This method will be run just before the plugin files are deleted
## when a plugin is uninstalled. It is good practice to clean up
## after ourselves!
sub uninstall() {
    my ( $self, $args ) = @_;

    return 1;
}

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {
        my $template = $self->get_template({ file => 'configure.tt' });

        ## Grab the values we already have for our settings, if any exist
        $template->param(
            allowed_report_ids => $self->retrieve_data('allowed_report_ids'),
            last_configured_by => C4::Context->userenv->{'number'},
            last_upgraded   => $self->retrieve_data('last_upgraded'),
        );

        $self->output_html( $template->output() );
    }
    else {
        my $allowed_report_ids = $cgi->param('allowed_report_ids');
        $self->store_data(
            {
                allowed_report_ids => $allowed_report_ids,
                last_configured_by => C4::Context->userenv->{'number'},
            }
        );
        $self->go_home();
    }
}


sub api_routes {
    my ( $self, $args ) = @_;

    my $spec_dir = $self->mbf_dir();
    return JSON::Validator->new->schema($spec_dir . "/openapi.json")->schema->{data};
    #my $spec_str = $self->mbf_read('openapi.json');
    #my $spec     = decode_json($spec_str);

    #return $spec;
}

# sub api_routes {
#     my ( $self, $args ) = @_;

#     my $spec_dir = $self->mbf_dir();

#     my $schema = JSON::Validator::Schema::OpenAPIv2->new;
#     my $spec = $schema->resolve($spec_dir . '/openapi.json');

#     return $self->_convert_refs_to_absolute($spec->data->{'paths'}, 'file://' . $spec_dir . '/');
# }

sub api_namespace {
    my ( $self ) = @_;
    
    return 'kohasuomi';
}

1;

