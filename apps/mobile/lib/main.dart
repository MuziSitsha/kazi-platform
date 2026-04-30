import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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

const _serviceCategories = ['All', 'Cleaning', 'Electrical', 'Plumbing', 'Handyman'];

const _services = [
  _ServiceData(
    id: 'clean-deep',
    category: 'Cleaning',
    title: 'Deep Cleaning',
    subtitle: 'Apartments, homes, and move-in resets.',
    priceFrom: 'From R450',
    eta: '12 min avg arrival',
    icon: Icons.cleaning_services_outlined,
  ),
  _ServiceData(
    id: 'clean-office',
    category: 'Cleaning',
    title: 'Office Refresh',
    subtitle: 'Flexible teams for recurring office cleans.',
    priceFrom: 'From R650',
    eta: 'Scheduled slots',
    icon: Icons.business_center_outlined,
  ),
  _ServiceData(
    id: 'electrical-urgent',
    category: 'Electrical',
    title: 'Urgent Electrical',
    subtitle: 'Faults, trips, fittings, and assessments.',
    priceFrom: 'From R780',
    eta: '18 min avg arrival',
    icon: Icons.electrical_services_outlined,
  ),
  _ServiceData(
    id: 'plumbing-fix',
    category: 'Plumbing',
    title: 'Leak and Pipe Fix',
    subtitle: 'Repairs, replacements, and diagnostics.',
    priceFrom: 'From R720',
    eta: '21 min avg arrival',
    icon: Icons.plumbing_outlined,
  ),
  _ServiceData(
    id: 'handyman-home',
    category: 'Handyman',
    title: 'Handyman Assist',
    subtitle: 'Assembly, patching, hanging, and repairs.',
    priceFrom: 'From R520',
    eta: 'Same-day availability',
    icon: Icons.handyman_outlined,
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

IconData _iconForCategory(String label) {
  final key = label.toLowerCase();
  if (key.contains('clean')) return Icons.cleaning_services_outlined;
  if (key.contains('electric')) return Icons.electrical_services_outlined;
  if (key.contains('plumb')) return Icons.plumbing_outlined;
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

  static _KaziController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_AppScope>();
    assert(scope != null, 'No _AppScope found in context');
    return scope!.notifier!;
  }
}

class _KaziController extends ChangeNotifier {
  static const String _configuredPushToken = String.fromEnvironment('KAZI_FCM_TOKEN');

  _KaziController() {
    bootstrap();
  }

  final KaziApiClient api = KaziApiClient();

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

  final Map<String, ApiService> _liveServicesById = {};
  final Map<String, ApiServiceCategory> _categoriesById = {};

  bool get isAuthenticated => session != null;
  bool get isCustomer => currentUser?.role == 'customer';
  bool get isProvider => currentUser?.role == 'provider';
  String get apiBaseUrl => api.baseUrl;
  bool get hasLiveCatalog => _liveServicesById.isNotEmpty;
  int get unreadNotifications => notifications.where((item) => !item.isRead).length;

  Future<void> bootstrap() async {
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

      if (categories.isNotEmpty) {
        serviceCategories = ['All', ...categories.map((category) => category.name)];
      }

      if (liveServices.isNotEmpty) {
        services = liveServices.map(_mapService).toList();
      }
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
  }) async {
    session = await api.verifyOtp(phone: phone, code: code, role: role);
    currentUser = session!.user;
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

  Future<void> advanceBooking(_BookingData booking) async {
    if (session == null) {
      throw const KaziApiException('Sign in as a provider first.');
    }

    final nextStatus = switch (booking.status) {
      _BookingStatus.matched => 'en_route',
      _BookingStatus.enRoute => 'completed',
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
    if (session == null || !isCustomer) {
      throw const KaziApiException('Sign in as a customer to leave a review.');
    }

    await api.createReview(
      accessToken: session!.accessToken,
      bookingId: booking.id,
      rating: rating,
      comment: comment,
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
  }) async {
    if (session == null || !isCustomer) {
      throw const KaziApiException('Sign in as a customer to create a booking.');
    }

    final liveService = _liveServicesById[service.id];
    if (liveService == null) {
      throw const KaziApiException(
        'This service is not yet available from the live API catalog. Add service records in the backend first.',
      );
    }

    final scheduledAt = scheduled
        ? DateTime.now().add(const Duration(days: 1)).copyWith(hour: 9, minute: 0)
        : null;

    await api.createBooking(
      accessToken: session!.accessToken,
      serviceCategoryId: liveService.categoryId,
      serviceId: liveService.id,
      type: scheduled ? 'scheduled' : 'instant',
      scheduledAt: scheduledAt?.toIso8601String(),
      customerAddress: customerAddress,
      customerNotes: customerNotes.isEmpty ? null : customerNotes,
      promoCode: promoCode?.trim().isEmpty == true ? null : promoCode?.trim(),
      quotedPriceCents: liveService.basePriceCents,
      paymentMethod: paymentMethod.toLowerCase(),
    );

    await refreshAuthenticatedData();
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

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const KaziApiException('Enable device location services before sharing live tracking.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw const KaziApiException('Location permission is required to share live tracking.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    await api.updateBookingTracking(
      accessToken: session!.accessToken,
      bookingId: booking.id,
      latitude: position.latitude,
      longitude: position.longitude,
    );

    await refreshAuthenticatedData();
  }

  Future<void> openTrackingMap(_BookingData booking) async {
    final latitude = booking.providerCurrentLat;
    final longitude = booking.providerCurrentLng;
    if (latitude == null || longitude == null) {
      throw const KaziApiException('This booking does not have a live provider location yet.');
    }

    final uri = Uri.parse(
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
      icon: _iconForCategory(category?.name ?? service.name),
    );
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
      providerCurrentLat: booking.providerCurrentLat,
      providerCurrentLng: booking.providerCurrentLng,
      providerLocationUpdatedAt: booking.providerLocationUpdatedAt,
      isRated: booking.isRated,
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
      'arrived' => _BookingStatus.enRoute,
      'in_progress' => _BookingStatus.enRoute,
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
  String? _error;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: '0821234567');
    _role = widget.initialRole;
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
            const Text('Local development uses the real OTP endpoints. In dev mode, the API logs the OTP code to the backend console.'),
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
  String _selectedCategory = _serviceCategories.first;
  String _searchQuery = '';
  _ServiceData? _lastBookedService;

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

    final addressController = TextEditingController(text: 'Sandton, Johannesburg');
    final notesController = TextEditingController();
    final promoController = TextEditingController();
    var scheduled = scheduledDefault;
    var paymentMethod = 'Card';
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
                    Text(service.title, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(service.subtitle, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 20),
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Service address',
                        border: OutlineInputBorder(),
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
                                await controller.createBooking(
                                  service: service,
                                  scheduled: scheduled,
                                  customerAddress: addressController.text.trim(),
                                  customerNotes: notesController.text.trim(),
                                  paymentMethod: paymentMethod,
                                  promoCode: promoController.text.trim(),
                                );

                                if (!mounted) return;
                                navigator.pop();
                                setState(() => _lastBookedService = service);
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
    final categoryOptions = controller.serviceCategories;

    if (!categoryOptions.contains(_selectedCategory)) {
      _selectedCategory = categoryOptions.first;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AdaptiveSplit(
            primary: _HeroCard(
              title: 'Book a verified pro in Johannesburg with fast, clear service flow.',
              body:
                  'Choose a category, request help now or schedule ahead, and keep every booking update, message, and payment in one place.',
              primaryLabel: 'Book now',
              secondaryLabel: 'Schedule service',
              onPrimaryPressed: services.isEmpty ? () {} : () => _openBookingSheet(services.first),
              onSecondaryPressed: services.isEmpty ? () {} : () => _openBookingSheet(services.first, scheduledDefault: true),
            ),
            secondary: _SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Booking state', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  const _InlineStatus(label: 'Coverage', value: 'Johannesburg, Sandton, Midrand and surrounds'),
                  const SizedBox(height: 10),
                  _InlineStatus(label: 'Signed in as', value: controller.currentUser?.role ?? 'Guest'),
                  const SizedBox(height: 10),
                  _InlineStatus(
                    label: 'Last booked service',
                    value: _lastBookedService?.title ?? 'None yet',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeading(
            title: 'Browse services',
            subtitle: 'Filter, search, and launch the booking flow from any screen size.',
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search cleaning, plumbing, or urgent help',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categoryOptions
                .map(
                  (category) => ChoiceChip(
                    label: Text(category),
                    selected: _selectedCategory == category,
                    onSelected: (_) => setState(() => _selectedCategory = category),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          if (services.isEmpty)
            const _SurfaceCard(
              child: Text('No live services available yet. Seed service categories and services in the backend to start real bookings.'),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final serviceCardAspectRatio = switch (constraints.maxWidth) {
                  < 1100 => 0.68,
                  _ => 1.02,
                };

                return _ResponsiveGrid(
                  minTileWidth: 240,
                  maxColumns: 3,
                  childAspectRatio: serviceCardAspectRatio,
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
        ],
      ),
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
      await controller.refreshAuthenticatedData();
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
                    Text('Rate ${booking.serviceTitle}', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    const Text('How was your provider experience?'),
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
                      decoration: const InputDecoration(
                        labelText: 'Review note',
                        border: OutlineInputBorder(),
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
                                  const SnackBar(content: Text('Review submitted successfully.')),
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
          const _SectionHeading(
            title: 'Booking workflow',
            subtitle: 'Move bookings through the lifecycle and keep the state readable on every screen size.',
          ),
          const SizedBox(height: 12),
          _ResponsiveGrid(
            minTileWidth: 180,
            maxColumns: 4,
            childAspectRatio: 1.35,
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
                        onReview: controller.isCustomer &&
                                booking.status == _BookingStatus.completed &&
                                !booking.isRated
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
                        trackActionLabel: controller.isProvider
                            ? 'Update live location'
                            : booking.hasLiveTracking
                                ? 'Open live map'
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
              backgroundColor: KaziTheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Provider operations', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  const Text(
                    'Toggle availability, accept work, and keep your active queue visible in a single adaptive layout.',
                    style: TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  if (controller.providerProfileMissing)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: FilledButton.tonal(
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
                      ),
                    ),
                  if (!controller.providerProfileMissing) ...[
                    DropdownButtonFormField<String>(
                      key: ValueKey(_selectedDocumentType),
                      initialValue: _selectedDocumentType,
                      decoration: const InputDecoration(
                        labelText: 'Verification document type',
                        border: OutlineInputBorder(),
                      ),
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
                    const SizedBox(height: 16),
                  ],
                  SwitchListTile(
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
                ],
              ),
            ),
            secondary: _SurfaceCard(
              backgroundColor: KaziTheme.primaryGreen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Provider status',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
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
            subtitle: 'Accept work directly from the provider view and keep tablet density without losing mobile clarity.',
          ),
          const SizedBox(height: 12),
          _ResponsiveGrid(
            minTileWidth: 240,
            maxColumns: 3,
            childAspectRatio: 1.1,
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
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          const _SectionHeading(
            title: 'Today\'s accepted jobs',
            subtitle: 'Accepted jobs move into the live queue for the provider.',
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
                      child: _AcceptedJobTile(job: job),
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
          const _SectionHeading(
            title: 'Wallet and history',
            subtitle: 'Switch context between customer and provider views while keeping transactions readable on every device size.',
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 16),
          _ResponsiveGrid(
            minTileWidth: 220,
            maxColumns: 3,
            childAspectRatio: 1.2,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Transaction history', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  ...history.map((entry) => _WalletHistoryTile(entry: entry)),
                ],
              ),
            ),
            secondary: _SurfaceCard(
              backgroundColor: const Color(0xFFFFF4D6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payout and promo rules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimaryPressed,
    required this.onSecondaryPressed,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF006B3C), Color(0xFF0D8C54)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1.05,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Text(body, style: const TextStyle(color: Colors.white70, height: 1.5)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(onPressed: onPrimaryPressed, child: Text(primaryLabel)),
              OutlinedButton(
                onPressed: onSecondaryPressed,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                child: Text(secondaryLabel),
              ),
            ],
          ),
        ],
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

  String _formatTimestamp(DateTime? createdAt) {
    if (createdAt == null) {
      return 'Just now';
    }

    final difference = DateTime.now().difference(createdAt);
    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours} hr ago';
    }
    return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
  }

  IconData _iconForNotification(String type) {
    if (type.contains('cancel')) return Icons.event_busy_outlined;
    if (type.contains('complete')) return Icons.task_alt_outlined;
    if (type.contains('accept') || type.contains('assigned')) return Icons.person_pin_circle_outlined;
    if (type.contains('route') || type.contains('arrived')) return Icons.near_me_outlined;
    return Icons.notifications_active_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _AppScope.of(context);
    final notifications = controller.notifications;
    final messenger = ScaffoldMessenger.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notifications', style: Theme.of(context).textTheme.headlineSmall),
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
                            messenger.showSnackBar(SnackBar(content: Text(error.toString())));
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
                      child: Text('Booking updates, provider movement, chat alerts, and payment confirmations will appear here.'),
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
                                      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
                                    }
                                  },
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: item.isRead ? KaziTheme.surface : const Color(0xFFE6F4EC),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    _iconForNotification(item.type),
                                    color: item.isRead ? const Color(0xFF5A675F) : KaziTheme.primaryGreen,
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
                                                fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
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
    );
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 220;
          final buttonStyle = compact
              ? const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )
              : null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 40 : 48,
                height: compact ? 40 : 48,
                decoration: BoxDecoration(
                  color: KaziTheme.surface,
                  borderRadius: BorderRadius.circular(compact ? 14 : 16),
                ),
                child: Icon(data.icon, color: KaziTheme.primaryGreen, size: compact ? 20 : 24),
              ),
              SizedBox(height: compact ? 12 : 16),
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: compact ? 16 : 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                data.subtitle,
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF4F5B53), height: 1.45),
              ),
              SizedBox(height: compact ? 12 : 16),
              if (compact)
                Text(
                  '${data.priceFrom} • ${data.eta}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A231D)),
                )
              else ...[
                _InlineStatus(label: 'Price', value: data.priceFrom),
                const SizedBox(height: 10),
                _InlineStatus(label: 'Dispatch', value: data.eta),
              ],
              SizedBox(height: compact ? 12 : 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: onBook,
                    style: buttonStyle,
                    child: Text(compact ? 'Book' : 'Book now'),
                  ),
                  OutlinedButton(
                    onPressed: onSchedule,
                    style: buttonStyle,
                    child: Text(compact ? 'Later' : 'Schedule'),
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
    this.trackActionLabel,
  });

  final _BookingData booking;
  final VoidCallback? onAdvance;
  final VoidCallback? onReview;
  final VoidCallback? onPayNow;
  final VoidCallback? onMessage;
  final VoidCallback? onCall;
  final VoidCallback? onTrack;
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
          if (onReview != null || onPayNow != null || onMessage != null || onCall != null || onTrack != null) ...[
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
  const _IncomingJobCard({required this.data, required this.onAccept});

  final _ProviderJobData data;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(data.category, style: const TextStyle(color: Color(0xFF4F5B53))),
          const SizedBox(height: 10),
          _InlineStatus(label: 'Timing', value: data.timing),
          const SizedBox(height: 10),
          _InlineStatus(label: 'Budget', value: data.pay),
          const SizedBox(height: 10),
          _InlineStatus(label: 'Distance', value: data.distance),
          const Spacer(),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onAccept,
            child: Text(onAccept == null ? 'Unavailable' : 'Accept job'),
          ),
        ],
      ),
    );
  }
}

class _AcceptedJobTile extends StatelessWidget {
  const _AcceptedJobTile({required this.job});

  final _ProviderJobData job;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      backgroundColor: KaziTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(job.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _InlineStatus(label: 'Time', value: job.timing),
          const SizedBox(height: 8),
          _InlineStatus(label: 'Pay', value: job.pay),
          const SizedBox(height: 8),
          _InlineStatus(label: 'Distance', value: job.distance),
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
                Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w700)),
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
    required this.childAspectRatio,
    required this.children,
  });

  final double minTileWidth;
  final int maxColumns;
  final double childAspectRatio;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(
          1,
          math.min(maxColumns, ((constraints.maxWidth + 16) / (minTileWidth + 16)).floor()),
        );

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: children.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) => children[index],
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
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF4F5B53)),
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
      backgroundColor: KaziTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF4F5B53))),
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
    required this.icon,
  });

  final String id;
  final String category;
  final String title;
  final String subtitle;
  final String priceFrom;
  final String eta;
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
    required this.providerCurrentLat,
    required this.providerCurrentLng,
    required this.providerLocationUpdatedAt,
    required this.isRated,
  });

  final String id;
  final String serviceTitle;
  final String address;
  final String schedule;
  final _BookingStatus status;
  final String paymentMethod;
  final String paymentStatus;
  final String amount;
  final double? providerCurrentLat;
  final double? providerCurrentLng;
  final DateTime? providerLocationUpdatedAt;
  final bool isRated;

  bool get canPayOnline =>
      (paymentMethod == 'CARD' || paymentMethod == 'EFT') && paymentStatus != 'PAID' && status != _BookingStatus.cancelled;

  bool get supportsLiveTracking =>
      status == _BookingStatus.matched || status == _BookingStatus.enRoute;

  bool get hasLiveTracking => providerCurrentLat != null && providerCurrentLng != null;

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
    return '${providerCurrentLat!.toStringAsFixed(5)}, ${providerCurrentLng!.toStringAsFixed(5)} • $freshness';
  }

  _BookingData copyWith({_BookingStatus? status, bool? isRated}) {
    return _BookingData(
      id: id,
      serviceTitle: serviceTitle,
      address: address,
      schedule: schedule,
      status: status ?? this.status,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      amount: amount,
      providerCurrentLat: providerCurrentLat,
      providerCurrentLng: providerCurrentLng,
      providerLocationUpdatedAt: providerLocationUpdatedAt,
      isRated: isRated ?? this.isRated,
    );
  }
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
  enRoute('En route', 0.75, Color(0xFF006B3C), 'Complete booking'),
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
