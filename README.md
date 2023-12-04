
# Koha-Suomi plugin ReportServices

This is the plugin description

# Downloading

From the release page you can download the latest \*.kpz file
suomi
# Installing

Koha's Plugin System allows for you to add additional tools and reports to Koha that are specific to your library. Plugins are installed by uploading KPZ ( Koha Plugin Zip ) packages. A KPZ file is just a zip file containing the perl files, template files, and any other files necessary to make the plugin work.

The plugin system needs to be turned on by a system administrator.

To set up the Koha plugin system you must first make some changes to your install.

    Change <enable_plugins>0<enable_plugins> to <enable_plugins>1</enable_plugins> in your koha-conf.xml file
    Confirm that the path to <pluginsdir> exists, is correct, and is writable by the web server
    Remember to allow access to plugin directory from Apache

    <Directory <pluginsdir>>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    Restart your webserver

Once set up is complete you will need to alter your UseKohaPlugins system preference. On the Tools page you will see the Tools Plugins and on the Reports page you will see the Reports Plugins.



# Using the REST API endpoint /api/v1/contrib/kohasuomi/reportservices/reports

The Koha REST API endpoint responds to GET requests and requires the following in the request:

1. The Koha API OAuth 2.0 access Token in the request header provided by /api/v1/oauth/token in exchange for the API keys configured to the correct API user.
   The API user/borrowernumber whose API keys are used to send the GET request needs the "use report plugins" permission in Koha to be able to send requests to the endpoint.
2. The Koha internal report ID that Koha should produce JSON response data for in path
   
Optional:

param1, param2,param3,param4,param5: Parameters to be passed on to the Koha report

GET Example address using two optional parameters in the request, running Koha SQL report with id 53:   https://vaski-test.fi/api/v1/contrib/kohasuomi/reportservices/reports?report_id=53&param1=2022-04-11&param2=2023-11-15

in Koha SQL report id 53: where (b.timestamp between <<Start Date|date>> and <<End Date|date>>) <--- these user definable parameters would be replaced by the GET request's param1 and param2 in order of their appearance in the SQL statement so the report runs as:

...where (b.timestamp between '2022-04-11' and '2023-11-15'.





