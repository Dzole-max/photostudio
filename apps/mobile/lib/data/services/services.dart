import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers.dart';
import '../domain_kit.dart';
import '../photos/geocoder.dart';
import '../photos/photo_analyzer.dart';
import '../photos/photo_library.dart';
import '../photos/vision.dart';
import 'ai_providers.dart';
import 'art_providers.dart';
import 'auth_service.dart';
import 'motion_provider.dart';
import 'observability.dart';
import 'photo_permission.dart';
import 'user_data_service.dart';

part 'services.g.dart';

/// Service registry. Every external dependency has a fake that is chosen
/// automatically from [AppConfig] when its key is missing, so a fresh clone
/// runs the whole flow without accounts. Tests override these providers.

@Riverpod(keepAlive: true)
Analytics analytics(Ref ref) => NoopAnalytics();

@Riverpod(keepAlive: true)
CrashReporter crashReporter(Ref ref) {
  final config = ref.watch(appConfigProvider);
  return config.sentryEnabled
      ? const SentryCrashReporter()
      : const NoopCrashReporter();
}

@Riverpod(keepAlive: true)
PhotoPermissionService photoPermission(Ref ref) =>
    const DevicePhotoPermissionService();

@Riverpod(keepAlive: true)
AuthService authService(Ref ref) => FakeAuthService();

@Riverpod(keepAlive: true)
UserDataService userDataService(Ref ref) => UserDataService(
  db: ref.watch(appDatabaseProvider),
  remote: const FakeRemoteDataDeletion(),
);

@Riverpod(keepAlive: true)
PhotoLibrary photoLibrary(Ref ref) => DevicePhotoLibrary();

@Riverpod(keepAlive: true)
PhotoImages photoImages(Ref ref) =>
    PhotoImages(ref.watch(photoLibraryProvider));

@Riverpod(keepAlive: true)
Vision vision(Ref ref) {
  final v = MlKitVision.supported ? MlKitVision() : const NoVision();
  ref.onDispose(v.close);
  return v;
}

@Riverpod(keepAlive: true)
Future<ReverseGeocoder> geocoder(Ref ref) async {
  final kit = await ref.watch(domainKitProvider.future);
  return CachedGeocoder(FakeGeocoder(kit.geo), ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
Future<PhotoAnalyzer> photoAnalyzer(Ref ref) async => PhotoAnalyzer(
  vision: ref.watch(visionProvider),
  geocoder: await ref.watch(geocoderProvider.future),
  db: ref.watch(appDatabaseProvider),
);

@Riverpod(keepAlive: true)
Future<CaptionProvider> captionProvider(Ref ref) async {
  final kit = await ref.watch(domainKitProvider.future);
  return FakeCaptionProvider(kit.geo);
}

@Riverpod(keepAlive: true)
OccasionAiProvider occasionAiService(Ref ref) => const FakeOccasionAiProvider();

@Riverpod(keepAlive: true)
StyleProvider styleProvider(Ref ref) =>
    FakeStyleProvider(ref.watch(photoImagesProvider));

@Riverpod(keepAlive: true)
UpscaleProvider upscaleProvider(Ref ref) =>
    FakeUpscaleProvider(ref.watch(photoImagesProvider));

@Riverpod(keepAlive: true)
CoverArtProvider coverArtProvider(Ref ref) =>
    FakeCoverArtProvider(ref.watch(styleProviderProvider));

@Riverpod(keepAlive: true)
MotionProvider motionProvider(Ref ref) => const FakeMotionProvider();
