import 'package:azure_application_insights/azure_application_insights.dart';
import 'package:http/http.dart';
import 'package:shelf/shelf.dart';

TelemetryClient? _telemetryClient;

void _buildTelemetryClient(
    {String? connectionString, TelemetryClient? telemetryClient}) {
  // if we already instantiated a client previously, keep using the existing instance
  if (_telemetryClient != null) {
    return;
  }

  // in case an instance is injected, use the injected instance
  if (telemetryClient != null) {
    _telemetryClient = telemetryClient;
  }

  // otherwise re-instantiate a new client from the connection string
  if (connectionString != null) {
    final connectionStringElements = connectionString.split(';');

    final instrumentationKeyCandidates = connectionStringElements
        .where((e) => e.startsWith('InstrumentationKey='))
        .toList();

    // if we get an incorrect connection string, don't log anything
    if (instrumentationKeyCandidates.isEmpty) {
      return;
    }

    final instrumentationKey = instrumentationKeyCandidates.first
        .substring('InstrumentationKey='.length);

    _telemetryClient = TelemetryClient(
      processor: BufferedProcessor(
        next: TransmissionProcessor(
          instrumentationKey: instrumentationKey,
          httpClient: Client(),
          timeout: const Duration(seconds: 10),
        ),
      ),
    );
  }
}

Middleware azureApplicationInsightsMiddleware(
        {String? connectionString, TelemetryClient? telemetryClient}) =>
    (innerHandler) {
      // ensure client exists
      _buildTelemetryClient(
          connectionString: connectionString, telemetryClient: telemetryClient);

      return (request) {
        // var startTime = DateTime.now();
        var watch = Stopwatch()..start();

        return Future.sync(() => innerHandler(request)).then((response) {
          _telemetryClient?.trackRequest(
            id: request.hashCode.toString(),
            duration: watch.elapsed,
            responseCode: response.statusCode.toString(),
          );

          return response;
        }, onError: (Object error, StackTrace stackTrace) {
          if (error is HijackException) throw error;

          _telemetryClient?.trackError(
              severity: Severity.error,
              error:
                  'Shelf error $error, request ${request.method} ${request.requestedUri}');

          // ignore: only_throw_errors
          throw error;
        });
      };
    };
