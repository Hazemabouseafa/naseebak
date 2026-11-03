import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../models/subscription_model.dart';
import '../repositories/subscription_repository.dart';

class GooglePlayPurchaseEvent {
  final String productId;
  final String purchaseToken;
  final PurchaseStatus status;
  final String? errorMessage;
  final PurchaseDetails? rawPurchaseDetails;

  const GooglePlayPurchaseEvent({
    required this.productId,
    required this.purchaseToken,
    required this.status,
    this.errorMessage,
    this.rawPurchaseDetails,
  });
}

/// Abstraction over `InAppPurchase` so that real Android Google Play Billing
/// works in production while unit/widget tests can inject a deterministic mock.
abstract class GooglePlayBillingGateway {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<void> completePurchase(PurchaseDetails purchase);
  Future<void> restorePurchases({String? applicationUserName});
}

class NativeGooglePlayBillingGateway implements GooglePlayBillingGateway {
  final InAppPurchase _iap = InAppPurchase.instance;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      _iap.queryProductDetails(identifiers);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _iap.buyNonConsumable(purchaseParam: purchaseParam);

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);

  @override
  Future<void> restorePurchases({String? applicationUserName}) =>
      _iap.restorePurchases(applicationUserName: applicationUserName);
}

class GooglePlayBillingClientService {
  final GooglePlayBillingGateway _gateway;
  final Map<String, ProductDetails> _cachedProductDetails = {};

  GooglePlayBillingClientService({GooglePlayBillingGateway? gateway})
      : _gateway = gateway ?? NativeGooglePlayBillingGateway();

  Stream<List<PurchaseDetails>> get purchaseStream => _gateway.purchaseStream;

  /// Queries Google Play Billing for the localized price & currency of [productId].
  /// Never invents or hardcodes a fallback price if the product is unavailable.
  Future<StoreProductPricingModel?> querySubscriptionProduct(
    String productId,
  ) async {
    final available = await _gateway.isAvailable();
    if (!available) {
      return null;
    }

    final response = await _gateway.queryProductDetails({productId});
    if (response.error != null || response.productDetails.isEmpty) {
      return null;
    }

    final product = response.productDetails.first;
    _cachedProductDetails[product.id] = product;

    return StoreProductPricingModel(
      productId: product.id,
      title: product.title,
      description: product.description,
      formattedPrice: product.price,
      rawPrice: product.rawPrice,
      currencyCode: product.currencyCode,
    );
  }

  /// Launches the official Google Play Billing subscription sheet.
  Future<bool> startSubscriptionPurchase({
    required String productId,
    String? obfuscatedAccountId,
  }) async {
    ProductDetails? product = _cachedProductDetails[productId];
    if (product == null) {
      final response = await _gateway.queryProductDetails({productId});
      if (response.productDetails.isNotEmpty) {
        product = response.productDetails.first;
        _cachedProductDetails[product.id] = product;
      }
    }

    if (product == null) {
      throw Exception(
        'باقة الاشتراك غير متاحة حالياً في متجر Google Play لهذا الجهاز.',
      );
    }

    final param = PurchaseParam(
      productDetails: product,
      applicationUserName: obfuscatedAccountId,
    );

    return _gateway.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases({String? obfuscatedAccountId}) async {
    await _gateway.restorePurchases(applicationUserName: obfuscatedAccountId);
  }

  Future<void> completePurchaseIfNeeded(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _gateway.completePurchase(purchase);
    }
  }
}

/// Sends the Google Play purchase token to the Laravel backend (`POST /api/v1/subscription/google-play/verify`)
/// and returns the verified server-side entitlement. Never grants entitlement locally without backend confirmation.
class PurchaseVerificationService {
  final SubscriptionRepository _repository;

  const PurchaseVerificationService({
    required SubscriptionRepository repository,
  }) : _repository = repository;

  Future<SubscriptionOverviewResponse> verifyWithBackend({
    required String productId,
    required String purchaseToken,
  }) {
    return _repository.verifyGooglePlayPurchase(
      productId: productId,
      purchaseToken: purchaseToken,
    );
  }
}
