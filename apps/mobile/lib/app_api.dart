import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class KaziApiException implements Exception {
  const KaziApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class KaziApiClient {
  KaziApiClient({String? baseUrl}) : baseUrl = baseUrl ?? _resolveBaseUrl();

  final String baseUrl;

  static String _resolveBaseUrl() {
    const override = String.fromEnvironment('KAZI_API_BASE_URL');
    if (override.isNotEmpty) {
      return override;
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:3001/api/v1';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3001/api/v1';
    }

    return 'http://127.0.0.1:3001/api/v1';
  }

  Future<void> sendOtp(String phone) async {
    await _request(
      'POST',
      '/auth/send-otp',
      body: {'phone': phone},
    );
  }

  Future<KaziSession> verifyOtp({
    required String phone,
    required String code,
    required String role,
  }) async {
    final payload = await _request(
      'POST',
      '/auth/verify-otp',
      body: {
        'phone': phone,
        'code': code,
        'role': role,
      },
    ) as Map<String, dynamic>;

    return KaziSession.fromJson(payload);
  }

  Future<ApiUser> getMe(String accessToken) async {
    final payload = await _request('GET', '/users/me', accessToken: accessToken)
        as Map<String, dynamic>;
    return ApiUser.fromJson(payload);
  }

  Future<List<ApiPromo>> listActivePromos(String accessToken) async {
    final payload = await _request(
      'GET',
      '/promos/active',
      accessToken: accessToken,
    ) as List<dynamic>;
    return payload
        .map((item) => ApiPromo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ApiReferralSummary> getReferralSummary(String accessToken) async {
    final payload = await _request(
      'GET',
      '/promos/referral-summary',
      accessToken: accessToken,
    ) as Map<String, dynamic>;
    return ApiReferralSummary.fromJson(payload);
  }

  Future<ApiReferralSummary> redeemReferralCode({
    required String accessToken,
    required String referralCode,
  }) async {
    final payload = await _request(
      'POST',
      '/promos/referral/redeem',
      accessToken: accessToken,
      body: {'referralCode': referralCode},
    ) as Map<String, dynamic>;
    return ApiReferralSummary.fromJson(payload);
  }

  Future<ApiNotificationFeed> listNotifications(String accessToken) async {
    final payload = await _request(
      'GET',
      '/notifications/mine',
      accessToken: accessToken,
    ) as Map<String, dynamic>;
    return ApiNotificationFeed.fromJson(payload);
  }

  Future<void> markNotificationRead({
    required String accessToken,
    required String notificationId,
  }) async {
    await _request(
      'PATCH',
      '/notifications/$notificationId/read',
      accessToken: accessToken,
    );
  }

  Future<void> markAllNotificationsRead(String accessToken) async {
    await _request(
      'PATCH',
      '/notifications/mine/read-all',
      accessToken: accessToken,
    );
  }

  Future<void> updateFcmToken({
    required String accessToken,
    required String fcmToken,
  }) async {
    await _request(
      'PATCH',
      '/users/me/fcm-token',
      accessToken: accessToken,
      body: {'fcmToken': fcmToken},
    );
  }

  Future<List<ApiServiceCategory>> listCategories() async {
    final payload = await _request('GET', '/services/categories') as List<dynamic>;
    return payload
        .map((item) => ApiServiceCategory.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ApiService>> listServices({String? categoryId}) async {
    final payload = await _request(
      'GET',
      '/services',
      queryParameters: categoryId == null ? null : {'categoryId': categoryId},
    ) as List<dynamic>;

    return payload
        .map((item) => ApiService.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ApiBooking> createBooking({
    required String accessToken,
    required String serviceCategoryId,
    required String serviceId,
    required String type,
    String? scheduledAt,
    String? customerAddress,
    String? customerNotes,
    String? promoCode,
    required int quotedPriceCents,
    required String paymentMethod,
  }) async {
    final payload = await _request(
      'POST',
      '/bookings',
      accessToken: accessToken,
      body: {
        'serviceCategoryId': serviceCategoryId,
        'serviceId': serviceId,
        'type': type,
        'scheduledAt': scheduledAt,
        'customerAddress': customerAddress,
        'customerNotes': customerNotes,
        'promoCode': promoCode,
        'quotedPriceCents': quotedPriceCents,
        'paymentMethod': paymentMethod,
      },
    ) as Map<String, dynamic>;

    return ApiBooking.fromJson(payload);
  }

  Future<List<ApiBooking>> listMyBookings(String accessToken) async {
    final payload = await _request('GET', '/bookings/mine', accessToken: accessToken)
        as List<dynamic>;
    return payload
        .map((item) => ApiBooking.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ApiBooking>> listAvailableBookings(String accessToken) async {
    final payload = await _request(
      'GET',
      '/bookings/provider/available',
      accessToken: accessToken,
    ) as List<dynamic>;
    return payload
        .map((item) => ApiBooking.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ApiBooking> acceptBooking({
    required String accessToken,
    required String bookingId,
  }) async {
    final payload = await _request(
      'PATCH',
      '/bookings/$bookingId/accept',
      accessToken: accessToken,
    ) as Map<String, dynamic>;
    return ApiBooking.fromJson(payload);
  }

  Future<ApiBooking> updateBookingStatus({
    required String accessToken,
    required String bookingId,
    required String status,
  }) async {
    final payload = await _request(
      'PATCH',
      '/bookings/$bookingId/status',
      accessToken: accessToken,
      body: {'status': status},
    ) as Map<String, dynamic>;
    return ApiBooking.fromJson(payload);
  }

  Future<ApiBooking> updateBookingTracking({
    required String accessToken,
    required String bookingId,
    required double latitude,
    required double longitude,
  }) async {
    final payload = await _request(
      'PATCH',
      '/bookings/$bookingId/tracking',
      accessToken: accessToken,
      body: {
        'latitude': latitude,
        'longitude': longitude,
      },
    ) as Map<String, dynamic>;
    return ApiBooking.fromJson(payload);
  }

  Future<void> createReview({
    required String accessToken,
    required String bookingId,
    required int rating,
    String? comment,
  }) async {
    await _request(
      'POST',
      '/reviews',
      accessToken: accessToken,
      body: {
        'bookingId': bookingId,
        'rating': rating,
        'comment': comment,
      },
    );
  }

  Future<ApiHostedCheckout> createHostedCheckout({
    required String accessToken,
    required String bookingId,
    String? returnUrl,
  }) async {
    final payload = await _request(
      'POST',
      '/payments/bookings/$bookingId/checkout',
      accessToken: accessToken,
      body: {
        if (returnUrl != null && returnUrl.trim().isNotEmpty) 'returnUrl': returnUrl.trim(),
      },
    ) as Map<String, dynamic>;
    return ApiHostedCheckout.fromJson(payload);
  }

  Future<ApiChatThread> getBookingChatThread({
    required String accessToken,
    required String bookingId,
  }) async {
    final payload = await _request(
      'GET',
      '/chat/bookings/$bookingId/thread',
      accessToken: accessToken,
    ) as Map<String, dynamic>;
    return ApiChatThread.fromJson(payload);
  }

  Future<ApiChatMessage> sendBookingChatMessage({
    required String accessToken,
    required String bookingId,
    required String message,
  }) async {
    final payload = await _request(
      'POST',
      '/chat/bookings/$bookingId/messages',
      accessToken: accessToken,
      body: {'message': message},
    ) as Map<String, dynamic>;
    return ApiChatMessage.fromJson(payload);
  }

  Future<ApiBookingCall> startBookingCall({
    required String accessToken,
    required String bookingId,
  }) async {
    final payload = await _request(
      'POST',
      '/chat/bookings/$bookingId/call',
      accessToken: accessToken,
      body: {},
    ) as Map<String, dynamic>;
    return ApiBookingCall.fromJson(payload);
  }

  Future<ApiProviderProfile> getMyProviderProfile(String accessToken) async {
    final payload = await _request(
      'GET',
      '/providers/me',
      accessToken: accessToken,
    ) as Map<String, dynamic>;
    return ApiProviderProfile.fromJson(payload);
  }

  Future<List<ApiProviderDocument>> listMyProviderDocuments(String accessToken) async {
    final payload = await _request(
      'GET',
      '/providers/me/documents',
      accessToken: accessToken,
    ) as Map<String, dynamic>;
    final items = payload['documents'] as List<dynamic>? ?? const [];
    return items
        .map((item) => ApiProviderDocument.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ApiProviderProfile> onboardProvider({
    required String accessToken,
    String? bio,
    String? serviceArea,
    List<String>? serviceCategoryIds,
  }) async {
    final payload = await _request(
      'POST',
      '/providers/onboarding',
      accessToken: accessToken,
      body: {
        'bio': bio,
        'serviceArea': serviceArea,
        'serviceCategoryIds': serviceCategoryIds,
        'documentsSubmitted': false,
      },
    ) as Map<String, dynamic>;
    return ApiProviderProfile.fromJson(payload);
  }

  Future<ApiProviderProfile> updateAvailability({
    required String accessToken,
    required bool isAvailable,
  }) async {
    final payload = await _request(
      'PATCH',
      '/providers/me/availability',
      accessToken: accessToken,
      body: {'isAvailable': isAvailable},
    ) as Map<String, dynamic>;
    return ApiProviderProfile.fromJson(payload);
  }

  Future<ApiProviderDocumentUploadResult> uploadProviderDocument({
    required String accessToken,
    required String documentType,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final uri = Uri.parse('$baseUrl/providers/me/documents/upload');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..headers['Accept'] = 'application/json'
      ..fields['documentType'] = documentType
      ..files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));

    try {
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      final decoded = response.body.isEmpty ? null : jsonDecode(response.body);

      if (response.statusCode >= 400) {
        throw KaziApiException(
          _extractMessage(decoded) ?? 'Upload failed with status ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      return ApiProviderDocumentUploadResult.fromJson(decoded as Map<String, dynamic>);
    } on TimeoutException {
      throw const KaziApiException('The provider document upload timed out.');
    } on http.ClientException {
      throw KaziApiException('Could not reach KAZI API at $baseUrl.');
    }
  }

  Future<dynamic> _request(
    String method,
    String path, {
    String? accessToken,
    Object? body,
    Map<String, String>? queryParameters,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
    final headers = <String, String>{'Accept': 'application/json'};
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }

    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) {
        request.body = jsonEncode(body);
      }

      final client = http.Client();
      final response = await client.send(request).timeout(const Duration(seconds: 15));
      final materialized = await http.Response.fromStream(response);
      client.close();
      final responseText = materialized.body;
      final decoded = responseText.isEmpty ? null : jsonDecode(responseText);

      if (materialized.statusCode >= 400) {
        throw KaziApiException(
          _extractMessage(decoded) ?? 'Request failed with status ${materialized.statusCode}',
          statusCode: materialized.statusCode,
        );
      }

      return decoded;
    } on TimeoutException {
      throw const KaziApiException('The API request timed out.');
    } on http.ClientException {
      throw KaziApiException('Could not reach KAZI API at $baseUrl.');
    }
  }

  String? _extractMessage(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final message = decoded['message'];
      if (message is String) {
        return message;
      }
      if (message is List && message.isNotEmpty) {
        return message.first.toString();
      }
    }

    return null;
  }
}

class KaziSession {
  const KaziSession({
    required this.accessToken,
    required this.refreshToken,
    required this.isNewUser,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final bool isNewUser;
  final ApiUser user;

  factory KaziSession.fromJson(Map<String, dynamic> json) {
    return KaziSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      isNewUser: json['isNewUser'] as bool? ?? false,
      user: ApiUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class ApiUser {
  const ApiUser({
    required this.id,
    required this.phone,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.walletBalanceCents,
  });

  final String id;
  final String phone;
  final String role;
  final String? firstName;
  final String? lastName;
  final int walletBalanceCents;

  String get displayName {
    final fullName = [firstName, lastName].whereType<String>().where((item) => item.isNotEmpty).join(' ');
    return fullName.isEmpty ? phone : fullName;
  }

  factory ApiUser.fromJson(Map<String, dynamic> json) {
    return ApiUser(
      id: json['id'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      walletBalanceCents: (json['walletBalanceCents'] as num?)?.toInt() ?? 0,
    );
  }
}

class ApiServiceCategory {
  const ApiServiceCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.iconKey,
  });

  final String id;
  final String name;
  final String slug;
  final String? iconKey;

  factory ApiServiceCategory.fromJson(Map<String, dynamic> json) {
    return ApiServiceCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      iconKey: json['iconKey'] as String?,
    );
  }
}

class ApiService {
  const ApiService({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.basePriceCents,
    required this.estimatedDurationMinutes,
    required this.supportsInstantBooking,
    required this.category,
  });

  final String id;
  final String categoryId;
  final String name;
  final String? description;
  final int basePriceCents;
  final int estimatedDurationMinutes;
  final bool supportsInstantBooking;
  final ApiServiceCategory? category;

  factory ApiService.fromJson(Map<String, dynamic> json) {
    return ApiService(
      id: json['id'] as String,
      categoryId: json['categoryId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      basePriceCents: (json['basePriceCents'] as num?)?.toInt() ?? 0,
      estimatedDurationMinutes: (json['estimatedDurationMinutes'] as num?)?.toInt() ?? 60,
      supportsInstantBooking: json['supportsInstantBooking'] as bool? ?? true,
      category: json['category'] is Map<String, dynamic>
          ? ApiServiceCategory.fromJson(json['category'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ApiBooking {
  const ApiBooking({
    required this.id,
    required this.bookingRef,
    required this.serviceId,
    required this.serviceCategoryId,
    required this.type,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.quotedPriceCents,
    required this.finalPriceCents,
    required this.customerAddress,
    required this.providerCurrentLat,
    required this.providerCurrentLng,
    required this.providerLocationUpdatedAt,
    required this.isRated,
    required this.createdAt,
    required this.scheduledAt,
  });

  final String id;
  final String bookingRef;
  final String serviceId;
  final String serviceCategoryId;
  final String type;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final int quotedPriceCents;
  final int finalPriceCents;
  final String? customerAddress;
  final double? providerCurrentLat;
  final double? providerCurrentLng;
  final DateTime? providerLocationUpdatedAt;
  final bool isRated;
  final DateTime? createdAt;
  final DateTime? scheduledAt;

  int get displayPriceCents => finalPriceCents > 0 ? finalPriceCents : quotedPriceCents;

  factory ApiBooking.fromJson(Map<String, dynamic> json) {
    return ApiBooking(
      id: json['id'] as String,
      bookingRef: json['bookingRef'] as String,
      serviceId: json['serviceId'] as String,
      serviceCategoryId: json['serviceCategoryId'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      paymentMethod: json['paymentMethod'] as String,
      paymentStatus: json['paymentStatus'] as String? ?? 'pending',
      quotedPriceCents: (json['quotedPriceCents'] as num?)?.toInt() ?? 0,
      finalPriceCents: (json['finalPriceCents'] as num?)?.toInt() ?? 0,
      customerAddress: json['customerAddress'] as String?,
      providerCurrentLat: (json['providerCurrentLat'] as num?)?.toDouble(),
      providerCurrentLng: (json['providerCurrentLng'] as num?)?.toDouble(),
      providerLocationUpdatedAt: _parseDate(json['providerLocationUpdatedAt']),
      isRated: json['isRated'] as bool? ?? false,
      createdAt: _parseDate(json['createdAt']),
      scheduledAt: _parseDate(json['scheduledAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class ApiProviderProfile {
  const ApiProviderProfile({
    required this.isAvailable,
    required this.verificationStatus,
    required this.documentsSubmitted,
  });

  final bool isAvailable;
  final String verificationStatus;
  final bool documentsSubmitted;

  factory ApiProviderProfile.fromJson(Map<String, dynamic> json) {
    return ApiProviderProfile(
      isAvailable: json['isAvailable'] as bool? ?? false,
      verificationStatus: json['verificationStatus'] as String? ?? 'pending',
      documentsSubmitted: json['documentsSubmitted'] as bool? ?? false,
    );
  }
}

class ApiProviderDocument {
  const ApiProviderDocument({
    required this.id,
    required this.documentType,
    required this.fileName,
    required this.status,
    required this.fileUrl,
  });

  final String id;
  final String documentType;
  final String fileName;
  final String status;
  final String? fileUrl;

  factory ApiProviderDocument.fromJson(Map<String, dynamic> json) {
    return ApiProviderDocument(
      id: json['id'] as String,
      documentType: json['documentType'] as String? ?? 'document',
      fileName: json['fileName'] as String? ?? 'file',
      status: json['status'] as String? ?? 'submitted',
      fileUrl: json['fileUrl'] as String?,
    );
  }
}

class ApiProviderDocumentUploadResult {
  const ApiProviderDocumentUploadResult({
    required this.uploaded,
    required this.documents,
  });

  final ApiProviderDocument uploaded;
  final List<ApiProviderDocument> documents;

  factory ApiProviderDocumentUploadResult.fromJson(Map<String, dynamic> json) {
    final documents = json['documents'] as List<dynamic>? ?? const [];
    return ApiProviderDocumentUploadResult(
      uploaded: ApiProviderDocument.fromJson(json['uploaded'] as Map<String, dynamic>),
      documents: documents
          .map((item) => ApiProviderDocument.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ApiHostedCheckout {
  const ApiHostedCheckout({
    required this.bookingId,
    required this.paymentId,
    required this.paymentMethod,
    required this.status,
    required this.checkoutId,
    required this.checkoutUrl,
    required this.amountCents,
  });

  final String bookingId;
  final String? paymentId;
  final String? paymentMethod;
  final String status;
  final String? checkoutId;
  final String? checkoutUrl;
  final int? amountCents;

  factory ApiHostedCheckout.fromJson(Map<String, dynamic> json) {
    return ApiHostedCheckout(
      bookingId: json['bookingId'] as String,
      paymentId: json['paymentId'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
      status: json['status'] as String? ?? 'pending',
      checkoutId: json['checkoutId'] as String?,
      checkoutUrl: json['checkoutUrl'] as String?,
      amountCents: (json['amountCents'] as num?)?.toInt(),
    );
  }
}

class ApiNotificationFeed {
  const ApiNotificationFeed({
    required this.unreadCount,
    required this.items,
  });

  final int unreadCount;
  final List<ApiNotification> items;

  factory ApiNotificationFeed.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List<dynamic>? ?? const [];
    return ApiNotificationFeed(
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      items: items
          .map((item) => ApiNotification.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ApiNotification {
  const ApiNotification({
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

  factory ApiNotification.fromJson(Map<String, dynamic> json) {
    return ApiNotification(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Notification',
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? 'general',
      isRead: json['isRead'] as bool? ?? false,
      createdAt: ApiBooking._parseDate(json['createdAt']),
    );
  }
}

class ApiPromo {
  const ApiPromo({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.minBookingAmountCents,
  });

  final String id;
  final String code;
  final String title;
  final String? description;
  final String discountType;
  final int discountValue;
  final int minBookingAmountCents;

  factory ApiPromo.fromJson(Map<String, dynamic> json) {
    return ApiPromo(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? 'Promo',
      description: json['description'] as String?,
      discountType: json['discountType'] as String? ?? 'flat',
      discountValue: (json['discountValue'] as num?)?.toInt() ?? 0,
      minBookingAmountCents: (json['minBookingAmountCents'] as num?)?.toInt() ?? 0,
    );
  }
}

class ApiReferralSummary {
  const ApiReferralSummary({
    required this.referralCode,
    required this.referredByCode,
    required this.referralsCount,
    required this.rewardPerReferralCents,
    required this.referralEarningsCents,
  });

  final String? referralCode;
  final String? referredByCode;
  final int referralsCount;
  final int rewardPerReferralCents;
  final int referralEarningsCents;

  factory ApiReferralSummary.fromJson(Map<String, dynamic> json) {
    return ApiReferralSummary(
      referralCode: json['referralCode'] as String?,
      referredByCode: json['referredByCode'] as String?,
      referralsCount: (json['referralsCount'] as num?)?.toInt() ?? 0,
      rewardPerReferralCents: (json['rewardPerReferralCents'] as num?)?.toInt() ?? 0,
      referralEarningsCents: (json['referralEarningsCents'] as num?)?.toInt() ?? 0,
    );
  }
}

class ApiChatThread {
  const ApiChatThread({
    required this.bookingId,
    required this.bookingRef,
    required this.participant,
    required this.messages,
  });

  final String bookingId;
  final String bookingRef;
  final ApiChatParticipant participant;
  final List<ApiChatMessage> messages;

  factory ApiChatThread.fromJson(Map<String, dynamic> json) {
    final items = json['messages'] as List<dynamic>? ?? const [];
    return ApiChatThread(
      bookingId: json['bookingId'] as String,
      bookingRef: json['bookingRef'] as String? ?? '',
      participant: ApiChatParticipant.fromJson(json['participant'] as Map<String, dynamic>),
      messages: items
          .map((item) => ApiChatMessage.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ApiChatParticipant {
  const ApiChatParticipant({
    required this.id,
    required this.displayName,
    required this.phone,
  });

  final String id;
  final String displayName;
  final String phone;

  factory ApiChatParticipant.fromJson(Map<String, dynamic> json) {
    return ApiChatParticipant(
      id: json['id'] as String,
      displayName: json['displayName'] as String? ?? 'Participant',
      phone: json['phone'] as String? ?? '',
    );
  }
}

class ApiChatMessage {
  const ApiChatMessage({
    required this.id,
    required this.bookingId,
    required this.senderId,
    required this.recipientId,
    required this.messageType,
    required this.message,
    required this.callStatus,
    required this.createdAt,
  });

  final String id;
  final String bookingId;
  final String senderId;
  final String recipientId;
  final String messageType;
  final String message;
  final String? callStatus;
  final DateTime? createdAt;

  factory ApiChatMessage.fromJson(Map<String, dynamic> json) {
    return ApiChatMessage(
      id: json['id'] as String,
      bookingId: json['bookingId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      recipientId: json['recipientId'] as String? ?? '',
      messageType: json['messageType'] as String? ?? 'text',
      message: json['message'] as String? ?? '',
      callStatus: json['callStatus'] as String?,
      createdAt: ApiBooking._parseDate(json['createdAt']),
    );
  }
}

class ApiBookingCall {
  const ApiBookingCall({
    required this.bookingId,
    required this.bookingRef,
    required this.participantName,
    required this.participantPhone,
    required this.callLogId,
    required this.callMode,
    required this.callProvider,
    required this.callStatus,
    required this.statusMessage,
    required this.startedAt,
  });

  final String bookingId;
  final String bookingRef;
  final String participantName;
  final String participantPhone;
  final String callLogId;
  final String callMode;
  final String callProvider;
  final String callStatus;
  final String statusMessage;
  final DateTime? startedAt;

  factory ApiBookingCall.fromJson(Map<String, dynamic> json) {
    return ApiBookingCall(
      bookingId: json['bookingId'] as String,
      bookingRef: json['bookingRef'] as String? ?? '',
      participantName: json['participantName'] as String? ?? 'Participant',
      participantPhone: json['participantPhone'] as String? ?? '',
      callLogId: json['callLogId'] as String? ?? '',
      callMode: json['callMode'] as String? ?? 'phone_fallback',
      callProvider: json['callProvider'] as String? ?? 'device_dialer',
      callStatus: json['callStatus'] as String? ?? 'fallback_ready',
      statusMessage: json['statusMessage'] as String? ?? '',
      startedAt: ApiBooking._parseDate(json['startedAt']),
    );
  }
}