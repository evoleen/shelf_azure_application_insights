import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_azure_application_insights/shelf_azure_application_insights.dart';

void main() async {
  var handler = const Pipeline()
      .addMiddleware(azureApplicationInsightsMiddleware(
          connectionString: '<APPLICATION_INSIGHTS_CONNECTION_STRING>'))
      .addHandler(_echoRequest);

  var server = await shelf_io.serve(handler, 'localhost', 8080);

  // Enable content compression
  server.autoCompress = true;

  print('Serving at http://${server.address.host}:${server.port}');
}

Response _echoRequest(Request request) =>
    Response.ok('Request for "${request.url}"');
