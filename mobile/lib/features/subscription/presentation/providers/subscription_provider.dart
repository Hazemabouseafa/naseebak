import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/subscription_model.dart';
import '../../data/repositories/subscription_repository.dart';
import '../../data/services/google_play_billing_service.dart';

enum SubscriptionUiPhase {
  loading,
  noSubscription,
  availablePlan,
  purchaseInProgress,
  purchasePending,
  verificationPending,
  activeSubscription,
  cancelledButValid,
  expiredSubscription,
  purchaseFailure,
  productUnavailable,
}

class SubscriptionState {
  final bool isLoading;
  final SubscriptionUiPhase uiPhase;
  final SubscriptionEntitlementModel entitlement;
  final SubscriptionRecordModel? currentSubscription;
  final SubscriptionPlanModel? activePlan;
  final StoreProductPricingModel? storePricing;
  final List<SubscriptionRecordModel> history;
  final String googlePlayManageUrl;
  final String? errorMessage;
  final String? statusBannerMessage;

  const SubscriptionState({
    this.isLoading = false,
    this.uiPhase = SubscriptionUiPhase.loading,
    required this.entitlement,
    this.currentSubscription,
    this.activePlan,
    this.storePricing,
    this.history = const [],
    this.googlePlayManageUrl =
        'https://play.google.com/store/account/subscriptions',
    this.errorMessage,
    this.statusBannerMessage,
  });

  factory SubscriptionState.initial() {
    return SubscriptionState(
      isLoading: true,
      uiPhase: SubscriptionUiPhase.loading,
      entitlement: SubscriptionEntitlementModel.freeDefault(),
    );
  }

  SubscriptionState copyWith({
    bool? isLoading,
    SubscriptionUiPhase? uiPhase,
    SubscriptionEntitlementModel? entitlement,
    SubscriptionRecordModel? currentSubscription,
    SubscriptionPlanModel? activePlan,
    StoreProductPricingModel? storePricing,
    List<SubscriptionRecordModel>? history,
    String? googlePlayManageUrl,
    String? errorMessage,
    String? statusBannerMessage,
    bool clearError = false,
    bool clearBanner = false,
  }) {
    return SubscriptionState(
      isLoading: isLoading ?? this.isLoading,
      uiPhase: uiPhase ?? this.uiPhase,
      entitlement: entitlement ?? this.entitlement,
      currentSubscription: currentSubscription ?? this.currentSubscription,
      activePlan: activePlan ?? this.activePlan,
      storePricing: storePricing ?? this.storePricing,
      history: history ?? this.history,
      googlePlayManageUrl: googlePlayManageUrl ?? this.googlePlayManageUrl,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusBannerMessage:
          clearBanner ? null : (statusBannerMessage ?? this.statusBannerMessage),
    );
  }
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final SubscriptionRepository _repository;
  final GooglePlayBillingClientService _billingClient;
  final PurchaseVerificationService _verificationService;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  SubscriptionNotifier({
    required SubscriptionRepository repository,
    required GooglePlayBillingClientService billingClient,
    required PurchaseVerificationService verificationService,
  })  : _repository = repository,
        _billingClient = billingClient,
        _verificationService = verificationService,
        super(SubscriptionState.initial()) {
    _purchaseSubscription =
        _billingClient.purchaseStream.listen(_handlePurchaseUpdates);
  }

  /// Loads subscription status, plans, history, and localized Google Play pricing.
  Future<void> loadSubscriptionCenter() async {
    state = state.copyWith(
      isLoading: true,
      uiPhase: SubscriptionUiPhase.loading,
      clearError: true,
      clearBanner: true,
    );

    try {
      final overview = await _repository.fetchSubscriptionOverview();
      final plans = await _repository.fetchPlans();
      final history = await _repository.fetchSubscriptionHistory();

      final primaryPlan = plans.isNotEmpty ? plans.first : null;
      StoreProductPricingModel? storeProduct;

      if (primaryPlan != null) {
        try {
          storeProduct = await _billingClient.querySubscriptionProduct(
            primaryPlan.googlePlayProductId,
          );
        } catch (_) {
          storeProduct = null;
        }
      }

      final resolvedPhase = _resolveUiPhase(
        entitlement: overview.entitlement,
        currentSub: overview.currentSubscription,
        storeProduct: storeProduct,
      );

      state = state.copyWith(
        isLoading: false,
        uiPhase: resolvedPhase,
        entitlement: overview.entitlement,
        currentSubscription: overview.currentSubscription,
        activePlan: primaryPlan,
        storePricing: storeProduct,
        history: history,
        googlePlayManageUrl: overview.googlePlayManageUrl,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        uiPhase: SubscriptionUiPhase.purchaseFailure,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Refreshes only the backend entitlement state.
  Future<void> refreshEntitlementOnly() async {
    try {
      final overview = await _repository.fetchSubscriptionOverview();
      final history = await _repository.fetchSubscriptionHistory();

      final resolvedPhase = _resolveUiPhase(
        entitlement: overview.entitlement,
        currentSub: overview.currentSubscription,
        storeProduct: state.storePricing,
      );

      state = state.copyWith(
        isLoading: false,
        uiPhase: resolvedPhase,
        entitlement: overview.entitlement,
        currentSubscription: overview.currentSubscription,
        history: history,
        googlePlayManageUrl: overview.googlePlayManageUrl,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Initiates Google Play Billing purchase flow for the monthly subscription plan.
  /// Never activates subscription locally without server verification.
  Future<void> initiateGooglePlaySubscription({int? currentUserId}) async {
    final plan = state.activePlan;
    if (plan == null || state.storePricing == null) {
      state = state.copyWith(
        uiPhase: SubscriptionUiPhase.productUnavailable,
        errorMessage:
            'باقة الاشتراك الشهري غير متاحة حالياً في متجر Google Play. يرجى المحاولة لاحقاً.',
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      uiPhase: SubscriptionUiPhase.purchaseInProgress,
      clearError: true,
      statusBannerMessage: 'جارٍ فتح نافذة الاشتراك الرسمية في Google Play...',
    );

    try {
      final launched = await _billingClient.startSubscriptionPurchase(
        productId: plan.googlePlayProductId,
        obfuscatedAccountId: currentUserId?.toString(),
      );

      if (!launched) {
        state = state.copyWith(
          isLoading: false,
          uiPhase: SubscriptionUiPhase.purchaseFailure,
          errorMessage: 'تعذر بدء عملية الشراء عبر متجر Google Play.',
          clearBanner: true,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        uiPhase: SubscriptionUiPhase.purchaseFailure,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
        clearBanner: true,
      );
    }
  }

  /// Restores existing Google Play purchases and verifies them with Laravel.
  Future<void> restoreGooglePlayPurchases({int? currentUserId}) async {
    state = state.copyWith(
      isLoading: true,
      uiPhase: SubscriptionUiPhase.verificationPending,
      clearError: true,
      statusBannerMessage: 'جارٍ استعادة المشتريات والتحقق منها عبر الخادم...',
    );

    try {
      await _billingClient.restorePurchases(
        obfuscatedAccountId: currentUserId?.toString(),
      );
      await refreshEntitlementOnly();
      state = state.copyWith(
        isLoading: false,
        statusBannerMessage: 'تم تحديث حالة الاشتراك من متجر Google Play.',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        uiPhase: SubscriptionUiPhase.purchaseFailure,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        state = state.copyWith(
          isLoading: false,
          uiPhase: SubscriptionUiPhase.purchasePending,
          statusBannerMessage:
              'عملية الدفع قيد المعالجة لدى متجر Google Play. سيتم تفعيل الاشتراك فور تأكيد المتجر.',
          clearError: true,
        );
      } else if (purchase.status == PurchaseStatus.error) {
        state = state.copyWith(
          isLoading: false,
          uiPhase: SubscriptionUiPhase.purchaseFailure,
          errorMessage: purchase.error?.message.isNotEmpty == true
              ? purchase.error!.message
              : 'لم تكتمل عملية الاشتراك في Google Play.',
          clearBanner: true,
        );
      } else if (purchase.status == PurchaseStatus.canceled) {
        final fallbackPhase = _resolveUiPhase(
          entitlement: state.entitlement,
          currentSub: state.currentSubscription,
          storeProduct: state.storePricing,
        );
        state = state.copyWith(
          isLoading: false,
          uiPhase: fallbackPhase,
          statusBannerMessage: 'تم إلغاء نافذة الشراء قبل إتمام الدفع.',
        );
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Send purchaseToken to Laravel for official Google Play Developer API verification
        state = state.copyWith(
          isLoading: true,
          uiPhase: SubscriptionUiPhase.verificationPending,
          statusBannerMessage:
              'تم استلام عملية الشراء من Google Play، وجارٍ التحقق الرسمي عبر خادم نَصِيبُكَ...',
          clearError: true,
        );

        try {
          final verifiedOverview =
              await _verificationService.verifyWithBackend(
            productId: purchase.productID,
            purchaseToken: purchase.verificationData.serverVerificationData,
          );

          await _billingClient.completePurchaseIfNeeded(purchase);
          final history = await _repository.fetchSubscriptionHistory();

          final nextPhase = _resolveUiPhase(
            entitlement: verifiedOverview.entitlement,
            currentSub: verifiedOverview.currentSubscription,
            storeProduct: state.storePricing,
          );

          state = state.copyWith(
            isLoading: false,
            uiPhase: nextPhase,
            entitlement: verifiedOverview.entitlement,
            currentSubscription: verifiedOverview.currentSubscription,
            history: history,
            statusBannerMessage:
                verifiedOverview.entitlement.hasActiveSubscription
                    ? 'تم التحقق وتفعيل اشتراكك الشهري بنجاح.'
                    : 'تمت مزامنة حالة الاشتراك مع الخادم.',
          );
        } catch (e) {
          state = state.copyWith(
            isLoading: false,
            uiPhase: SubscriptionUiPhase.purchaseFailure,
            errorMessage: e.toString().replaceFirst('Exception: ', ''),
            clearBanner: true,
          );
        }
      }
    }
  }

  SubscriptionUiPhase _resolveUiPhase({
    required SubscriptionEntitlementModel entitlement,
    required SubscriptionRecordModel? currentSub,
    required StoreProductPricingModel? storeProduct,
  }) {
    if (entitlement.hasActiveSubscription) {
      if (entitlement.subscriptionStatus == 'cancelled') {
        return SubscriptionUiPhase.cancelledButValid;
      }
      return SubscriptionUiPhase.activeSubscription;
    }

    if (currentSub != null) {
      if (currentSub.status == 'pending') {
        return SubscriptionUiPhase.purchasePending;
      }
      if (currentSub.status == 'expired' ||
          currentSub.status == 'refunded' ||
          currentSub.status == 'revoked' ||
          currentSub.status == 'on_hold') {
        return SubscriptionUiPhase.expiredSubscription;
      }
    }

    if (storeProduct == null) {
      return SubscriptionUiPhase.productUnavailable;
    }

    return SubscriptionUiPhase.availablePlan;
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SubscriptionRepository(apiClient: apiClient);
});

final googlePlayBillingServiceProvider =
    Provider<GooglePlayBillingClientService>((ref) {
  return GooglePlayBillingClientService();
});

final purchaseVerificationServiceProvider =
    Provider<PurchaseVerificationService>((ref) {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return PurchaseVerificationService(repository: repo);
});

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  final repo = ref.watch(subscriptionRepositoryProvider);
  final billing = ref.watch(googlePlayBillingServiceProvider);
  final verifier = ref.watch(purchaseVerificationServiceProvider);
  return SubscriptionNotifier(
    repository: repo,
    billingClient: billing,
    verificationService: verifier,
  );
});
