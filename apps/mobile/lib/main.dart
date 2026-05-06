import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_api.dart';
import 'theme/kazi_theme.dart';

const _destinations = [
  _ShellDestination('Home', Icons.home_outlined, Icons.home),
  _ShellDestination('Bookings', Icons.calendar_month_outlined, Icons.calendar_month),
  _ShellDestination('Provider', Icons.engineering_outlined, Icons.engineering),
  _ShellDestination(
    'Wallet',
    Icons.account_balance_wallet_outlined,
    Icons.account_balance_wallet,
  ),
];

const _paymentReturnUrl = String.fromEnvironment('KAZI_PAYMENT_RETURN_URL');

const _serviceCategories = [
  'All',
  'Cleaning',
  'Care',
  'Laundry',
  'Wellness',
  'Repairs',
  'Mechanics',
  'Outdoor',
];

const _services = [
  _ServiceData(
    id: 'clean-home',
    category: 'Cleaning',
    title: 'Home Cleaning',
    subtitle: 'Recurring or one-off cleaning for flats, homes, and guest stays.',
    priceFrom: 'From R399',
    eta: 'Next slot in 45 min',
    imageAsset: 'assets/service-images/home-cleaning.jpg',
    icon: Icons.cleaning_services_outlined,
  ),
  _ServiceData(
    id: 'plumbing-fix',
    category: 'Repairs',
    title: 'Leak and Pipe Fix',
    subtitle: 'Repairs, replacements, and diagnostics.',
    priceFrom: 'From R720',
    eta: '21 min avg arrival',
    imageAsset: 'assets/service-images/leak-and-pipe-fix.jpg',
    icon: Icons.plumbing_outlined,
  ),
  _ServiceData(
    id: 'handyman-home',
    category: 'Repairs',
    title: 'Handyman Assist',
    subtitle: 'Assembly, patching, hanging, and repairs.',
    priceFrom: 'From R520',
    eta: 'Same-day availability',
    imageAsset: 'assets/service-images/handyman-assist.jpg',
    imageFit: BoxFit.contain,
    imageAlignment: Alignment.center,
    icon: Icons.handyman_outlined,
  ),
  _ServiceData(
    id: 'appliance-repair',
    category: 'Repairs',
    title: 'Appliance Repair',
    subtitle: 'Fridges, ovens, washing machines, and same-day fault finding.',
    priceFrom: 'From R640',
    eta: 'Today before 18:00',
    imageAsset: 'assets/service-images/appliance-repair.jpg',
    icon: Icons.kitchen_outlined,
  ),
  _ServiceData(
    id: 'ac-cleaning',
    category: 'Cleaning',
    title: 'AC Cleaning',
    subtitle: 'Aircon unit cleaning, filter refreshes, and seasonal maintenance.',
    priceFrom: 'From R430',
    eta: 'Tomorrow morning',
    imageAsset: 'assets/service-images/ac-cleaning.jpg',
    icon: Icons.ac_unit_outlined,
  ),
  _ServiceData(
    id: 'furniture-cleaning',
    category: 'Cleaning',
    title: 'Furniture Cleaning',
    subtitle: 'Sofas, mattresses, carpets, and upholstery refresh services.',
    priceFrom: 'From R520',
    eta: 'Booked today',
    imageAsset: 'assets/service-images/furniture-cleaning.jpg',
    icon: Icons.weekend_outlined,
  ),
  _ServiceData(
    id: 'garden-outdoor',
    category: 'Outdoor',
    title: 'Garden and Outdoor',
    subtitle: 'Yard cleanups, trimming, pressure washing, and outdoor resets.',
    priceFrom: 'From R580',
    eta: 'Next slot today',
    imageAsset: 'assets/service-images/garden-and-outdoor.jpg',
    icon: Icons.yard_outlined,
  ),
  _ServiceData(
    id: 'pest-control',
    category: 'Outdoor',
    title: 'Pest Control',
    subtitle: 'Fast treatment visits for homes, flats, and small businesses.',
    priceFrom: 'From R760',
    eta: 'Booked in under 1 hour',
    imageAsset: 'assets/service-images/pest-control.jpg',
    icon: Icons.pest_control_outlined,
  ),
];

const _walletHistory = [
  _WalletEntryData('Deep Cleaning booking', 'Customer payment received', '+R450', true),
  _WalletEntryData('Provider payout', 'Weekly earnings transfer', '-R1,850', false),
  _WalletEntryData('Promo credit', 'Welcome discount applied', '+R180', true),
  _WalletEntryData('Electrical booking', 'Wallet hold for active job', '-R780', false),
];

String _formatCurrencyFromCents(int cents) {
  final amount = cents / 100;
  final hasDecimals = cents % 100 != 0;
  return 'R${amount.toStringAsFixed(hasDecimals ? 2 : 0)}';
}

String _formatBookingSchedule(DateTime? scheduledAt, {required bool isScheduled}) {
  if (scheduledAt == null) {
    return isScheduled ? 'Scheduled booking' : 'Immediate dispatch';
  }

  final hour = scheduledAt.hour.toString().padLeft(2, '0');
  final minute = scheduledAt.minute.toString().padLeft(2, '0');
  final when = DateUtils.isSameDay(scheduledAt, DateTime.now()) ? 'Today' : 'Later';
  return '$when, $hour:$minute';
}

String _formatPaymentMethodLabel(String value) {
  switch (value.toUpperCase()) {
    case 'CARD':
      return 'Card';
    case 'EFT':
      return 'EFT';
    case 'WALLET':
      return 'Wallet';
    case 'CASH':
      return 'Cash';
    default:
      return value.replaceAll('_', ' ');
  }
}

String _formatPaymentStatusLabel(String value) {
  switch (value.toUpperCase()) {
    case 'PENDING':
      return 'Pending';
    case 'PAID':
      return 'Paid';
    case 'FAILED':
      return 'Failed';
    case 'REFUNDED':
      return 'Refunded';
    default:
      return value.replaceAll('_', ' ');
  }
}

String _normalizeCatalogValue(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

bool _catalogStringsOverlap(String left, String right) {
  if (left.isEmpty || right.isEmpty) {
    return false;
  }

  if (left == right || left.contains(right) || right.contains(left)) {
    return true;
  }

  final leftWords = left.split(' ').where((word) => word.length > 2).toSet();
  final rightWords = right.split(' ').where((word) => word.length > 2).toSet();
  final sharedWords = leftWords.intersection(rightWords);
  return sharedWords.length >= 2;
}

IconData _iconForCategory(String label) {
  final key = label.toLowerCase();
  if (key.contains('clean')) return Icons.cleaning_services_outlined;
  if (key.contains('laundry') || key.contains('dry')) return Icons.local_laundry_service_outlined;
  if (key.contains('care') || key.contains('baby')) return Icons.child_care_outlined;
  if (key.contains('pet')) return Icons.pets_outlined;
  if (key.contains('salon') || key.contains('spa') || key.contains('wellness')) return Icons.spa_outlined;
  if (key.contains('repair')) return Icons.home_repair_service_outlined;
  if (key.contains('mechanic') || key.contains('car')) return Icons.car_repair_outlined;
  if (key.contains('electric')) return Icons.electrical_services_outlined;
  if (key.contains('plumb')) return Icons.plumbing_outlined;
  if (key.contains('appliance') || key.contains('kitchen')) return Icons.kitchen_outlined;
  if (key.contains('garden') || key.contains('outdoor')) return Icons.yard_outlined;
  if (key.contains('pest')) return Icons.pest_control_outlined;
  if (key.contains('hand')) return Icons.handyman_outlined;
  return Icons.home_repair_service_outlined;
}

class _FirebaseRuntimeOptions {
  static const String _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String _messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String _storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const String _androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const String _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const String _iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  static FirebaseOptions? get currentPlatform {
    if (_apiKey.isEmpty || _projectId.isEmpty || _messagingSenderId.isEmpty) {
      return null;
    }

    if (kIsWeb) {
      return null;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      if (_androidAppId.isEmpty) {
        return null;
      }

      return FirebaseOptions(
        apiKey: _apiKey,
        appId: _androidAppId,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (_iosAppId.isEmpty) {
        return null;
      }

      return FirebaseOptions(
        apiKey: _apiKey,
        appId: _iosAppId,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
        iosBundleId: _iosBundleId.isEmpty ? null : _iosBundleId,
      );
    }

    return null;
  }
}

class _AppScope extends InheritedNotifier<_KaziController> {
  const _AppScope({required _KaziController controller, required super.child})
      : super(notifier: controller);

  static _KaziController of(BuildContext context, {bool listen = true}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<_AppScope>()
        : context.getElementForInheritedWidgetOfExactType<_AppScope>()?.widget as _AppScope?;
    assert(scope != null, 'No _AppScope found in context');
    return scope!.notifier!;
  }
}

class _KaziController extends ChangeNotifier {
  static const String _configuredPushToken = String.fromEnvironment('KAZI_FCM_TOKEN');
  static const String _storedSessionKey = 'kazi.mobile.session';
  static const String _rememberSessionKey = 'kazi.mobile.rememberSession';
  static const String _rememberIdentifierKey = 'kazi.mobile.rememberIdentifier';
  static const String _storedIdentifierKey = 'kazi.mobile.identifier';

  _KaziController() {
    bootstrap();
  }

  final KaziApiClient api = KaziApiClient();
  SharedPreferences? _preferences;

  bool isBootstrapping = true;
  bool isRefreshing = false;
  KaziSession? session;
  ApiUser? currentUser;
  bool providerAvailable = false;
  bool providerProfileMissing = false;
  String providerVerificationStatus = 'pending';
  List<ApiProviderDocument> providerDocuments = const [];

  List<String> serviceCategories = List<String>.of(_serviceCategories);
  List<_ServiceData> services = List<_ServiceData>.of(_services);
  List<_BookingData> bookings = const [];
  List<_NotificationData> notifications = const [];
  List<ApiPromo> activePromos = const [];
  ApiReferralSummary? referralSummary;
  List<_ProviderJobData> incomingJobs = const [];
  List<_ProviderJobData> acceptedJobs = const [];
  List<_WalletEntryData> walletHistory = List<_WalletEntryData>.of(_walletHistory);
  void Function(String title, String body)? onForegroundPushMessage;

  StreamSubscription<String>? _pushTokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  String? _devicePushToken;
  String? _syncedPushToken;
  bool _providerTrackingPermissionRequested = false;

  final Map<String, ApiService> _liveServicesById = {};
  final Map<String, ApiServiceCategory> _categoriesById = {};
  String _rememberedIdentifier = '';
  bool _rememberIdentifier = true;
  bool _rememberSession = true;

  bool get isAuthenticated => session != null;
  bool get isCustomer => currentUser?.role == 'customer';
  bool get isProvider => currentUser?.role == 'provider';
  String get rememberedIdentifier => _rememberedIdentifier;
  bool get rememberIdentifier => _rememberIdentifier;
  bool get rememberSession => _rememberSession;
  String get apiBaseUrl => api.baseUrl;
  bool get hasLiveCatalog => _liveServicesById.isNotEmpty;
  int get unreadNotifications => notifications.where((item) => !item.isRead).length;

  Future<void> bootstrap() async {
    _preferences = await SharedPreferences.getInstance();
    _rememberIdentifier = _preferences?.getBool(_rememberIdentifierKey) ?? true;
    _rememberSession = _preferences?.getBool(_rememberSessionKey) ?? true;
    _rememberedIdentifier = _preferences?.getString(_storedIdentifierKey) ?? '';
    await _restorePersistedSession();
    await _initializePushMessaging();
    await loadPublicCatalog();
    isBootstrapping = false;
    notifyListeners();
  }

  Future<void> loadPublicCatalog() async {
    try {
      final categories = await api.listCategories();
      final liveServices = await api.listServices();

      _categoriesById
        ..clear()
        ..addEntries(categories.map((category) => MapEntry(category.id, category)));
      _liveServicesById
        ..clear()
        ..addEntries(liveServices.map((service) => MapEntry(service.id, service)));

      serviceCategories = _mergeCategoryNames(categories);
      services = _mergeCatalogServices(liveServices);
    } catch (_) {
      serviceCategories = List<String>.of(_serviceCategories);
      services = List<_ServiceData>.of(_services);
    }

    notifyListeners();
  }

  Future<void> sendOtp(String phone) {
    return api.sendOtp(phone);
  }

  Future<void> verifyOtp({
    required String phone,
    required String code,
    required String role,
    required bool rememberSession,
    required bool rememberIdentifier,
  }) async {
    session = await api.verifyOtp(phone: phone, code: code, role: role);
    currentUser = session!.user;
    await _persistAuthState(
      identifier: phone,
      rememberSession: rememberSession,
      rememberIdentifier: rememberIdentifier,
    );
    await _syncConfiguredPushToken();
    await refreshAuthenticatedData();
  }

  Future<void> signOut() async {
    session = null;
    currentUser = null;
    providerAvailable = false;
    providerProfileMissing = false;
    providerVerificationStatus = 'pending';
    providerDocuments = const [];
    bookings = const [];
    notifications = const [];
    activePromos = const [];
    referralSummary = null;
    incomingJobs = const [];
    acceptedJobs = const [];
    walletHistory = List<_WalletEntryData>.of(_walletHistory);
    _syncedPushToken = null;
    _providerTrackingPermissionRequested = false;
    await _preferences?.remove(_storedSessionKey);
    notifyListeners();
  }

  Future<void> refreshAuthenticatedData() async {
    if (session == null) return;

    isRefreshing = true;
    notifyListeners();

    try {
      await _syncConfiguredPushToken();
      currentUser = await api.getMe(session!.accessToken);
      final liveBookings = await api.listMyBookings(session!.accessToken);
      final notificationFeed = await api.listNotifications(session!.accessToken);
      activePromos = await api.listActivePromos(session!.accessToken);
      referralSummary = await api.getReferralSummary(session!.accessToken);
      bookings = liveBookings.map(_mapBooking).toList();
      notifications = notificationFeed.items.map(_mapNotification).toList();

      if (isProvider) {
        final providerBookings = liveBookings
            .where((booking) => booking.status != 'completed' && booking.status != 'cancelled')
            .map(_mapProviderJobFromBooking)
            .toList();
        acceptedJobs = providerBookings;

        final openJobs = await api.listAvailableBookings(session!.accessToken);
        incomingJobs = openJobs.map(_mapProviderJobFromBooking).toList();

        try {
          final profile = await api.getMyProviderProfile(session!.accessToken);
          providerAvailable = profile.isAvailable;
          providerVerificationStatus = profile.verificationStatus;
          providerProfileMissing = false;
          providerDocuments = await api.listMyProviderDocuments(session!.accessToken);
        } on KaziApiException catch (error) {
          providerAvailable = false;
          providerVerificationStatus = 'pending';
          providerProfileMissing = error.statusCode == 404;
          providerDocuments = const [];
        }
      } else {
        providerAvailable = false;
        providerProfileMissing = false;
        providerVerificationStatus = 'pending';
        providerDocuments = const [];
        incomingJobs = const [];
        acceptedJobs = const [];
      }

      walletHistory = _buildWalletHistory();
    } finally {
      isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> _restorePersistedSession() async {
    if (_preferences == null || !_rememberSession) {
      return;
    }

    final storedSession = _preferences!.getString(_storedSessionKey);
    if (storedSession == null || storedSession.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(storedSession) as Map<String, dynamic>;
      session = KaziSession.fromJson(decoded);
      currentUser = session!.user;
      await refreshAuthenticatedData();
    } catch (_) {
      session = null;
      currentUser = null;
      await _preferences!.remove(_storedSessionKey);
    }
  }

  Future<void> _persistAuthState({
    required String identifier,
    required bool rememberSession,
    required bool rememberIdentifier,
  }) async {
    _rememberSession = rememberSession;
    _rememberIdentifier = rememberIdentifier;
    _rememberedIdentifier = rememberIdentifier ? identifier : '';

    if (_preferences == null) {
      return;
    }

    await _preferences!.setBool(_rememberSessionKey, rememberSession);
    await _preferences!.setBool(_rememberIdentifierKey, rememberIdentifier);

    if (_rememberedIdentifier.isEmpty) {
      await _preferences!.remove(_storedIdentifierKey);
    } else {
      await _preferences!.setString(_storedIdentifierKey, _rememberedIdentifier);
    }

    if (rememberSession && session != null) {
      await _preferences!.setString(_storedSessionKey, jsonEncode(session!.toJson()));
    } else {
      await _preferences!.remove(_storedSessionKey);
    }
  }

  Future<void> completeProviderOnboarding() async {
    if (session == null) {
      throw const KaziApiException('Sign in as a provider first.');
    }

    await api.onboardProvider(
      accessToken: session!.accessToken,
      serviceArea: 'Johannesburg',
      serviceCategoryIds: _categoriesById.keys.take(3).toList(),
    );

    await refreshAuthenticatedData();
  }

  Future<ApiProviderDocumentUploadResult> uploadProviderDocument({
    required String documentType,
    required PlatformFile file,
  }) async {
    if (session == null) {
      throw const KaziApiException('Sign in as a provider first.');
    }

    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const KaziApiException('The selected file could not be read on this device.');
    }

    final result = await api.uploadProviderDocument(
      accessToken: session!.accessToken,
      documentType: documentType,
      fileBytes: bytes,
      fileName: file.name,
    );

    providerDocuments = result.documents;
    providerVerificationStatus = 'pending';
    providerProfileMissing = false;
    notifyListeners();
    return result;
  }

  Future<void> setProviderAvailability(bool value) async {
    if (session == null) {
      throw const KaziApiException('Sign in as a provider first.');
    }

    final profile = await api.updateAvailability(
      accessToken: session!.accessToken,
      isAvailable: value,
    );
    providerAvailable = profile.isAvailable;
    notifyListeners();
  }

  Future<void> acceptJob(_ProviderJobData job) async {
    if (session == null) {
      throw const KaziApiException('Sign in as a provider first.');
    }

    await api.acceptBooking(accessToken: session!.accessToken, bookingId: job.id);
    await refreshAuthenticatedData();
  }

  Future<void> declineJob(_ProviderJobData job, {String? reason}) async {
    if (session == null) {
      throw const KaziApiException('Sign in as a provider first.');
    }

    await api.declineBooking(
      accessToken: session!.accessToken,
      bookingId: job.id,
      reason: reason ?? 'Provider declined this job.',
    );
    await refreshAuthenticatedData();
  }

  Future<void> advanceBooking(_BookingData booking) async {
    if (session == null) {
      throw const KaziApiException('Sign in as a provider first.');
    }

    final nextStatus = switch (booking.status) {
      _BookingStatus.matched => 'en_route',
      _BookingStatus.enRoute => 'arrived',
      _BookingStatus.arrived => 'in_progress',
      _BookingStatus.inProgress => 'completed',
      _BookingStatus.scheduled => 'pending',
      _ => null,
    };

    if (nextStatus == null) {
      return;
    }

    await api.updateBookingStatus(
      accessToken: session!.accessToken,
      bookingId: booking.id,
      status: nextStatus,
    );

    await refreshAuthenticatedData();
  }

  Future<void> submitReview({
    required _BookingData booking,
    required int rating,
    String? comment,
  }) async {
    if (session == null) {
      throw const KaziApiException('Sign in to leave a review.');
    }

    await api.createReview(
      accessToken: session!.accessToken,
      bookingId: booking.id,
      rating: rating,
      comment: comment,
    );

    await refreshAuthenticatedData();
  }

  Future<void> cancelBooking(_BookingData booking, {required String reason}) async {
    if (session == null) {
      throw const KaziApiException('Sign in first to cancel a booking.');
    }

    await api.cancelBooking(
      accessToken: session!.accessToken,
      bookingId: booking.id,
      reason: reason,
    );
    await refreshAuthenticatedData();
  }

  Future<void> createBooking({
    required _ServiceData service,
    required bool scheduled,
    required String customerAddress,
    required String customerNotes,
    required String paymentMethod,
    String? promoCode,
    Position? customerPosition,
  }) async {
    if (session == null || !isCustomer) {
      throw const KaziApiException('Sign in as a customer to create a booking.');
    }

    final liveService = _resolveLiveService(service);
    if (liveService == null) {
      throw const KaziApiException(
        'This service card is visible in the marketplace, but it is not connected to a live backend service yet.',
      );
    }

    final scheduledAt = scheduled
        ? DateTime.now().add(const Duration(days: 1)).copyWith(hour: 9, minute: 0)
        : null;
    final resolvedCustomerPosition = customerPosition ?? await _tryGetCurrentPosition();

    await api.createBooking(
      accessToken: session!.accessToken,
      serviceCategoryId: liveService.categoryId,
      serviceId: liveService.id,
      type: scheduled ? 'scheduled' : 'instant',
      scheduledAt: scheduledAt?.toIso8601String(),
      customerLat: resolvedCustomerPosition?.latitude,
      customerLng: resolvedCustomerPosition?.longitude,
      customerAddress: customerAddress,
      customerNotes: customerNotes.isEmpty ? null : customerNotes,
      promoCode: promoCode?.trim().isEmpty == true ? null : promoCode?.trim(),
      quotedPriceCents: liveService.basePriceCents,
      paymentMethod: paymentMethod.toLowerCase(),
    );

    await refreshAuthenticatedData();
  }

  Future<Position?> resolveCurrentBookingPosition({bool requestPermissionIfNeeded = true}) {
    return _tryGetCurrentPosition(requestPermissionIfNeeded: requestPermissionIfNeeded);
  }

  Future<String?> resolveCurrentBookingAddress(Position? position) async {
    if (position == null) {
      return null;
    }

    try {
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isEmpty) {
        return null;
      }

      return _formatPlacemarkAddress(placemarks.first);
    } catch (_) {
      return null;
    }
  }

  Future<Position?> _tryGetCurrentPosition({bool requestPermissionIfNeeded = true}) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermissionIfNeeded) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> openHostedPayment(_BookingData booking) async {
    if (session == null || !isCustomer) {
      throw const KaziApiException('Sign in as a customer to pay for a booking.');
    }

    final checkout = await api.createHostedCheckout(
      accessToken: session!.accessToken,
      bookingId: booking.id,
      returnUrl: _paymentReturnUrl.isEmpty ? null : _paymentReturnUrl,
    );

    final checkoutUrl = checkout.checkoutUrl;
    if (checkoutUrl == null || checkoutUrl.isEmpty) {
      throw const KaziApiException('No hosted checkout URL was returned for this booking.');
    }

    final uri = Uri.parse(checkoutUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw KaziApiException('Could not open the payment link: $checkoutUrl');
    }

    await refreshAuthenticatedData();
  }

  Future<void> updateLiveLocation(_BookingData booking) async {
    if (session == null || !isProvider) {
      throw const KaziApiException('Sign in as the assigned provider to share live tracking.');
    }

    final position = await _tryGetCurrentPosition();
    _providerTrackingPermissionRequested = true;
    if (position == null) {
      throw const KaziApiException('Location permission is required to share live tracking.');
    }

    final updatedBooking = await api.updateBookingTracking(
      accessToken: session!.accessToken,
      bookingId: booking.id,
      latitude: position.latitude,
      longitude: position.longitude,
    );

    _replaceBooking(updatedBooking);
  }

  Future<void> syncProviderTrackingForActiveBookings() async {
    if (session == null || !isProvider) {
      return;
    }

    _BookingData? activeBooking;
    for (final booking in bookings) {
      if (booking.supportsLiveTracking) {
        activeBooking = booking;
        break;
      }
    }

    if (activeBooking == null) {
      return;
    }

    final position = await _tryGetCurrentPosition(
      requestPermissionIfNeeded: !_providerTrackingPermissionRequested,
    );
    _providerTrackingPermissionRequested = true;
    if (position == null) {
      return;
    }

    final updatedBooking = await api.updateBookingTracking(
      accessToken: session!.accessToken,
      bookingId: activeBooking.id,
      latitude: position.latitude,
      longitude: position.longitude,
    );

    _replaceBooking(updatedBooking);
  }

  void _replaceBooking(ApiBooking booking) {
    final updatedBooking = _mapBooking(booking);
    bookings = bookings
        .map((item) => item.id == booking.id ? updatedBooking : item)
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> openTrackingMap(_BookingData booking) async {
    final latitude = booking.providerCurrentLat;
    final longitude = booking.providerCurrentLng;
    if (latitude == null || longitude == null) {
      throw const KaziApiException('This booking does not have a live provider location yet.');
    }

    final uri = booking.customerLat != null && booking.customerLng != null
        ? Uri.parse(
            'https://www.google.com/maps/dir/?api=1&origin=${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}&destination=${booking.customerLat!.toStringAsFixed(6)},${booking.customerLng!.toStringAsFixed(6)}&travelmode=driving',
          )
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}',
          );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw const KaziApiException('Could not open the live tracking map.');
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    if (session == null) {
      throw const KaziApiException('Sign in first to manage notifications.');
    }

    await api.markNotificationRead(
      accessToken: session!.accessToken,
      notificationId: notificationId,
    );

    notifications = notifications
        .map(
          (item) => item.id == notificationId
              ? item.copyWith(isRead: true)
              : item,
        )
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> markAllNotificationsRead() async {
    if (session == null) {
      throw const KaziApiException('Sign in first to manage notifications.');
    }

    await api.markAllNotificationsRead(session!.accessToken);
    notifications = notifications
        .map((item) => item.copyWith(isRead: true))
        .toList(growable: false);
    notifyListeners();
  }

  Future<ApiReferralSummary> redeemReferralCode(String referralCode) async {
    if (session == null) {
      throw const KaziApiException('Sign in first to redeem a referral code.');
    }

    final summary = await api.redeemReferralCode(
      accessToken: session!.accessToken,
      referralCode: referralCode.trim(),
    );
    referralSummary = summary;
    currentUser = await api.getMe(session!.accessToken);
    walletHistory = _buildWalletHistory();
    notifyListeners();
    return summary;
  }

  Future<ApiChatThread> getBookingThread(String bookingId) async {
    if (session == null) {
      throw const KaziApiException('Sign in first to open booking chat.');
    }

    return api.getBookingChatThread(
      accessToken: session!.accessToken,
      bookingId: bookingId,
    );
  }

  Future<ApiChatMessage> sendBookingMessage({
    required String bookingId,
    required String message,
  }) async {
    if (session == null) {
      throw const KaziApiException('Sign in first to send booking messages.');
    }

    return api.sendBookingChatMessage(
      accessToken: session!.accessToken,
      bookingId: bookingId,
      message: message,
    );
  }

  Future<ApiBookingCall> startBookingCall(String bookingId) async {
    if (session == null) {
      throw const KaziApiException('Sign in first to call through a booking.');
    }

    return api.startBookingCall(
      accessToken: session!.accessToken,
      bookingId: bookingId,
    );
  }

  Future<void> _syncConfiguredPushToken() async {
    final pushToken = _devicePushToken ?? _configuredPushToken;
    if (session == null) return;
    if (pushToken.isEmpty || pushToken == _syncedPushToken) {
      return;
    }

    await api.updateFcmToken(
      accessToken: session!.accessToken,
      fcmToken: pushToken,
    );
    _syncedPushToken = pushToken;
  }

  Future<void> _initializePushMessaging() async {
    final options = _FirebaseRuntimeOptions.currentPlatform;
    if (options == null) {
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }

      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        _devicePushToken = token;
      }

      _pushTokenRefreshSubscription = messaging.onTokenRefresh.listen((token) {
        _devicePushToken = token;
        _syncedPushToken = null;
        unawaited(_syncConfiguredPushToken());
      });

      _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification != null) {
          onForegroundPushMessage?.call(
            notification.title ?? 'New update',
            notification.body ?? '',
          );
        }

        if (session != null) {
          unawaited(refreshAuthenticatedData());
        }
      });
    } catch (error) {
      debugPrint('Firebase push initialization skipped: $error');
    }
  }

  @override
  void dispose() {
    _pushTokenRefreshSubscription?.cancel();
    _foregroundMessageSubscription?.cancel();
    super.dispose();
  }

  _ServiceData _mapService(ApiService service) {
    final category = service.category ?? _categoriesById[service.categoryId];
    return _ServiceData(
      id: service.id,
      category: category?.name ?? 'General',
      title: service.name,
      subtitle: service.description?.trim().isNotEmpty == true
          ? service.description!.trim()
          : '${service.estimatedDurationMinutes} minute service window.',
      priceFrom: 'From ${_formatCurrencyFromCents(service.basePriceCents)}',
      eta: service.supportsInstantBooking
          ? '${math.max(12, service.estimatedDurationMinutes ~/ 4)} min avg arrival'
          : 'Scheduled slots',
      imageAsset: _imageAssetForService(
        serviceName: service.name,
        categorySlug: category?.slug,
        fallbackId: service.id,
      ),
      icon: _iconForCategory(category?.name ?? service.name),
    );
  }

  String _imageAssetForService({
    required String serviceName,
    String? categorySlug,
    String? fallbackId,
  }) {
    const imageByKey = {
      'clean-home': 'assets/service-images/home-cleaning.jpg',
      'clean-deep': 'assets/service-images/deep-cleaning.jpg',
      'clean-move': 'assets/service-images/maid-service.jpg',
      'laundry-dry-cleaning': 'assets/service-images/laundry-dry-cleaning.jpg',
      'babysitting': 'assets/service-images/babysitting.jpg',
      'pet-care': 'assets/service-images/pet-care.jpg',
      'womens-salon': 'assets/service-images/salon-at-home.jpg',
      'spa-massage': 'assets/service-images/spa-and-massage.jpg',
      'mechanic-mobile': 'assets/service-images/book-a-mechanic.jpg',
      'electrical-urgent': 'assets/service-images/urgent-electrical.jpg',
      'plumbing-fix': 'assets/service-images/leak-and-pipe-fix.jpg',
      'handyman-home': 'assets/service-images/handyman-assist.jpg',
      'appliance-repair': 'assets/service-images/appliance-repair.jpg',
      'ac-cleaning': 'assets/service-images/ac-cleaning.jpg',
      'furniture-cleaning': 'assets/service-images/furniture-cleaning.jpg',
      'garden-outdoor': 'assets/service-images/garden-and-outdoor.jpg',
      'pest-control': 'assets/service-images/pest-control.jpg',
    };

    final normalizedName = _normalizeServiceImageKey(serviceName);
    final normalizedCategory = categorySlug == null
        ? null
        : _normalizeServiceImageKey(categorySlug);
    final normalizedId = fallbackId == null
        ? null
        : _normalizeServiceImageKey(fallbackId);

    return imageByKey[normalizedName] ??
        imageByKey[normalizedCategory] ??
        imageByKey[normalizedId] ??
        'assets/service-images/home-cleaning.jpg';
  }

  String _normalizeServiceImageKey(String value) {
    return value
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  List<String> _mergeCategoryNames(List<ApiServiceCategory> categories) {
    final merged = <String>{
      ..._serviceCategories.where((category) => category != 'All'),
    };

    for (final category in categories) {
      if (category.name.trim().isNotEmpty) {
        merged.add(category.name.trim());
      }
    }

    return ['All', ...merged];
  }

  List<_ServiceData> _mergeCatalogServices(List<ApiService> liveServices) {
    final liveCatalog = liveServices.map(_mapService).toList(growable: false);
    final matchedLiveIds = <String>{};
    final merged = <_ServiceData>[];

    for (final curated in _services) {
      _ServiceData resolved = curated;

      for (final live in liveCatalog) {
        if (matchedLiveIds.contains(live.id)) {
          continue;
        }

        final similarTitle = _catalogStringsOverlap(
          _normalizeCatalogValue(live.title),
          _normalizeCatalogValue(curated.title),
        );

        if (similarTitle) {
          resolved = live;
          matchedLiveIds.add(live.id);
          break;
        }
      }

      merged.add(resolved);
    }

    for (final live in liveCatalog) {
      if (!matchedLiveIds.contains(live.id)) {
        merged.add(live);
      }
    }

    return merged;
  }

  ApiService? _resolveLiveService(_ServiceData service) {
    final directMatch = _liveServicesById[service.id];
    if (directMatch != null) {
      return directMatch;
    }

    final normalizedTitle = _normalizeCatalogValue(service.title);
    final normalizedCategory = _normalizeCatalogValue(service.category);
    final categoryMatches = <ApiService>[];

    for (final live in _liveServicesById.values) {
      final category = live.category ?? _categoriesById[live.categoryId];
      final liveTitle = _normalizeCatalogValue(live.name);
      final liveCategory = _normalizeCatalogValue(category?.name ?? '');

      if (_catalogStringsOverlap(liveTitle, normalizedTitle)) {
        return live;
      }

      if (liveCategory == normalizedCategory) {
        categoryMatches.add(live);
      }
    }

    if (categoryMatches.length == 1) {
      return categoryMatches.first;
    }

    return null;
  }

  _BookingData _mapBooking(ApiBooking booking) {
    final liveService = _liveServicesById[booking.serviceId];
    final title = liveService?.name ?? 'Service booking';
    return _BookingData(
      id: booking.id,
      serviceTitle: title,
      address: booking.customerAddress ?? 'Johannesburg',
      schedule: _formatBookingSchedule(
        booking.scheduledAt,
        isScheduled: booking.type == 'scheduled',
      ),
      status: _mapBookingStatus(booking),
      paymentMethod: booking.paymentMethod.toUpperCase(),
      paymentStatus: booking.paymentStatus.toUpperCase(),
      amount: _formatCurrencyFromCents(booking.displayPriceCents),
      customerLat: booking.customerLat,
      customerLng: booking.customerLng,
      providerCurrentLat: booking.providerCurrentLat,
      providerCurrentLng: booking.providerCurrentLng,
      providerLocationUpdatedAt: booking.providerLocationUpdatedAt,
      isRated: booking.isRated,
      customerHasRated: booking.customerHasRated,
      providerHasRated: booking.providerHasRated,
    );
  }

  _NotificationData _mapNotification(ApiNotification notification) {
    return _NotificationData(
      id: notification.id,
      title: notification.title,
      body: notification.body,
      type: notification.type,
      isRead: notification.isRead,
      createdAt: notification.createdAt,
    );
  }

  _ProviderJobData _mapProviderJobFromBooking(ApiBooking booking) {
    final liveService = _liveServicesById[booking.serviceId];
    return _ProviderJobData(
      id: booking.id,
      title: liveService?.name ?? booking.bookingRef,
      timing: _formatBookingSchedule(
        booking.scheduledAt,
        isScheduled: booking.type == 'scheduled',
      ),
      pay: _formatCurrencyFromCents(booking.displayPriceCents),
      distance: booking.type == 'instant' ? 'Local dispatch' : 'Scheduled route',
      category: liveService?.category?.name ?? 'General',
    );
  }

  _BookingStatus _mapBookingStatus(ApiBooking booking) {
    return switch (booking.status) {
      'pending' => booking.type == 'scheduled' ? _BookingStatus.scheduled : _BookingStatus.requested,
      'accepted' => _BookingStatus.matched,
      'en_route' => _BookingStatus.enRoute,
      'arrived' => _BookingStatus.arrived,
      'in_progress' => _BookingStatus.inProgress,
      'completed' => _BookingStatus.completed,
      'cancelled' => _BookingStatus.cancelled,
      'disputed' => _BookingStatus.cancelled,
      _ => _BookingStatus.requested,
    };
  }

  List<_WalletEntryData> _buildWalletHistory() {
    if (bookings.isEmpty) {
      return List<_WalletEntryData>.of(_walletHistory);
    }

    return bookings.take(6).map((booking) {
      final isCredit = isProvider && booking.status == _BookingStatus.completed;
      return _WalletEntryData(
        booking.serviceTitle,
        booking.schedule,
        '${isCredit ? '+' : '-'}${booking.amount.replaceFirst('R', 'R')}',
        isCredit,
      );
    }).toList();
  }
}

Future<void> _showAuthSheet(BuildContext context, {String initialRole = 'customer'}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _AuthSheet(initialRole: initialRole),
  );
}

Future<String?> _showReasonSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String confirmLabel,
  required List<_ActionReasonOption> options,
}) {
  final otherController = TextEditingController();
  String? selectedValue = options.firstOrNull?.value;

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final selectedOption = options.where((option) => option.value == selectedValue).firstOrNull;
          final requiresCustomReason = selectedOption?.requiresCustomReason ?? false;
          final canSubmit = selectedOption != null && (!requiresCustomReason || otherController.text.trim().isNotEmpty);

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  Text(subtitle, style: const TextStyle(height: 1.45)),
                  const SizedBox(height: 16),
                  ...options.map(
                    (option) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setModalState(() {
                            selectedValue = option.value;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: selectedValue == option.value ? const Color(0xFFE6F4EC) : KaziTheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selectedValue == option.value ? KaziTheme.primaryGreen : KaziTheme.border,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                selectedValue == option.value
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: selectedValue == option.value
                                    ? KaziTheme.primaryGreen
                                    : const Color(0xFF6B756E),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(option.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    if (option.subtitle != null) ...[
                                      const SizedBox(height: 4),
                                      Text(option.subtitle!, style: const TextStyle(height: 1.4, color: Color(0xFF4F5B53))),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (requiresCustomReason) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: otherController,
                      maxLines: 3,
                      onChanged: (_) => setModalState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Add your reason',
                        hintText: 'Give a short reason for the cancellation',
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: canSubmit
                        ? () {
                            final result = requiresCustomReason
                                ? otherController.text.trim()
                                : selectedOption.label;
                            Navigator.of(context).pop(result);
                          }
                        : null,
                    child: Text(confirmLabel),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(otherController.dispose);
}

const List<_ActionReasonOption> _customerCancellationReasons = [
  _ActionReasonOption(
    value: 'slow_arrival',
    label: 'Driver took too long to arrive',
    subtitle: 'Use this when the provider is delayed or the ETA no longer works for you.',
  ),
  _ActionReasonOption(
    value: 'not_moving',
    label: 'Driver is not getting closer',
    subtitle: 'Good for trips where live tracking is stalled or progress looks off.',
  ),
  _ActionReasonOption(
    value: 'mistake',
    label: 'Booked by mistake',
  ),
  _ActionReasonOption(
    value: 'change_details',
    label: 'Need to change address or booking details',
  ),
  _ActionReasonOption(
    value: 'no_longer_needed',
    label: 'I no longer need this service',
  ),
  _ActionReasonOption(
    value: 'other',
    label: 'Other',
    requiresCustomReason: true,
  ),
];

const List<_ActionReasonOption> _providerDeclineReasons = [
  _ActionReasonOption(
    value: 'too_far',
    label: 'Pickup is too far away',
  ),
  _ActionReasonOption(
    value: 'running_late',
    label: 'Running late on another trip',
  ),
  _ActionReasonOption(
    value: 'vehicle_issue',
    label: 'Vehicle or equipment issue',
  ),
  _ActionReasonOption(
    value: 'details_missing',
    label: 'Not enough job details',
  ),
  _ActionReasonOption(
    value: 'other',
    label: 'Other',
    requiresCustomReason: true,
  ),
];

const List<_ActionReasonOption> _providerCancellationReasons = [
  _ActionReasonOption(
    value: 'customer_unreachable',
    label: 'Customer is unreachable',
  ),
  _ActionReasonOption(
    value: 'delay',
    label: 'Traffic or delay is too severe',
  ),
  _ActionReasonOption(
    value: 'vehicle_issue',
    label: 'Vehicle or equipment issue',
  ),
  _ActionReasonOption(
    value: 'emergency',
    label: 'Emergency or safety issue',
  ),
  _ActionReasonOption(
    value: 'other',
    label: 'Other',
    requiresCustomReason: true,
  ),
];

class _ActionReasonOption {
  const _ActionReasonOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.requiresCustomReason = false,
  });

  final String value;
  final String label;
  final String? subtitle;
  final bool requiresCustomReason;
}

class _AuthSheet extends StatefulWidget {
  const _AuthSheet({required this.initialRole});

  final String initialRole;

  @override
  State<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<_AuthSheet> {
  late final TextEditingController _phoneController;
  final TextEditingController _codeController = TextEditingController();
  late String _role;
  bool _otpRequested = false;
  bool _busy = false;
  bool _rememberSession = true;
  bool _rememberIdentifier = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final controller = _AppScope.of(context, listen: false);
    _phoneController = TextEditingController(
      text: controller.rememberedIdentifier,
    );
    _role = widget.initialRole;
    _rememberSession = controller.rememberSession;
    _rememberIdentifier = controller.rememberIdentifier;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _AppScope.of(context).sendOtp(_phoneController.text.trim());
      if (!mounted) return;
      setState(() => _otpRequested = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _AppScope.of(context).verifyOtp(
        phone: _phoneController.text.trim(),
        code: _codeController.text.trim(),
        role: _role,
        rememberSession: _rememberSession,
        rememberIdentifier: _rememberIdentifier,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sign in to KAZI', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Enter your South African mobile number to receive a one-time verification code and continue securely.'),
            const SizedBox(height: 20),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'South African mobile number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['customer', 'provider']
                  .map(
                    (role) => ChoiceChip(
                      label: Text(role == 'customer' ? 'Customer' : 'Provider'),
                      selected: _role == role,
                      onSelected: (_) => setState(() => _role = role),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _rememberSession,
              onChanged: (value) => setState(() => _rememberSession = value ?? true),
              title: const Text('Stay signed in on this device'),
              subtitle: const Text('Keep your customer session active so booking does not request OTP again.'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _rememberIdentifier,
              onChanged: (value) => setState(() => _rememberIdentifier = value ?? true),
              title: const Text('Remember this mobile number'),
              subtitle: const Text('Prefill your number next time without storing a password.'),
            ),
            if (_otpRequested) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'OTP code',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : (_otpRequested ? _verifyOtp : _requestOtp),
              child: Text(_busy ? 'Please wait...' : (_otpRequested ? 'Verify OTP' : 'Send OTP')),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KaziApp());
}

class KaziApp extends StatefulWidget {
  const KaziApp({super.key});

  @override
  State<KaziApp> createState() => _KaziAppState();
}

class _KaziAppState extends State<KaziApp> {
  late final _KaziController _controller;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _controller = _KaziController();
    _controller.onForegroundPushMessage = _showForegroundPushMessage;
  }

  @override
  void dispose() {
    _controller.onForegroundPushMessage = null;
    _controller.dispose();
    super.dispose();
  }

  void _showForegroundPushMessage(String title, String body) {
    final message = body.isEmpty ? title : '$title\n$body';
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AppScope(
      controller: _controller,
      child: MaterialApp(
        title: 'KAZI',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _scaffoldMessengerKey,
        theme: KaziTheme.light(),
        home: const KaziShell(),
      ),
    );
  }
}

class KaziShell extends StatefulWidget {
  const KaziShell({super.key});

  @override
  State<KaziShell> createState() => _KaziShellState();
}

class _KaziShellState extends State<KaziShell> {
  int _selectedIndex = 0;

  Future<void> _openNotifications() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _NotificationsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _AppScope.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 840;
        final isExpandedRail = constraints.maxWidth >= 1240;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 20,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_destinations[_selectedIndex].label),
                Text(
                  isTablet
                      ? 'Johannesburg bookings, provider updates, and wallet activity'
                      : 'Fast booking flow for customers and providers',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              if (controller.isAuthenticated)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: KaziTheme.surface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('${controller.currentUser?.displayName ?? 'User'} • ${controller.currentUser?.role ?? ''}'),
                )
              else
                TextButton(
                  onPressed: () => _showAuthSheet(context),
                  child: const Text('Sign in'),
                ),
              if (constraints.maxWidth >= 560)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: KaziTheme.surface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.place_outlined, size: 18, color: KaziTheme.primaryGreen),
                      SizedBox(width: 6),
                      Text('Johannesburg'),
                    ],
                  ),
                ),
              IconButton(
                onPressed: controller.refreshAuthenticatedData,
                icon: const Icon(Icons.refresh_outlined),
              ),
              IconButton(
                onPressed: controller.isAuthenticated ? _openNotifications : () => _showAuthSheet(context),
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none_outlined),
                    if (controller.unreadNotifications > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD62828),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (controller.isAuthenticated)
                IconButton(
                  onPressed: controller.signOut,
                  icon: const Icon(Icons.logout_outlined),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Row(
              children: [
                if (isTablet)
                  _ShellRail(
                    selectedIndex: _selectedIndex,
                    extended: isExpandedRail,
                    onSelected: (index) => setState(() => _selectedIndex = index),
                  ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1320),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: KeyedSubtree(
                          key: ValueKey(_selectedIndex),
                          child: _buildPage(_selectedIndex),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: isTablet
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) => setState(() => _selectedIndex = index),
                  destinations: _destinations
                      .map(
                        (destination) => NavigationDestination(
                          icon: Icon(destination.icon),
                          selectedIcon: Icon(destination.selectedIcon),
                          label: destination.label,
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const _CustomerHomePage();
      case 1:
        return const _BookingsPage();
      case 2:
        return const _ProviderHubPage();
      default:
        return const _WalletPage();
    }
  }
}

class _ShellRail extends StatelessWidget {
  const _ShellRail({
    required this.selectedIndex,
    required this.extended,
    required this.onSelected,
  });

  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: extended ? 240 : 88,
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFFD9DED8))),
      ),
      child: Column(
        crossAxisAlignment: extended ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: extended ? double.infinity : 56,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: KaziTheme.primaryGreen,
              borderRadius: BorderRadius.circular(24),
            ),
            child: extended
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KAZI',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Adaptive mobile ops shell',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  )
                : const Icon(Icons.bolt, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: NavigationRail(
              selectedIndex: selectedIndex,
              extended: extended,
              backgroundColor: Colors.transparent,
              labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
              onDestinationSelected: onSelected,
              destinations: _destinations
                  .map(
                    (destination) => NavigationRailDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selectedIcon),
                      label: Text(destination.label),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerHomePage extends StatefulWidget {
  const _CustomerHomePage();

  @override
  State<_CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<_CustomerHomePage> {
  final GlobalKey _browseServicesSectionKey = GlobalKey();
  String _selectedCategory = _serviceCategories.first;
  String _searchQuery = '';

  void _openCustomerSignIn() {
    _showAuthSheet(context, initialRole: 'customer');
  }

  Future<void> _scrollToBrowseServices() async {
    final targetContext = _browseServicesSectionKey.currentContext;
    if (targetContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<_ServiceData> get _filteredServices {
    final controller = _AppScope.of(context);

    return controller.services.where((service) {
      final categoryMatch = _selectedCategory == 'All' || service.category == _selectedCategory;
      final query = _searchQuery.trim().toLowerCase();
      final queryMatch = query.isEmpty ||
          service.title.toLowerCase().contains(query) ||
          service.subtitle.toLowerCase().contains(query);
      return categoryMatch && queryMatch;
    }).toList();
  }

  Future<void> _openBookingSheet(_ServiceData service, {bool scheduledDefault = false}) async {
    final controller = _AppScope.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (!controller.isCustomer) {
      await _showAuthSheet(context, initialRole: 'customer');
      if (!mounted || !controller.isCustomer) {
        return;
      }
    }

    final addressController = TextEditingController();
    final notesController = TextEditingController();
    final promoController = TextEditingController();
    var bookingPosition = await controller.resolveCurrentBookingPosition();
    var usingCurrentLocation = bookingPosition != null;
    if (bookingPosition != null) {
      final detectedAddress = await controller.resolveCurrentBookingAddress(bookingPosition);
      if (!mounted) {
        return;
      }
      addressController.text = detectedAddress ?? _formatPinnedLocationLabel(bookingPosition);
    }
    if (!mounted) {
      return;
    }
    var scheduled = scheduledDefault;
    var paymentMethod = 'Card';
    var submitting = false;
    var refreshingLocation = false;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.title, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(service.subtitle, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 20),
                    TextField(
                      controller: addressController,
                      onChanged: (_) {
                        if (usingCurrentLocation) {
                          setModalState(() => usingCurrentLocation = false);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Pickup or service address',
                        hintText: 'Use current location or type an address',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F1E8),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFD7CFBE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.my_location_outlined, size: 18, color: Color(0xFF1A231D)),
                              const SizedBox(width: 8),
                              Text(
                                bookingPosition != null
                                    ? (usingCurrentLocation ? 'Using your current location' : 'Current location available')
                                    : 'Location pin missing',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A231D)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            bookingPosition != null
                                ? (usingCurrentLocation
                                    ? 'Pinned to your phone location. You can still type a different address below.'
                                    : 'You switched to a typed address. Tap below if you want to reuse your current pin.')
                                : 'Add your street address or capture your current position so the provider can route to you.',
                          ),
                          if (bookingPosition != null) ...[
                            const SizedBox(height: 6),
                            Builder(
                              builder: (context) {
                                final pinnedPosition = bookingPosition!;
                                return Text(
                                  '${pinnedPosition.latitude.toStringAsFixed(5)}, ${pinnedPosition.longitude.toStringAsFixed(5)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: submitting || refreshingLocation
                                ? null
                                : () async {
                                    setModalState(() {
                                      refreshingLocation = true;
                                      error = null;
                                    });
                                    final resolvedPosition = await controller.resolveCurrentBookingPosition();
                                    final resolvedAddress = await controller.resolveCurrentBookingAddress(resolvedPosition);
                                    if (!mounted) return;
                                    setModalState(() {
                                      bookingPosition = resolvedPosition;
                                      usingCurrentLocation = resolvedPosition != null;
                                      if (resolvedPosition != null) {
                                        addressController.text =
                                            resolvedAddress ?? _formatPinnedLocationLabel(resolvedPosition);
                                        addressController.selection = TextSelection.fromPosition(
                                          TextPosition(offset: addressController.text.length),
                                        );
                                      }
                                      refreshingLocation = false;
                                    });
                                  },
                            icon: const Icon(Icons.gps_fixed),
                            label: Text(
                              refreshingLocation
                                  ? 'Detecting location...'
                                  : bookingPosition != null
                                      ? 'Refresh current location'
                                      : 'Use my current location',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes for the provider',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: promoController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Promo code',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (controller.activePromos.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: controller.activePromos
                            .take(4)
                            .map(
                              (promo) => ActionChip(
                                label: Text(promo.code),
                                onPressed: () => setModalState(() => promoController.text = promo.code),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Schedule for later'),
                      subtitle: Text(scheduled ? 'Tomorrow, 09:00' : 'Dispatch as soon as possible'),
                      value: scheduled,
                      onChanged: (value) => setModalState(() => scheduled = value),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Card', 'Cash', 'Wallet']
                          .map(
                            (method) => ChoiceChip(
                              label: Text(method),
                              selected: paymentMethod == method,
                              onSelected: (_) => setModalState(() => paymentMethod = method),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: submitting
                          ? null
                          : () async {
                              setModalState(() {
                                submitting = true;
                                error = null;
                              });

                              try {
                                final trimmedAddress = addressController.text.trim();
                                final bookingPositionForSubmit = usingCurrentLocation ? bookingPosition : null;
                                if (trimmedAddress.isEmpty && bookingPositionForSubmit == null) {
                                  throw const KaziApiException(
                                    'Add your service address or enable your current location before requesting a provider.',
                                  );
                                }

                                await controller.createBooking(
                                  service: service,
                                  scheduled: scheduled,
                                  customerAddress: trimmedAddress.isEmpty && bookingPositionForSubmit != null
                                      ? _formatPinnedLocationLabel(bookingPositionForSubmit)
                                      : trimmedAddress,
                                  customerNotes: notesController.text.trim(),
                                  paymentMethod: paymentMethod,
                                  promoCode: promoController.text.trim(),
                                  customerPosition: bookingPositionForSubmit,
                                );

                                if (!mounted) return;
                                navigator.pop();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${service.title} requested for ${scheduled ? 'tomorrow' : 'immediate dispatch'} via $paymentMethod.',
                                    ),
                                  ),
                                );
                              } catch (err) {
                                setModalState(() => error = err.toString());
                              } finally {
                                if (mounted) {
                                  setModalState(() => submitting = false);
                                }
                              }
                            },
                      child: Text(submitting ? 'Submitting...' : (scheduled ? 'Schedule booking' : 'Request now')),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!, style: const TextStyle(color: Colors.redAccent)),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    addressController.dispose();
    notesController.dispose();
    promoController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _AppScope.of(context);
    final services = _filteredServices;
    final featuredOfferings = services.length <= 5 ? services : services.take(5).toList(growable: false);
    final categoryOptions = controller.serviceCategories;
    const cityLabel = 'Johannesburg';

    const trustHighlights = [
      ('Top rated professionals', 'Reliable, vetted providers with strong marketplace ratings.', Icons.star_rounded),
      ('Same-day availability', 'Book in under a minute and request help for today.', Icons.calendar_today_rounded),
      ('Clean value pricing', 'Transparent pricing with instant and scheduled options.', Icons.bar_chart_rounded),
      ('All-in-one app', 'Book, track, pay, review, and reorder in one place.', Icons.apps_rounded),
    ];

    const testimonials = [
      (
        'It felt premium from the moment I opened the app. Booking was simple and the cleaner arrived exactly when expected.',
        'Nadia',
      ),
      (
        'The provider updates and live tracking make it feel much more polished than a normal services app.',
        'Shereen',
      ),
      (
        'I like that I can move from home cleaning to laundry or repairs without relearning the app.',
        'Kareem',
      ),
    ];

    if (!categoryOptions.contains(_selectedCategory)) {
      _selectedCategory = categoryOptions.first;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _JustlifeInspiredHero(
            cityLabel: cityLabel,
            onBrowsePressed: _scrollToBrowseServices,
            onLocationPressed: controller.services.isEmpty
                ? () {}
                : () => _openBookingSheet(controller.services.first, scheduledDefault: true),
            onSignInPressed: controller.isAuthenticated ? null : _openCustomerSignIn,
          ),
          const SizedBox(height: 28),
          if (featuredOfferings.isNotEmpty) ...[
            const _SectionHeading(
              title: 'Signature offerings on rotation',
              subtitle: 'A moving spotlight on the services that define the KAZI experience before you browse the full catalogue.',
            ),
            const SizedBox(height: 12),
            _OfferingCarousel(
              offerings: featuredOfferings,
              onBook: (service) => _openBookingSheet(service),
            ),
            const SizedBox(height: 28),
          ],
          const _SectionHeading(
            title: 'Browse all services',
            subtitle: 'Search the full marketplace, compare options, and book from the same clean flow.',
          ),
          const SizedBox(height: 12),
          Container(
            key: _browseServicesSectionKey,
            child: _SurfaceCard(
              backgroundColor: const Color(0xFFFFFCF2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search mechanics, cleaning, plumbing, or appliance repair',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categoryOptions
                        .map(
                          (category) {
                            final selected = _selectedCategory == category;
                            return ChoiceChip(
                              label: Text(
                                category,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: selected ? Colors.white : KaziTheme.primaryGreen,
                                ),
                              ),
                              avatar: selected
                                  ? const Icon(Icons.check_circle, size: 16, color: Colors.white)
                                  : null,
                              showCheckmark: false,
                              backgroundColor: const Color(0xFFFFF7DE),
                              selectedColor: KaziTheme.primaryGreen,
                              side: BorderSide(
                                color: selected ? KaziTheme.primaryGreen : const Color(0xFFE2C96F),
                              ),
                              selected: selected,
                              onSelected: (_) => setState(() => _selectedCategory = category),
                            );
                          },
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              return _ResponsiveGrid(
                minTileWidth: 270,
                maxColumns: 3,
                children: services
                    .map(
                      (service) => _ServiceFlowCard(
                        data: service,
                        onBook: () => _openBookingSheet(service),
                        onSchedule: () => _openBookingSheet(service, scheduledDefault: true),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 28),
          const _SectionHeading(
            title: 'There are so many reasons to love KAZI',
            subtitle: 'The experience is built to feel reliable, premium, and simple from the first screen.',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              return _ResponsiveGrid(
                minTileWidth: 210,
                maxColumns: 4,
                children: trustHighlights
                    .map(
                      (entry) => _TrustFeatureCard(
                        title: entry.$1,
                        body: entry.$2,
                        icon: entry.$3,
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 28),
          const _SectionHeading(
            title: 'What customers say about KAZI',
            subtitle: 'A cleaner home-services experience should feel calm, credible, and easy to repeat.',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              return _ResponsiveGrid(
                minTileWidth: 250,
                maxColumns: 3,
                children: testimonials
                    .map(
                      (entry) => _TestimonialCard(
                        quote: entry.$1,
                        customerName: entry.$2,
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 28),
          _PromisePanel(
            onPrimaryPressed: controller.services.isEmpty ? () {} : () => _openBookingSheet(controller.services.first),
            onSecondaryPressed: controller.isAuthenticated ? null : _openCustomerSignIn,
          ),
        ],
      ),
    );
  }
}

class _JustlifeInspiredHero extends StatelessWidget {
  const _JustlifeInspiredHero({
    required this.cityLabel,
    required this.onBrowsePressed,
    required this.onLocationPressed,
    this.onSignInPressed,
  });

  final String cityLabel;
  final VoidCallback onBrowsePressed;
  final VoidCallback onLocationPressed;
  final VoidCallback? onSignInPressed;

  @override
  Widget build(BuildContext context) {
    Widget buildContent() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE7A3),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE1B645)),
            ),
            child: const Text(
              '#1 home services app for your day-to-day life',
              style: TextStyle(
                color: KaziTheme.primaryGreen,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Where would you like to receive your service?',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 42,
                  height: 1.04,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Start with your location, then browse trusted cleaning, repairs, laundry, pet care, and home support with a calmer premium flow.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF526056),
                  height: 1.6,
                ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF1),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFDCCB8A)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD76A),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.location_on_outlined, color: KaziTheme.primaryGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Service area',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$cityLabel and nearby coverage with fast dispatch windows.',
                        style: const TextStyle(color: Color(0xFF56645A), height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: onBrowsePressed,
                style: FilledButton.styleFrom(
                  backgroundColor: KaziTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                child: const Text('Browse services'),
              ),
              OutlinedButton.icon(
                onPressed: onLocationPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: KaziTheme.primaryGreen,
                  side: const BorderSide(color: Color(0xFFB8C5B7)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                icon: const Icon(Icons.location_on_outlined),
                label: const Text('Choose location'),
              ),
              if (onSignInPressed != null)
                TextButton(
                  onPressed: onSignInPressed,
                  style: TextButton.styleFrom(
                    foregroundColor: KaziTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  child: const Text('Sign in'),
                ),
            ],
          ),
        ],
      );
    }

    Widget buildVisualPanel() {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _HeroBadge(icon: Icons.star_rounded, label: 'Top rated'),
              SizedBox(width: 10),
              _HeroBadge(icon: Icons.schedule_rounded, label: 'Same day'),
            ],
          ),
          SizedBox(height: 18),
          SizedBox(
            height: 164,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Align(
                    child: _HeroSunburst(),
                  ),
                ),
                Positioned(top: 12, left: 6, child: _FloatingTile(color: Color(0xFFFFCB3D), icon: Icons.cleaning_services_rounded)),
                Positioned(top: 0, right: 20, child: _FloatingTile(color: Color(0xFFCBE8D2), icon: Icons.home_repair_service_rounded)),
                Positioned(bottom: 16, left: 36, child: _FloatingTile(color: Color(0xFFFFE9A8), icon: Icons.local_laundry_service_rounded)),
                Positioned(bottom: 4, right: 0, child: _FloatingTile(color: Color(0xFFDCF1E2), icon: Icons.pets_rounded)),
                Positioned.fill(
                  child: Align(
                    child: _CenterHeroCard(),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 18),
          Text(
            'A cleaner, calmer booking experience',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF143424),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Move from browsing to booking, live tracking, and payments without the screen feeling crowded.',
            style: TextStyle(color: Color(0xFF58675C), height: 1.55),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF6D8),
            Color(0xFFEAF6EE),
            Color(0xFFD5EBD9),
          ],
          stops: [0.0, 0.48, 1.0],
        ),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0xFFD6DDCF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12003E25),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 840;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 11, child: buildContent()),
                const SizedBox(width: 28),
                const Expanded(flex: 9, child: _HeroVisualPanel()),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildContent(),
              const SizedBox(height: 28),
              buildVisualPanel(),
            ],
          );
        },
      ),
    );
  }
}

class _HeroVisualPanel extends StatelessWidget {
  const _HeroVisualPanel();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _HeroBadge(icon: Icons.star_rounded, label: 'Top rated'),
            SizedBox(width: 10),
            _HeroBadge(icon: Icons.schedule_rounded, label: 'Same day'),
          ],
        ),
        SizedBox(height: 18),
        SizedBox(
          height: 164,
          child: Stack(
            children: [
              Positioned.fill(
                child: Align(
                  child: _HeroSunburst(),
                ),
              ),
              Positioned(top: 12, left: 6, child: _FloatingTile(color: Color(0xFFFFCB3D), icon: Icons.cleaning_services_rounded)),
              Positioned(top: 0, right: 20, child: _FloatingTile(color: Color(0xFFCBE8D2), icon: Icons.home_repair_service_rounded)),
              Positioned(bottom: 16, left: 36, child: _FloatingTile(color: Color(0xFFFFE9A8), icon: Icons.local_laundry_service_rounded)),
              Positioned(bottom: 4, right: 0, child: _FloatingTile(color: Color(0xFFDCF1E2), icon: Icons.pets_rounded)),
              Positioned.fill(
                child: Align(
                  child: _CenterHeroCard(),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 18),
        Text(
          'A cleaner, calmer booking experience',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF143424),
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Move from browsing to booking, live tracking, and payments without the screen feeling crowded.',
          style: TextStyle(color: Color(0xFF58675C), height: 1.55),
        ),
      ],
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD7C98C)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: KaziTheme.primaryGreen),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _FloatingTile extends StatelessWidget {
  const _FloatingTile({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18004D2B),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, color: KaziTheme.primaryGreen, size: 28),
    );
  }
}

class _HeroSunburst extends StatefulWidget {
  const _HeroSunburst();

  @override
  State<_HeroSunburst> createState() => _HeroSunburstState();
}

class _HeroSunburstState extends State<_HeroSunburst> with SingleTickerProviderStateMixin {
  late final bool _animate;
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _animate = _shouldAnimate();
    if (_animate) {
      _controller = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  bool _shouldAnimate() {
    var animate = true;
    assert(() {
      animate = false;
      return true;
    }());
    return animate;
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _animate ? _controller! : const AlwaysStoppedAnimation(0),
      child: SizedBox(
        width: 146,
        height: 146,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (var index = 0; index < 12; index++)
              Transform.rotate(
                angle: (math.pi * 2 * index) / 12,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 8,
                    height: 28,
                    decoration: BoxDecoration(
                      color: KaziTheme.accentGold.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33FFB81C),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0xFFFFF0B6),
                    Color(0xFFFFC83D),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x44FFB81C),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: SizedBox(
                width: 72,
                height: 72,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterHeroCard extends StatelessWidget {
  const _CenterHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD7C98C)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16003E25),
            blurRadius: 24,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Book fast',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF143424),
              height: 1.05,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Live tracking',
            style: TextStyle(
              color: KaziTheme.primaryGreen,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Built-in pay',
            style: TextStyle(
              color: Color(0xFF5F6C63),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _ServiceShortcutTile extends StatelessWidget {
  const _ServiceShortcutTile({required this.data, required this.onTap});

  final _ServiceData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: _SurfaceCard(
        backgroundColor: Colors.white,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: KaziTheme.softGold,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(data.icon, color: KaziTheme.primaryGreen, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              data.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF173325),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustFeatureCard extends StatelessWidget {
  const _TrustFeatureCard({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFEFB),
            Color(0xFFFFF6DE),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE1C56A)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12003E25),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE0C56D)),
            ),
            child: const Text(
              'KAZI standard',
              style: TextStyle(
                color: KaziTheme.primaryGreen,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4CB),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE0C56D)),
            ),
            child: Icon(icon, size: 32, color: KaziTheme.primaryGreen),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF173325),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF5A685E), height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({required this.quote, required this.customerName});

  final String quote;
  final String customerName;

  @override
  Widget build(BuildContext context) {
    final trimmedName = customerName.trim();
    final customerInitial = trimmedName.isNotEmpty ? trimmedName[0].toUpperCase() : 'K';

    return _SurfaceCard(
      backgroundColor: const Color(0xFFFFFCF6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: List.generate(
                    5,
                    (_) => const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.star_rounded, size: 18, color: KaziTheme.accentGold),
                    ),
                  ),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: KaziTheme.softGold,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.format_quote_rounded, color: KaziTheme.primaryGreen),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            quote,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF4F5B53),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F0EA),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  customerInitial,
                  style: const TextStyle(
                    color: KaziTheme.primaryGreen,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF173325),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Verified KAZI customer',
                      style: TextStyle(
                        color: Color(0xFF5D6A62),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3ED),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Loved for punctual arrivals and polished finishes',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: KaziTheme.primaryGreen,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferingCarousel extends StatefulWidget {
  const _OfferingCarousel({required this.offerings, required this.onBook});

  final List<_ServiceData> offerings;
  final ValueChanged<_ServiceData> onBook;

  @override
  State<_OfferingCarousel> createState() => _OfferingCarouselState();
}

class _OfferingCarouselState extends State<_OfferingCarousel> {
  late final PageController _pageController;
  late final bool _autoRotate;
  Timer? _rotationTimer;
  var _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1);
    _autoRotate = _shouldAnimate();

    if (_autoRotate && widget.offerings.length > 1) {
      _rotationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_pageController.hasClients) return;
        final nextPage = (_currentPage + 1) % widget.offerings.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (!_pageController.hasClients) {
      setState(() => _currentPage = page);
      return;
    }

    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _goToPrevious() {
    final previousPage = (_currentPage - 1 + widget.offerings.length) % widget.offerings.length;
    _goToPage(previousPage);
  }

  void _goToNext() {
    final nextPage = (_currentPage + 1) % widget.offerings.length;
    _goToPage(nextPage);
  }

  bool _shouldAnimate() {
    var animate = true;
    assert(() {
      animate = false;
      return true;
    }());
    return animate;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final narrowPhone = constraints.maxWidth < 430;
        final carouselHeight = compact
            ? (narrowPhone ? 468.0 : 446.0)
            : 430.0;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFFCF3),
                Color(0xFFF3F8F4),
              ],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: const Color(0xFFDCC46E)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14003E25),
                blurRadius: 22,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                height: carouselHeight,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.offerings.length,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    final offering = widget.offerings[index];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF0C4A2C),
                              Color(0xFF1B6B45),
                            ],
                          ),
                        ),
                        child: compact
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _OfferingCarouselVisual(offering: offering)),
                                  _OfferingCarouselContent(offering: offering, onBook: () => widget.onBook(offering)),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    flex: 11,
                                    child: _OfferingCarouselContent(
                                      offering: offering,
                                      onBook: () => widget.onBook(offering),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 10,
                                    child: _OfferingCarouselVisual(offering: offering),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                runAlignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  _CarouselNavButton(
                    icon: Icons.west_rounded,
                    label: 'Previous',
                    onPressed: widget.offerings.length > 1 ? _goToPrevious : null,
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 170, maxWidth: 260),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(
                            widget.offerings.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: _currentPage == index ? 30 : 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _currentPage == index ? KaziTheme.primaryGreen : const Color(0xFFD6CBA4),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Offering ${_currentPage + 1} of ${widget.offerings.length}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF4F5B53),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CarouselNavButton(
                    icon: Icons.east_rounded,
                    label: 'Next',
                    onPressed: widget.offerings.length > 1 ? _goToNext : null,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OfferingCarouselContent extends StatelessWidget {
  const _OfferingCarouselContent({required this.offering, required this.onBook});

  final _ServiceData offering;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;

        return Padding(
          padding: EdgeInsets.fromLTRB(compact ? 18 : 22, 22, compact ? 18 : 22, compact ? 18 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0x26FFF1C9),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0x88FFD56F)),
                      ),
                      child: Text(
                        offering.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(offering.icon, color: KaziTheme.primaryGreen, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Now rotating through KAZI favourites',
                style: TextStyle(
                  color: Color(0xFFFFD56F),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                offering.title,
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                offering.subtitle,
                maxLines: compact ? 3 : 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFE4EFE8),
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _OfferingStatPill(label: offering.priceFrom),
                  _OfferingStatPill(label: offering.eta),
                  const _OfferingStatPill(label: 'Professional finish'),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: compact ? double.infinity : null,
                child: FilledButton(
                  onPressed: onBook,
                  style: FilledButton.styleFrom(
                    backgroundColor: KaziTheme.accentGold,
                    foregroundColor: const Color(0xFF153527),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  child: const Text('Book this offering'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OfferingCarouselVisual extends StatelessWidget {
  const _OfferingCarouselVisual({required this.offering});

  final _ServiceData offering;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFF2EEE6),
                        Color(0xFFDCCFB8),
                      ],
                    ),
                  ),
                ),
                Image.asset(
                  offering.imageAsset,
                  fit: offering.imageFit,
                  alignment: offering.imageAlignment,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 30,
          top: 28,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6D9),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE0C56D)),
            ),
            child: const Text(
              'Featured offering',
              style: TextStyle(
                color: KaziTheme.primaryGreen,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CarouselNavButton extends StatelessWidget {
  const _CarouselNavButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: onPressed == null ? const Color(0xFFE8E4D8) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: onPressed == null ? const Color(0xFFD9D4C5) : const Color(0xFFE1C56A),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: KaziTheme.primaryGreen, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: KaziTheme.primaryGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferingStatPill extends StatelessWidget {
  const _OfferingStatPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PromisePanel extends StatelessWidget {
  const _PromisePanel({required this.onPrimaryPressed, this.onSecondaryPressed});

  final VoidCallback onPrimaryPressed;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0E2F21),
        borderRadius: BorderRadius.circular(32),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 820;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x1FFFFFFF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'The KAZI Promise',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Excellence in every home, booking, and provider arrival.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              const Text(
                'KAZI is designed to keep the experience premium and easy: book faster, view provider details, track arrivals, manage payments, and return for your next service without friction.',
                style: TextStyle(color: Color(0xFFD4E3DA), height: 1.65),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: onPrimaryPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: KaziTheme.accentGold,
                      foregroundColor: const Color(0xFF153527),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    child: const Text('Book your next service'),
                  ),
                  if (onSecondaryPressed != null)
                    OutlinedButton(
                      onPressed: onSecondaryPressed,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x80FFCC57)),
                        backgroundColor: const Color(0x14000000),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const Text('Create account'),
                    ),
                ],
              ),
            ],
          );

          final visual = Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What you manage in one place',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 12),
                _PromiseBullet(text: 'Bookings, schedules, and provider ETA'),
                SizedBox(height: 10),
                _PromiseBullet(text: 'Payments, promo codes, and wallet activity'),
                SizedBox(height: 10),
                _PromiseBullet(text: 'Ratings, reviews, and rebooking'),
              ],
            ),
          );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: 18), visual],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: copy),
              const SizedBox(width: 18),
              Expanded(flex: 4, child: visual),
            ],
          );
        },
      ),
    );
  }
}

class _PromiseBullet extends StatelessWidget {
  const _PromiseBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 5),
          decoration: const BoxDecoration(
            color: KaziTheme.accentGold,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFFD6E4DB), height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _BookingsPage extends StatefulWidget {
  const _BookingsPage();

  @override
  State<_BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<_BookingsPage> {
  String _filter = 'All';
  Timer? _trackingPoller;

  Future<void> _cancelBookingFlow(
    _BookingData booking,
  ) async {
    final controller = _AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final reason = await _showReasonSheet(
      context,
      title: controller.isProvider ? 'Cancel this booking?' : 'Why are you cancelling?',
      subtitle: controller.isProvider
          ? 'Choose the reason that best matches why this active job should be released.'
          : 'Choose a rideshare-style reason so the cancellation is clear in the trip record.',
      confirmLabel: controller.isProvider ? 'Cancel booking' : 'Cancel trip',
      options: controller.isProvider ? _providerCancellationReasons : _customerCancellationReasons,
    );

    if (!mounted || reason == null) {
      return;
    }

    try {
      await controller.cancelBooking(booking, reason: reason);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            controller.isProvider
                ? 'Booking cancelled and removed from the provider queue.'
                : 'Booking cancelled successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openChatSheet(_BookingData booking) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BookingChatSheet(booking: booking),
    );
  }

  Future<void> _startCall(_BookingData booking) async {
    final controller = _AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final call = await controller.startBookingCall(booking.id);
      if (call.callMode == 'twilio_bridge') {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(call.statusMessage)));
        await controller.refreshAuthenticatedData();
        return;
      }

      final launched = await launchUrl(Uri.parse('tel:${call.participantPhone}'));
      if (!launched) {
        throw const KaziApiException('Could not open the phone dialer on this device.');
      }
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  void initState() {
    super.initState();
    _trackingPoller = Timer.periodic(const Duration(seconds: 12), (_) => _refreshTrackingSnapshot());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshTrackingSnapshot());
  }

  @override
  void dispose() {
    _trackingPoller?.cancel();
    super.dispose();
  }

  Future<void> _refreshTrackingSnapshot() async {
    if (!mounted) return;
    final controller = _AppScope.of(context);
    if (!controller.isAuthenticated || controller.isRefreshing) return;
    final hasTrackableBookings = controller.bookings.any((booking) => booking.supportsLiveTracking);
    if (!hasTrackableBookings) return;
    try {
      if (controller.isProvider) {
        await controller.syncProviderTrackingForActiveBookings();
      } else {
        await controller.refreshAuthenticatedData();
      }
    } catch (_) {
      // Keep the polling loop lightweight; explicit actions surface errors.
    }
  }

  Future<void> _openReviewSheet(_BookingData booking) async {
    final controller = _AppScope.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final commentController = TextEditingController();
    var rating = 5;
    var submitting = false;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.isProvider
                          ? 'Rate the customer for ${booking.serviceTitle}'
                          : 'Rate the provider for ${booking.serviceTitle}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      controller.isProvider
                          ? 'How was the customer experience on this trip?'
                          : 'How was your provider experience?',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(
                        5,
                        (index) {
                          final value = index + 1;
                          return ChoiceChip(
                            label: Text('$value star${value == 1 ? '' : 's'}'),
                            selected: rating == value,
                            onSelected: (_) => setModalState(() => rating = value),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: controller.isProvider ? 'Customer feedback note' : 'Provider feedback note',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: submitting
                          ? null
                          : () async {
                              setModalState(() {
                                submitting = true;
                                error = null;
                              });

                              try {
                                await controller.submitReview(
                                  booking: booking,
                                  rating: rating,
                                  comment: commentController.text.trim(),
                                );
                                if (!mounted) return;
                                navigator.pop();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      controller.isProvider
                                          ? 'Customer rating submitted successfully.'
                                          : 'Provider rating submitted successfully.',
                                    ),
                                  ),
                                );
                              } catch (err) {
                                setModalState(() => error = err.toString());
                              } finally {
                                if (mounted) {
                                  setModalState(() => submitting = false);
                                }
                              }
                            },
                      child: Text(submitting ? 'Submitting...' : 'Submit review'),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!, style: const TextStyle(color: Colors.redAccent)),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (!controller.isAuthenticated) {
      return const _AuthRequiredCard(
        title: 'Sign in to view bookings',
        body: 'Customer and provider booking history now comes from the Nest API, so this screen needs a real session.',
        role: 'customer',
      );
    }

    final liveBookings = controller.bookings;
    final filteredBookings = liveBookings.where((booking) {
      if (_filter == 'All') {
        return true;
      }
      return booking.status.label == _filter;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: KaziTheme.softGold,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    controller.isProvider ? 'Provider trip controls' : 'Customer trip controls',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: KaziTheme.primaryGreen),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  controller.isProvider
                      ? 'Accept, route, arrive, start, complete, or cancel from one trip-style view.'
                      : 'Track the provider, message them, pay, or cancel from one cleaner booking flow.',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.05),
                ),
                const SizedBox(height: 12),
                Text(
                  controller.isProvider
                      ? 'This now behaves more like an Uber driver queue, with clear action states instead of a flat booking list.'
                      : 'This now behaves more like a rider trip screen, with live status, tracking, and customer-side control actions.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ResponsiveGrid(
            minTileWidth: 180,
            maxColumns: 4,
            children: [
              _MetricCard(label: 'All', value: '${liveBookings.length}', detail: 'Visible bookings'),
              _MetricCard(
                label: 'Active',
                value: '${liveBookings.where((item) => item.status == _BookingStatus.matched || item.status == _BookingStatus.enRoute).length}',
                detail: 'Providers travelling',
              ),
              _MetricCard(
                label: 'Scheduled',
                value: '${liveBookings.where((item) => item.status == _BookingStatus.scheduled).length}',
                detail: 'Upcoming jobs',
              ),
              _MetricCard(
                label: 'Completed',
                value: '${liveBookings.where((item) => item.status == _BookingStatus.completed).length}',
                detail: 'Closed this cycle',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['All', ..._BookingStatus.values.map((status) => status.label)]
                .map(
                  (label) => ChoiceChip(
                    label: Text(label),
                    selected: _filter == label,
                    onSelected: (_) => setState(() => _filter = label),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          if (filteredBookings.isEmpty)
            const _SurfaceCard(
              child: Text('No live bookings found for this account yet.'),
            )
          else
            Column(
              children: filteredBookings
                  .map(
                    (booking) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _BookingWorkflowCard(
                        booking: booking,
                        onAdvance: controller.isProvider &&
                                booking.status != _BookingStatus.completed &&
                                booking.status != _BookingStatus.cancelled
                            ? () async {
                                try {
                                  await controller.advanceBooking(booking);
                                } catch (error) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(error.toString())),
                                  );
                                }
                              }
                            : null,
                        onReview: booking.status == _BookingStatus.completed &&
                                booking.needsReviewForRole(controller.isProvider)
                            ? () async {
                                await _openReviewSheet(booking);
                              }
                            : null,
                        onPayNow: controller.isCustomer && booking.canPayOnline
                            ? () async {
                                try {
                                  await controller.openHostedPayment(booking);
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('Secure checkout opened in your browser.')),
                                  );
                                } catch (error) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(error.toString())),
                                  );
                                }
                              }
                            : null,
                        onMessage: () async {
                          await _openChatSheet(booking);
                        },
                        onCall: () async {
                          await _startCall(booking);
                        },
                        onTrack: controller.isProvider && booking.supportsLiveTracking
                            ? () async {
                                try {
                                  await controller.updateLiveLocation(booking);
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('Live provider location updated.')),
                                  );
                                } catch (error) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(error.toString())),
                                  );
                                }
                              }
                            : controller.isCustomer && booking.hasLiveTracking
                                ? () async {
                                    try {
                                      await controller.openTrackingMap(booking);
                                    } catch (error) {
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        SnackBar(content: Text(error.toString())),
                                      );
                                    }
                                  }
                                : null,
                        onCancel: booking.status != _BookingStatus.completed && booking.status != _BookingStatus.cancelled
                            ? () async {
                                await _cancelBookingFlow(booking);
                              }
                            : null,
                        trackActionLabel: controller.isProvider
                            ? 'Update live location'
                            : booking.hasLiveTracking
                                ? 'Track provider'
                                : null,
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _ProviderHubPage extends StatefulWidget {
  const _ProviderHubPage();

  @override
  State<_ProviderHubPage> createState() => _ProviderHubPageState();
}

class _ProviderHubPageState extends State<_ProviderHubPage> {
  String _selectedDocumentType = 'national_id';
  bool _uploadingDocument = false;

  Future<void> _cancelAcceptedJob(_ProviderJobData job) async {
    final controller = _AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final booking = controller.bookings.cast<_BookingData?>().firstWhere(
          (item) => item?.id == job.id,
          orElse: () => null,
        );

    if (booking == null) {
      messenger.showSnackBar(const SnackBar(content: Text('This booking is no longer available.')));
      return;
    }

    final reason = await _showReasonSheet(
      context,
      title: 'Cancel accepted job?',
      subtitle: 'Choose the reason that best explains why this assigned job should be released.',
      confirmLabel: 'Cancel job',
      options: _providerCancellationReasons,
    );

    if (!mounted || reason == null) {
      return;
    }

    try {
      await controller.cancelBooking(
        booking,
        reason: reason,
      );
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Job cancelled and released from your queue.')));
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Color _documentStatusColor(String status) {
    return switch (status) {
      'approved' => KaziTheme.primaryGreen,
      'rejected' => const Color(0xFFB42318),
      _ => KaziTheme.accentGold,
    };
  }

  @override
  Widget build(BuildContext context) {
    final controller = _AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (!controller.isProvider) {
      return const _AuthRequiredCard(
        title: 'Sign in as a provider',
        body: 'Provider availability, onboarding, and open jobs are now tied to the real backend provider role.',
        role: 'provider',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AdaptiveSplit(
            primary: _SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: KaziTheme.softGold,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Provider launch desk',
                      style: TextStyle(fontWeight: FontWeight.w700, color: KaziTheme.primaryGreen),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Provider hub with a calmer daily workflow', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.05)),
                  const SizedBox(height: 12),
                  const Text(
                    'Keep onboarding, document uploads, availability, and incoming jobs in one cleaner workspace that matches the new storefront feel.',
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _HeroMetaPill(label: '${controller.incomingJobs.length} incoming jobs'),
                      _HeroMetaPill(label: '${controller.acceptedJobs.length} accepted today'),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (controller.providerProfileMissing)
                    FilledButton.tonal(
                      onPressed: () async {
                        try {
                          await controller.completeProviderOnboarding();
                        } catch (error) {
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      },
                      child: const Text('Initialize provider onboarding'),
                    )
                  else ...[
                    DropdownButtonFormField<String>(
                      key: ValueKey(_selectedDocumentType),
                      initialValue: _selectedDocumentType,
                      items: const [
                        DropdownMenuItem(value: 'national_id', child: Text('National ID')),
                        DropdownMenuItem(value: 'proof_of_address', child: Text('Proof of address')),
                        DropdownMenuItem(value: 'drivers_license', child: Text('Driver\'s license')),
                        DropdownMenuItem(value: 'trade_certificate', child: Text('Trade certificate')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedDocumentType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _uploadingDocument
                          ? null
                          : () async {
                              final picked = await FilePicker.platform.pickFiles(
                                withData: true,
                                type: FileType.custom,
                                allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
                              );
                              final file = picked?.files.single;
                              if (file == null) {
                                return;
                              }

                              setState(() {
                                _uploadingDocument = true;
                              });

                              try {
                                final result = await controller.uploadProviderDocument(
                                  documentType: _selectedDocumentType,
                                  file: file,
                                );
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(content: Text('${result.uploaded.fileName} uploaded for review.')),
                                );
                              } catch (error) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(content: Text(error.toString())),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _uploadingDocument = false;
                                  });
                                }
                              }
                            },
                      icon: _uploadingDocument
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_outlined),
                      label: Text(_uploadingDocument ? 'Uploading document...' : 'Upload verification document'),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: KaziTheme.surface,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Available now'),
                        subtitle: Text(
                          controller.providerProfileMissing
                              ? 'Create a provider profile first'
                              : controller.providerAvailable
                                  ? 'Instant jobs enabled'
                                  : 'Paused for new assignments',
                        ),
                        value: controller.providerAvailable,
                        onChanged: controller.providerProfileMissing
                            ? null
                            : (value) async {
                                try {
                                  await controller.setProviderAvailability(value);
                                } catch (error) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(error.toString())),
                                  );
                                }
                              },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            secondary: _SurfaceCard(
              backgroundColor: KaziTheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Daily status',
                      style: TextStyle(fontWeight: FontWeight.w700, color: KaziTheme.primaryGreen),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Provider status', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  _InlineStatus(
                    label: 'Verification',
                    value: controller.providerProfileMissing
                        ? 'Profile missing'
                        : controller.providerVerificationStatus.replaceAll('_', ' '),
                  ),
                  const SizedBox(height: 10),
                  _InlineStatus(label: 'Available', value: controller.providerAvailable ? 'Yes' : 'No'),
                  const SizedBox(height: 10),
                  _InlineStatus(label: 'Documents', value: '${controller.providerDocuments.length}'),
                  const SizedBox(height: 10),
                  _InlineStatus(label: 'Accepted today', value: '${controller.acceptedJobs.length}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeading(
            title: 'Verification uploads',
            subtitle: 'Track the files you have sent for provider review directly from the provider hub.',
          ),
          const SizedBox(height: 12),
          if (controller.providerProfileMissing)
            const _SurfaceCard(
              child: Text('Create a provider profile before uploading verification documents.'),
            )
          else if (controller.providerDocuments.isEmpty)
            const _SurfaceCard(
              child: Text('No verification documents uploaded yet. Upload at least one document to start admin review.'),
            )
          else
            Column(
              children: controller.providerDocuments
                  .map(
                    (document) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SurfaceCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.description_outlined, color: KaziTheme.primaryGreen),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    document.documentType.replaceAll('_', ' ').toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(document.fileName, style: const TextStyle(height: 1.4)),
                                ],
                              ),
                            ),
                            _StatusPill(
                              label: document.status.replaceAll('_', ' '),
                              color: _documentStatusColor(document.status),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 24),
          const _SectionHeading(
            title: 'Incoming jobs',
            subtitle: 'Accept work from a cleaner card layout that keeps timing, pay, and distance easy to scan.',
          ),
          const SizedBox(height: 12),
          _ResponsiveGrid(
            minTileWidth: 240,
            maxColumns: 3,
            children: controller.incomingJobs
                .map(
                  (job) => _IncomingJobCard(
                    data: job,
                    onAccept: controller.providerAvailable
                        ? () async {
                            try {
                              await controller.acceptJob(job);
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(content: Text('${job.title} accepted and added to today\'s queue.')),
                              );
                            } catch (error) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          }
                        : null,
                    onDecline: () async {
                      final reason = await _showReasonSheet(
                        context,
                        title: 'Decline this job?',
                        subtitle: 'Choose the reason that best fits why you are skipping this incoming dispatch.',
                        confirmLabel: 'Decline job',
                        options: _providerDeclineReasons,
                      );
                      if (!mounted || reason == null) {
                        return;
                      }
                      try {
                        await controller.declineJob(job, reason: reason);
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text('${job.title} declined. We will keep other jobs moving.')),
                        );
                      } catch (error) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          const _SectionHeading(
            title: 'Today\'s accepted jobs',
            subtitle: 'Accepted work stays in a lighter queue view built around the same visual language as the customer home.',
          ),
          const SizedBox(height: 12),
          if (controller.acceptedJobs.isEmpty)
            const _SurfaceCard(
              child: Text('No jobs accepted yet. Turn availability on and accept an incoming job.'),
            )
          else
            Column(
              children: controller.acceptedJobs
                  .map(
                    (job) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                        child: _AcceptedJobTile(
                          job: job,
                          onCancel: () async {
                            await _cancelAcceptedJob(job);
                          },
                        ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _WalletPage extends StatefulWidget {
  const _WalletPage();

  @override
  State<_WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<_WalletPage> {
  String _ledgerView = 'Customer';
  final TextEditingController _referralCodeController = TextEditingController();
  bool _redeemingReferral = false;

  @override
  void dispose() {
    _referralCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _AppScope.of(context);

    if (!controller.isAuthenticated) {
      return const _AuthRequiredCard(
        title: 'Sign in to view wallet data',
        body: 'Wallet balance now comes from the real user profile, and the history is derived from live bookings until a dedicated wallet API is added.',
        role: 'customer',
      );
    }

    final history = controller.walletHistory;
    final referralSummary = controller.referralSummary;
    final activePromos = controller.activePromos;
    final credits = history.where((entry) => entry.isCredit).length;
    final debits = history.length - credits;
    final balanceValue = _ledgerView == 'Customer'
        ? _formatCurrencyFromCents(controller.currentUser?.walletBalanceCents ?? 0)
        : history.where((entry) => entry.isCredit).isEmpty
            ? 'R0'
            : history.where((entry) => entry.isCredit).first.amount.replaceFirst('+', '');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AdaptiveSplit(
            primary: _SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: KaziTheme.softGold,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Wallet and rewards',
                      style: TextStyle(fontWeight: FontWeight.w700, color: KaziTheme.primaryGreen),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('A cleaner earnings and credits view', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.05)),
                  const SizedBox(height: 12),
                  Text(
                    _ledgerView == 'Customer'
                        ? 'Check available credits, promo rewards, and transaction history without the old dashboard clutter.'
                        : 'Switch to the provider view to scan earnings and payout context with the same lighter visual rhythm.',
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Customer', 'Provider']
                        .map(
                          (view) => ChoiceChip(
                            label: Text(view),
                            selected: _ledgerView == view,
                            onSelected: (_) => setState(() => _ledgerView = view),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeroMetaPill(label: '$credits credit items'),
                      _HeroMetaPill(label: '$debits debit items'),
                      _HeroMetaPill(label: activePromos.isEmpty ? 'No active promos' : '${activePromos.length} active promos'),
                    ],
                  ),
                ],
              ),
            ),
            secondary: _SurfaceCard(
              backgroundColor: KaziTheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Balance snapshot',
                      style: TextStyle(fontWeight: FontWeight.w700, color: KaziTheme.primaryGreen),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InlineStatus(label: 'Current view', value: _ledgerView),
                  const SizedBox(height: 10),
                  _InlineStatus(label: 'Available balance', value: balanceValue),
                  const SizedBox(height: 10),
                  _InlineStatus(label: 'Referral code', value: referralSummary?.referralCode ?? 'Unavailable'),
                  const SizedBox(height: 10),
                  _InlineStatus(label: 'Reward pool', value: activePromos.isEmpty ? 'No promos' : '${activePromos.length} offers'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ResponsiveGrid(
            minTileWidth: 220,
            maxColumns: 3,
            children: [
              _WalletStatCard(
                title: _ledgerView == 'Customer' ? 'Available credits' : 'Available balance',
                value: balanceValue,
                detail: _ledgerView == 'Customer' ? 'Wallet balance from profile' : 'Derived from completed bookings',
              ),
              _WalletStatCard(
                title: 'Credits',
                value: '$credits',
                detail: 'Positive ledger items',
              ),
              _WalletStatCard(
                title: 'Debits',
                value: '$debits',
                detail: 'Outgoing charges or transfers',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _AdaptiveSplit(
            primary: _SurfaceCard(
              backgroundColor: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Transaction history', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  ...history.map((entry) => _WalletHistoryTile(entry: entry)),
                ],
              ),
            ),
            secondary: _SurfaceCard(
              backgroundColor: KaziTheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payout and promo rules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  const _InlineStatus(label: 'Next payout', value: 'Friday, 16:00'),
                  const SizedBox(height: 10),
                  _InlineStatus(
                    label: 'Promo pool',
                    value: activePromos.isEmpty ? 'No active promos' : '${activePromos.length} active offers',
                  ),
                  const SizedBox(height: 10),
                  _InlineStatus(label: 'Current view', value: _ledgerView),
                  if (referralSummary != null) ...[
                    const SizedBox(height: 18),
                    _InlineStatus(label: 'Your referral code', value: referralSummary.referralCode ?? 'Unavailable'),
                    const SizedBox(height: 10),
                    _InlineStatus(
                      label: 'Referral rewards',
                      value: _formatCurrencyFromCents(referralSummary.referralEarningsCents),
                    ),
                    const SizedBox(height: 10),
                    _InlineStatus(
                      label: 'Reward per signup',
                      value: _formatCurrencyFromCents(referralSummary.rewardPerReferralCents),
                    ),
                    const SizedBox(height: 10),
                    _InlineStatus(label: 'Successful invites', value: '${referralSummary.referralsCount}'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _referralCodeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Redeem referral code',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _redeemingReferral || referralSummary.referredByCode != null
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _redeemingReferral = true);
                              try {
                                await controller.redeemReferralCode(_referralCodeController.text);
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Referral reward applied successfully.')),
                                );
                              } catch (error) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(content: Text(error.toString())),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _redeemingReferral = false);
                                }
                              }
                            },
                      child: Text(
                        referralSummary.referredByCode != null
                            ? 'Referral already redeemed'
                            : (_redeemingReferral ? 'Applying...' : 'Redeem referral code'),
                      ),
                    ),
                  ],
                  if (activePromos.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text('Active promos', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    ...activePromos.take(3).map(
                      (promo) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('${promo.code} • ${promo.title}'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetaPill extends StatelessWidget {
  const _HeroMetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF8E7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFE2D5AB),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: KaziTheme.primaryGreen,
        ),
      ),
    );
  }
}

class _AuthRequiredCard extends StatelessWidget {
  const _AuthRequiredCard({
    required this.title,
    required this.body,
    required this.role,
  });

  final String title;
  final String body;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _SurfaceCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(body, style: const TextStyle(height: 1.5)),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => _showAuthSheet(context, initialRole: role),
                  child: Text(role == 'provider' ? 'Sign in as provider' : 'Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet();

  @override
  Widget build(BuildContext context) {
    final controller = _AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final notifications = controller.notifications;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifications',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text('${controller.unreadNotifications} unread updates'),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: controller.unreadNotifications == 0
                        ? null
                        : () async {
                            try {
                              await controller.markAllNotificationsRead();
                            } catch (error) {
                              messenger.showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          },
                    child: const Text('Mark all read'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: notifications.isEmpty
                    ? const _SurfaceCard(
                        child: Text(
                          'Booking updates, provider movement, chat alerts, and payment confirmations will appear here.',
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = notifications[index];
                          return _SurfaceCard(
                            child: InkWell(
                              onTap: item.isRead
                                  ? null
                                  : () async {
                                      try {
                                        await controller.markNotificationRead(item.id);
                                      } catch (error) {
                                        messenger.showSnackBar(
                                          SnackBar(content: Text(error.toString())),
                                        );
                                      }
                                    },
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: item.isRead
                                          ? KaziTheme.surface
                                          : const Color(0xFFE6F4EC),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      _iconForNotification(item.type),
                                      color: item.isRead
                                          ? const Color(0xFF5A675F)
                                          : KaziTheme.primaryGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.title,
                                                style: TextStyle(
                                                  fontWeight: item.isRead
                                                      ? FontWeight.w600
                                                      : FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _formatTimestamp(item.createdAt),
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(item.body, style: const TextStyle(height: 1.4)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForNotification(String type) {
    final normalized = type.toLowerCase();
    if (normalized.contains('chat') || normalized.contains('message')) {
      return Icons.chat_bubble_outline;
    }
    if (normalized.contains('payment') || normalized.contains('wallet')) {
      return Icons.account_balance_wallet_outlined;
    }
    if (normalized.contains('promo') || normalized.contains('offer')) {
      return Icons.local_offer_outlined;
    }
    if (normalized.contains('booking') || normalized.contains('provider')) {
      return Icons.event_available_outlined;
    }
    return Icons.notifications_outlined;
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) {
      return 'Just now';
    }

    final difference = DateTime.now().difference(timestamp);
    if (difference.inMinutes < 1) {
      return 'Now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours}h';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays}d';
    }

    final month = timestamp.month.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    return '$day/$month';
  }
}

class _ServiceFlowCard extends StatelessWidget {
  const _ServiceFlowCard({
    required this.data,
    required this.onBook,
    required this.onSchedule,
  });

  final _ServiceData data;
  final VoidCallback onBook;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      backgroundColor: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          final buttonStyle = compact
              ? ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: WidgetStatePropertyAll(Size(double.infinity, compact ? 34 : 40)),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                )
              : null;
          final imageHeight = compact ? 96.0 : (constraints.maxWidth < 320 ? 142.0 : 156.0);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: imageHeight,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFF4F1EB),
                              Color(0xFFE5DDD1),
                            ],
                          ),
                        ),
                      ),
                      Image.asset(
                        data.imageAsset,
                        fit: data.imageFit,
                        alignment: data.imageAlignment,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.05),
                              Colors.black.withValues(alpha: 0.42),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: compact ? 34 : 44,
                                  height: compact ? 34 : 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(data.icon, color: KaziTheme.primaryGreen, size: compact ? 18 : 22),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: compact ? 10 : 12,
                                        vertical: compact ? 5 : 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF1C9).withValues(alpha: 0.96),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        data.category,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: KaziTheme.primaryGreen,
                                          fontWeight: FontWeight.w800,
                                          fontSize: compact ? 11 : 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              data.title,
                              maxLines: compact ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 16 : 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.05,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: compact ? 10 : 14),
              Text(
                data.subtitle,
                maxLines: compact ? 2 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF536158),
                  height: 1.4,
                  fontSize: compact ? 12.5 : 14,
                ),
              ),
              SizedBox(height: compact ? 8 : 14),
              if (compact)
                Text(
                  '${data.priceFrom} • ${data.eta}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A231D),
                    fontSize: 12.5,
                  ),
                )
              else ...[
                _InlineStatus(label: 'Price', value: data.priceFrom),
                const SizedBox(height: 8),
                _InlineStatus(label: 'Dispatch', value: data.eta),
              ],
              SizedBox(height: compact ? 10 : 14),
              if (compact)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: onBook,
                        style: buttonStyle,
                        child: const Text('Book'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onSchedule,
                        style: buttonStyle,
                        child: const Text('Later'),
                      ),
                    ),
                  ],
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: onBook,
                      style: buttonStyle,
                      child: const Text('Book now'),
                    ),
                    OutlinedButton(
                      onPressed: onSchedule,
                      style: buttonStyle,
                      child: const Text('Schedule'),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BookingWorkflowCard extends StatelessWidget {
  const _BookingWorkflowCard({
    required this.booking,
    required this.onAdvance,
    this.onReview,
    this.onPayNow,
    this.onMessage,
    this.onCall,
    this.onTrack,
    this.onCancel,
    this.trackActionLabel,
  });

  final _BookingData booking;
  final VoidCallback? onAdvance;
  final VoidCallback? onReview;
  final VoidCallback? onPayNow;
  final VoidCallback? onMessage;
  final VoidCallback? onCall;
  final VoidCallback? onTrack;
  final VoidCallback? onCancel;
  final String? trackActionLabel;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(booking.serviceTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              _StatusPill(label: booking.status.label, color: booking.status.color),
            ],
          ),
          const SizedBox(height: 12),
          _InlineStatus(label: 'Address', value: booking.address),
          const SizedBox(height: 10),
          _InlineStatus(label: 'Schedule', value: booking.schedule),
          const SizedBox(height: 10),
          _InlineStatus(label: 'Payment', value: booking.paymentMethodLabel),
          const SizedBox(height: 10),
          _InlineStatus(label: 'Payment status', value: booking.paymentStatusLabel),
          const SizedBox(height: 10),
          _InlineStatus(label: 'Amount', value: booking.amount),
          if (booking.hasMapPreview) ...[
            const SizedBox(height: 14),
            _BookingTrackingMapCard(booking: booking),
          ],
          if (booking.supportsLiveTracking) ...[
            const SizedBox(height: 10),
            _InlineStatus(
              label: 'Live tracking',
              value: booking.trackingSummary,
            ),
          ],
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: booking.status.progress,
            backgroundColor: KaziTheme.surface,
            color: booking.status.color,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onAdvance,
            child: Text(onAdvance == null ? 'Booking completed' : booking.status.nextActionLabel),
          ),
          if (onReview != null || onPayNow != null || onMessage != null || onCall != null || onTrack != null || onCancel != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (onPayNow != null)
                  OutlinedButton(
                    onPressed: onPayNow,
                    child: const Text('Pay now'),
                  ),
                if (onMessage != null)
                  OutlinedButton(
                    onPressed: onMessage,
                    child: const Text('Message'),
                  ),
                if (onCall != null)
                  OutlinedButton(
                    onPressed: onCall,
                    child: const Text('Call'),
                  ),
                if (onTrack != null && trackActionLabel != null)
                  OutlinedButton(
                    onPressed: onTrack,
                    child: Text(trackActionLabel!),
                  ),
                if (onCancel != null)
                  OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Cancel booking'),
                  ),
                if (onReview != null)
                  OutlinedButton(
                    onPressed: onReview,
                    child: const Text('Leave review'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BookingChatSheet extends StatefulWidget {
  const _BookingChatSheet({required this.booking});

  final _BookingData booking;

  @override
  State<_BookingChatSheet> createState() => _BookingChatSheetState();
}

class _BookingChatSheetState extends State<_BookingChatSheet> {
  final TextEditingController _messageController = TextEditingController();
  ApiChatThread? _thread;
  ApiBookingCall? _lastCall;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadThread();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadThread() async {
    final controller = _AppScope.of(context);
    try {
      final thread = await controller.getBookingThread(widget.booking.id);
      if (!mounted) return;
      setState(() {
        _thread = thread;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  String _formatMessageTime(DateTime? value) {
    if (value == null) return 'Now';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _send() async {
    final controller = _AppScope.of(context);
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() => _sending = true);
    try {
      final message = await controller.sendBookingMessage(
        bookingId: widget.booking.id,
        message: text,
      );
      if (!mounted) return;
      setState(() {
        _thread = ApiChatThread(
          bookingId: _thread!.bookingId,
          bookingRef: _thread!.bookingRef,
          participant: _thread!.participant,
          messages: [..._thread!.messages, message],
        );
        _messageController.clear();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _callParticipant() async {
    final controller = _AppScope.of(context);
    try {
      final call = await controller.startBookingCall(widget.booking.id);
      if (!mounted) return;
      setState(() => _lastCall = call);

      if (call.callMode == 'twilio_bridge') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(call.statusMessage)));
        await _loadThread();
        return;
      }

      final launched = await launchUrl(Uri.parse('tel:${call.participantPhone}'));
      if (!launched) {
        throw const KaziApiException('Could not open the phone dialer on this device.');
      }
      await _loadThread();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: _loading
            ? const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()))
            : _error != null
                ? _SurfaceCard(child: Text(_error!))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _thread!.participant.displayName,
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 4),
                                Text('Booking ${_thread!.bookingRef}'),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: _callParticipant,
                            child: const Text('Call'),
                          ),
                        ],
                      ),
                      if (_lastCall != null) ...[
                        const SizedBox(height: 12),
                        _SurfaceCard(
                          backgroundColor: _lastCall!.callMode == 'twilio_bridge'
                              ? const Color(0xFFEAF5EE)
                              : const Color(0xFFFFF4D6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _lastCall!.callMode == 'twilio_bridge' ? 'Call in progress' : 'Dialer fallback ready',
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  const Spacer(),
                                  Text(_formatMessageTime(_lastCall!.startedAt)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(_lastCall!.statusMessage),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  _InlineStatus(
                                    label: 'Route',
                                    value: _lastCall!.callProvider == 'twilio' ? 'Twilio bridge' : 'Device dialer',
                                  ),
                                  _InlineStatus(label: 'State', value: _lastCall!.callStatus.replaceAll('_', ' ')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Flexible(
                        child: _thread!.messages.isEmpty
                            ? const _SurfaceCard(
                                child: Text('Share arrival notes, gate instructions, or service updates for this booking.'),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: _thread!.messages.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final message = _thread!.messages[index];
                                  final isSystemCall = message.messageType == 'call_log';
                                  return _SurfaceCard(
                                    backgroundColor: isSystemCall ? const Color(0xFFFFF4D6) : KaziTheme.surface,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              isSystemCall ? 'Call activity' : 'Message',
                                              style: const TextStyle(fontWeight: FontWeight.w700),
                                            ),
                                            const Spacer(),
                                            Text(_formatMessageTime(message.createdAt)),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(message.message),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              minLines: 1,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Booking message',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: _sending ? null : _send,
                            child: Text(_sending ? 'Sending...' : 'Send'),
                          ),
                        ],
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _IncomingJobCard extends StatelessWidget {
  const _IncomingJobCard({required this.data, required this.onAccept, required this.onDecline});

  final _ProviderJobData data;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      backgroundColor: KaziTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.work_outline, color: KaziTheme.primaryGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(data.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(data.category, style: const TextStyle(color: KaziTheme.primaryGreen, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _InlineStatus(label: 'Timing', value: data.timing),
          const SizedBox(height: 10),
          _InlineStatus(label: 'Budget', value: data.pay),
          const SizedBox(height: 10),
          _InlineStatus(label: 'Distance', value: data.distance),
          const Spacer(),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(
                onPressed: onAccept,
                child: Text(onAccept == null ? 'Unavailable' : 'Accept job'),
              ),
              OutlinedButton(
                onPressed: onDecline,
                child: const Text('Decline'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AcceptedJobTile extends StatelessWidget {
  const _AcceptedJobTile({required this.job, this.onCancel});

  final _ProviderJobData job;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      backgroundColor: KaziTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.check_circle_outline, color: KaziTheme.primaryGreen, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(job.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InlineStatus(label: 'Time', value: job.timing),
          const SizedBox(height: 8),
          _InlineStatus(label: 'Pay', value: job.pay),
          const SizedBox(height: 8),
          _InlineStatus(label: 'Distance', value: job.distance),
          if (onCancel != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onCancel,
              child: const Text('Cancel job'),
            ),
          ],
        ],
      ),
    );
  }
}

class _WalletHistoryTile extends StatelessWidget {
  const _WalletHistoryTile({required this.entry});

  final _WalletEntryData entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KaziTheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: entry.isCredit ? const Color(0xFFE6F5EC) : const Color(0xFFFFECE8),
              child: Icon(
                entry.isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                color: entry.isCredit ? KaziTheme.primaryGreen : Colors.redAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(entry.subtitle, style: const TextStyle(color: Color(0xFF4F5B53))),
                ],
              ),
            ),
            Text(
              entry.amount,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: entry.isCredit ? KaziTheme.primaryGreen : Colors.redAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdaptiveSplit extends StatelessWidget {
  const _AdaptiveSplit({required this.primary, required this.secondary});

  final Widget primary;
  final Widget secondary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: primary),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: secondary),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            primary,
            const SizedBox(height: 16),
            secondary,
          ],
        );
      },
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({
    required this.minTileWidth,
    required this.maxColumns,
    required this.children,
  });

  final double minTileWidth;
  final int maxColumns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(
          1,
          math.min(maxColumns, ((constraints.maxWidth + 16) / (minTileWidth + 16)).floor()),
        );
        final tileWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - ((columns - 1) * 16)) / columns;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: children
              .map(
                (child) => SizedBox(
                  width: tileWidth,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: KaziTheme.accentGold,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'KAZI highlights',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: KaziTheme.primaryGreen,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.35,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0D4D2C),
              ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF41624F),
                height: 1.55,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 96,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              colors: [
                KaziTheme.accentGold,
                KaziTheme.primaryGreen,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, this.backgroundColor = Colors.white});

  final Widget child;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD9DED8)),
      ),
      child: child,
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.detail});

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      backgroundColor: KaziTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF4F5B53))),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(detail),
        ],
      ),
    );
  }
}

class _WalletStatCard extends StatelessWidget {
  const _WalletStatCard({required this.title, required this.value, required this.detail});

  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: KaziTheme.softGold,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(title, style: const TextStyle(color: KaziTheme.primaryGreen, fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(detail),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _InlineStatus extends StatelessWidget {
  const _InlineStatus({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF4F5B53)))),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _ShellDestination {
  const _ShellDestination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _ServiceData {
  const _ServiceData({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.priceFrom,
    required this.eta,
    required this.imageAsset,
    this.imageFit = BoxFit.cover,
    this.imageAlignment = Alignment.center,
    required this.icon,
  });

  final String id;
  final String category;
  final String title;
  final String subtitle;
  final String priceFrom;
  final String eta;
  final String imageAsset;
  final BoxFit imageFit;
  final Alignment imageAlignment;
  final IconData icon;
}

class _BookingData {
  const _BookingData({
    required this.id,
    required this.serviceTitle,
    required this.address,
    required this.schedule,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.amount,
    required this.customerLat,
    required this.customerLng,
    required this.providerCurrentLat,
    required this.providerCurrentLng,
    required this.providerLocationUpdatedAt,
    required this.isRated,
    required this.customerHasRated,
    required this.providerHasRated,
  });

  final String id;
  final String serviceTitle;
  final String address;
  final String schedule;
  final _BookingStatus status;
  final String paymentMethod;
  final String paymentStatus;
  final String amount;
  final double? customerLat;
  final double? customerLng;
  final double? providerCurrentLat;
  final double? providerCurrentLng;
  final DateTime? providerLocationUpdatedAt;
  final bool isRated;
  final bool customerHasRated;
  final bool providerHasRated;

  bool get canPayOnline =>
      (paymentMethod == 'CARD' || paymentMethod == 'EFT') && paymentStatus != 'PAID' && status != _BookingStatus.cancelled;

  bool get supportsLiveTracking =>
      status == _BookingStatus.matched || status == _BookingStatus.enRoute;

  bool get hasLiveTracking => providerCurrentLat != null && providerCurrentLng != null;

  bool get hasPinnedCustomerLocation => customerLat != null && customerLng != null;

  bool get hasMapPreview => hasPinnedCustomerLocation || hasLiveTracking;

  String get paymentMethodLabel => _formatPaymentMethodLabel(paymentMethod);

  String get paymentStatusLabel => _formatPaymentStatusLabel(paymentStatus);

  String get trackingSummary {
    if (!supportsLiveTracking) {
      return 'Tracking available after provider assignment';
    }
    if (!hasLiveTracking) {
      return 'Waiting for provider location update';
    }
    final updatedAt = providerLocationUpdatedAt;
    final freshness = updatedAt == null
        ? 'just now'
        : '${DateTime.now().difference(updatedAt).inMinutes.clamp(0, 120)} min ago';
    if (customerLat != null && customerLng != null) {
      final distanceMeters = Geolocator.distanceBetween(
        customerLat!,
        customerLng!,
        providerCurrentLat!,
        providerCurrentLng!,
      );
      final distanceLabel = _formatDistanceMeters(distanceMeters);
      return '$distanceLabel • updated $freshness';
    }
    return '${providerCurrentLat!.toStringAsFixed(5)}, ${providerCurrentLng!.toStringAsFixed(5)} • updated $freshness';
  }

  bool needsReviewForRole(bool isProvider) => isProvider ? !providerHasRated : !customerHasRated;

  _BookingData copyWith({
    _BookingStatus? status,
    bool? isRated,
    bool? customerHasRated,
    bool? providerHasRated,
  }) {
    return _BookingData(
      id: id,
      serviceTitle: serviceTitle,
      address: address,
      schedule: schedule,
      status: status ?? this.status,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      amount: amount,
      customerLat: customerLat,
      customerLng: customerLng,
      providerCurrentLat: providerCurrentLat,
      providerCurrentLng: providerCurrentLng,
      providerLocationUpdatedAt: providerLocationUpdatedAt,
      isRated: isRated ?? this.isRated,
      customerHasRated: customerHasRated ?? this.customerHasRated,
      providerHasRated: providerHasRated ?? this.providerHasRated,
    );
  }
}

class _BookingTrackingMapCard extends StatelessWidget {
  const _BookingTrackingMapCard({required this.booking});

  final _BookingData booking;

  @override
  Widget build(BuildContext context) {
    final points = <latlng.LatLng>[
      if (booking.hasPinnedCustomerLocation) latlng.LatLng(booking.customerLat!, booking.customerLng!),
      if (booking.hasLiveTracking) latlng.LatLng(booking.providerCurrentLat!, booking.providerCurrentLng!),
    ];

    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    final center = latlng.LatLng(
      points.map((point) => point.latitude).reduce((total, value) => total + value) / points.length,
      points.map((point) => point.longitude).reduce((total, value) => total + value) / points.length,
    );

    final distanceLabel = booking.hasPinnedCustomerLocation && booking.hasLiveTracking
        ? _formatDistanceMeters(
            Geolocator.distanceBetween(
              booking.customerLat!,
              booking.customerLng!,
              booking.providerCurrentLat!,
              booking.providerCurrentLng!,
            ),
          )
        : booking.hasPinnedCustomerLocation
            ? 'Customer pin confirmed'
            : 'Provider live position';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F3E8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD8CFBA)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route_outlined, size: 18, color: Color(0xFF1A231D)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  distanceLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A231D)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 180,
              child: FlutterMap(
                options: MapOptions(initialCenter: center, initialZoom: 13.2),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.kazi.mobile',
                  ),
                  if (booking.hasPinnedCustomerLocation && booking.hasLiveTracking)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [
                            latlng.LatLng(booking.providerCurrentLat!, booking.providerCurrentLng!),
                            latlng.LatLng(booking.customerLat!, booking.customerLng!),
                          ],
                          strokeWidth: 4,
                          color: const Color(0xFF22543D),
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (booking.hasPinnedCustomerLocation)
                        Marker(
                          point: latlng.LatLng(booking.customerLat!, booking.customerLng!),
                          width: 44,
                          height: 44,
                          child: const _TrackingMarker(
                            icon: Icons.home_work_outlined,
                            backgroundColor: Color(0xFFFAF1D7),
                            iconColor: Color(0xFF8A5A00),
                          ),
                        ),
                      if (booking.hasLiveTracking)
                        Marker(
                          point: latlng.LatLng(booking.providerCurrentLat!, booking.providerCurrentLng!),
                          width: 44,
                          height: 44,
                          child: const _TrackingMarker(
                            icon: Icons.local_shipping_outlined,
                            backgroundColor: Color(0xFFDBF3E2),
                            iconColor: Color(0xFF22543D),
                          ),
                        ),
                    ],
                  ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            booking.hasLiveTracking
                ? 'The provider marker updates while the provider keeps the app open on the way to the job.'
                : 'The customer location is already pinned. The provider marker appears as soon as live sharing starts.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _TrackingMarker extends StatelessWidget {
  const _TrackingMarker({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(color: Color(0x24000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Icon(icon, color: iconColor, size: 22),
    );
  }
}

String _formatDistanceMeters(double distanceMeters) {
  if (distanceMeters >= 1000) {
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km away';
  }
  return '${distanceMeters.round()} m away';
}

String _formatPinnedLocationLabel(Position position) {
  return 'Current location (${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)})';
}

String _formatPlacemarkAddress(Placemark placemark) {
  final parts = <String>[
    if ((placemark.street ?? '').trim().isNotEmpty) placemark.street!.trim(),
    if ((placemark.subLocality ?? '').trim().isNotEmpty) placemark.subLocality!.trim(),
    if ((placemark.locality ?? '').trim().isNotEmpty) placemark.locality!.trim(),
    if ((placemark.administrativeArea ?? '').trim().isNotEmpty) placemark.administrativeArea!.trim(),
  ];

  if (parts.isEmpty) {
    return 'Current location';
  }

  return parts.toSet().join(', ');
}

class _NotificationData {
  const _NotificationData({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime? createdAt;

  _NotificationData copyWith({bool? isRead}) {
    return _NotificationData(
      id: id,
      title: title,
      body: body,
      type: type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}

enum _BookingStatus {
  requested('Requested', 0.2, Color(0xFFD89B00), 'Match provider'),
  matched('Matched', 0.45, Color(0xFF006B3C), 'Mark en route'),
  enRoute('En route', 0.62, Color(0xFF006B3C), 'Mark arrived'),
  arrived('Arrived', 0.78, Color(0xFF0B8A4A), 'Start service'),
  inProgress('In progress', 0.9, Color(0xFF0B8A4A), 'Complete booking'),
  scheduled('Scheduled', 0.15, Color(0xFF2962FF), 'Activate booking'),
  completed('Completed', 1.0, Color(0xFF1F7A45), 'Completed'),
  cancelled('Cancelled', 1.0, Color(0xFF9E9E9E), 'Cancelled');

  const _BookingStatus(this.label, this.progress, this.color, this.nextActionLabel);

  final String label;
  final double progress;
  final Color color;
  final String nextActionLabel;
}

class _ProviderJobData {
  const _ProviderJobData({
    required this.id,
    required this.title,
    required this.timing,
    required this.pay,
    required this.distance,
    required this.category,
  });

  final String id;
  final String title;
  final String timing;
  final String pay;
  final String distance;
  final String category;
}

class _WalletEntryData {
  const _WalletEntryData(this.title, this.subtitle, this.amount, this.isCredit);

  final String title;
  final String subtitle;
  final String amount;
  final bool isCredit;
}
