import 'app_config.dart';
import 'bootstrap.dart';

/// Default entrypoint (`flutter run`) uses the dev flavor with fakes.
Future<void> main() => bootstrap(Flavor.dev);
