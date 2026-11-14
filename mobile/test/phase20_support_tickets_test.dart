import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naseebak_mobile/core/design_system/naseebak_design_system.dart';
import 'package:naseebak_mobile/features/auth/data/auth_user_model.dart';
import 'package:naseebak_mobile/features/auth/data/google_auth_repository.dart';
import 'package:naseebak_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:naseebak_mobile/features/notifications/data/services/notification_navigation_service.dart';
import 'package:naseebak_mobile/features/profile/domain/profile_registration_draft.dart';
import 'package:naseebak_mobile/features/profile/presentation/providers/profile_management_provider.dart';
import 'package:naseebak_mobile/features/profile/presentation/screens/my_profile_screen.dart';
import 'package:naseebak_mobile/features/support/data/models/support_ticket_model.dart';
import 'package:naseebak_mobile/features/support/data/repositories/support_repository.dart';
import 'package:naseebak_mobile/features/support/presentation/screens/create_support_ticket_screen.dart';
import 'package:naseebak_mobile/features/support/presentation/screens/support_ticket_detail_screen.dart';
import 'package:naseebak_mobile/features/support/presentation/screens/support_tickets_screen.dart';

class _FakeGoogleAuthRepo extends Fake implements GoogleAuthRepository {
  static const _member = AuthUserModel(
    id: 1,
    email: 'member@example.com',
    accountStatus: 'active',
    profileCompleted: true,
    hasActiveSubscription: false,
  );

  @override
  Future<AuthUserModel?> readCachedSessionUser() async => _member;

  @override
  Future<AuthUserModel?> restoreSession() async => _member;
}

class FakeSupportRepo extends Fake implements SupportRepository {
  final List<SupportTicketModel> tickets;
  bool shouldFailFetch = false;

  FakeSupportRepo({List<SupportTicketModel>? initialTickets})
      : tickets = initialTickets != null ? [...initialTickets] : <SupportTicketModel>[];

  @override
  Future<PaginatedSupportTicketsResponse> fetchTickets({
    int page = 1,
    int perPage = 20,
    String? type,
    String? status,
  }) async {
    if (shouldFailFetch) {
      throw Exception('تعذر الاتصال بالخادم');
    }

    var filtered = [...tickets];
    if (type != null && type.isNotEmpty) {
      filtered = filtered.where((t) => t.type == type).toList();
    }
    if (status != null && status.isNotEmpty) {
      filtered = filtered.where((t) => t.status == status).toList();
    }

    return PaginatedSupportTicketsResponse(
      tickets: filtered,
      currentPage: 1,
      lastPage: 1,
      perPage: perPage,
      total: filtered.length,
    );
  }

  @override
  Future<SupportTicketSubmitResult> createTicket({
    required String type,
    required String category,
    required String subject,
    required String message,
  }) async {
    final created = SupportTicketModel(
      id: 100 + tickets.length + 1,
      ticketNumber: 'NSB-2611-00${100 + tickets.length + 1}',
      type: type,
      typeLabel: SupportTicketModel.defaultTypeLabel(type),
      category: category,
      categoryLabel: SupportTicketModel.defaultCategoryLabel(category),
      subject: subject,
      message: message,
      status: 'open',
      statusLabel: SupportTicketModel.defaultStatusLabel('open'),
      lastSenderType: 'member',
      repliesCount: 0,
      createdAt: '2026-11-14T10:00:00Z',
      lastActivityAt: '2026-11-14T10:00:00Z',
    );
    tickets.insert(0, created);
    return SupportTicketSubmitResult(
      ticket: created,
      message: 'تم إرسال طلبك إلى إدارة نَصِيبُكَ بنجاح.',
    );
  }

  @override
  Future<SupportTicketModel> fetchTicketDetail(int ticketId) async {
    return tickets.firstWhere((t) => t.id == ticketId);
  }

  @override
  Future<SupportTicketModel> sendMemberReply({
    required int ticketId,
    required String body,
  }) async {
    final index = tickets.indexWhere((t) => t.id == ticketId);
    final existing = tickets[index];
    final reply = SupportTicketReplyModel(
      id: existing.replies.length + 10,
      senderType: 'member',
      senderName: 'سارة محمد',
      body: body,
      createdAt: '2026-11-14T11:30:00Z',
    );
    final updated = SupportTicketModel(
      id: existing.id,
      ticketNumber: existing.ticketNumber,
      type: existing.type,
      typeLabel: existing.typeLabel,
      category: existing.category,
      categoryLabel: existing.categoryLabel,
      subject: existing.subject,
      message: existing.message,
      status: existing.status == 'answered' ? 'in_progress' : existing.status,
      statusLabel: SupportTicketModel.defaultStatusLabel(
        existing.status == 'answered' ? 'in_progress' : existing.status,
      ),
      adminReply: existing.adminReply,
      respondedAt: existing.respondedAt,
      lastActivityAt: '2026-11-14T11:30:00Z',
      lastSenderType: 'member',
      repliesCount: existing.replies.length + 1,
      closedAt: existing.closedAt,
      createdAt: existing.createdAt,
      replies: [...existing.replies, reply],
    );
    tickets[index] = updated;
    return updated;
  }
}

Widget _wrapSupportApp(
  Widget child, {
  required FakeSupportRepo repo,
  Size? screenSize,
}) {
  Widget app = ProviderScope(
    overrides: [
      supportRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: child,
    ),
  );

  if (screenSize != null) {
    app = MediaQuery(
      data: MediaQueryData(size: screenSize),
      child: app,
    );
  }
  return app;
}

SupportTicketModel _sampleAnsweredInquiry() {
  return const SupportTicketModel(
    id: 501,
    ticketNumber: 'NSB-2611-00501',
    type: 'inquiry',
    typeLabel: 'استفسار',
    category: 'account',
    categoryLabel: 'الحساب والملف الشخصي',
    subject: 'توثيق بيانات الحساب الشخصي',
    message: 'السلام عليكم، كيف أتابع حالة مراجعة ملفي الشخصي؟',
    status: 'answered',
    statusLabel: 'تم الرد',
    adminReply: 'وعليكم السلام، تتم مراجعة جميع الملفات خلال 24 ساعة.',
    respondedAt: '2026-11-14T09:15:00Z',
    lastActivityAt: '2026-11-14T09:15:00Z',
    lastSenderType: 'admin',
    repliesCount: 1,
    createdAt: '2026-11-14T08:00:00Z',
    replies: [
      SupportTicketReplyModel(
        id: 1,
        senderType: 'admin',
        senderName: 'إدارة نَصِيبُكَ',
        body: 'وعليكم السلام، تتم مراجعة جميع الملفات خلال 24 ساعة.',
        createdAt: '2026-11-14T09:15:00Z',
      ),
    ],
  );
}

SupportTicketModel _sampleClosedComplaint() {
  return const SupportTicketModel(
    id: 502,
    ticketNumber: 'NSB-2611-00502',
    type: 'complaint',
    typeLabel: 'شكوى',
    category: 'technical',
    categoryLabel: 'مشكلة تقنية',
    subject: 'بطء تحميل صفحة الإشعارات',
    message: 'تواجهني مشكلة بطء مؤقتة عند فتح صفحة الإشعارات.',
    status: 'closed',
    statusLabel: 'مغلق',
    adminReply: 'تم تحديث الخادم ومعالجة المشكلة بالكامل.',
    respondedAt: '2026-11-13T18:00:00Z',
    lastActivityAt: '2026-11-13T18:00:00Z',
    lastSenderType: 'admin',
    repliesCount: 1,
    closedAt: '2026-11-13T18:00:00Z',
    createdAt: '2026-11-13T14:00:00Z',
    replies: [
      SupportTicketReplyModel(
        id: 2,
        senderType: 'admin',
        senderName: 'إدارة نَصِيبُكَ',
        body: 'تم تحديث الخادم ومعالجة المشكلة بالكامل.',
        createdAt: '2026-11-13T18:00:00Z',
      ),
    ],
  );
}

void main() {
  group('Phase 20 — Inquiries & Complaints Support Feature Tests', () {
    testWidgets('1. Empty state and filtering inquiries vs complaints work cleanly',
        (tester) async {
      final repo = FakeSupportRepo(
        initialTickets: [
          _sampleAnsweredInquiry(),
          _sampleClosedComplaint(),
        ],
      );

      await tester.pumpWidget(
        _wrapSupportApp(const SupportTicketsScreen(), repo: repo),
      );
      await tester.pumpAndSettle();

      expect(find.text('NSB-2611-00501'), findsOneWidget);
      expect(find.text('NSB-2611-00502'), findsOneWidget);

      await tester.tap(find.byKey(const Key('filter_support_inquiry')));
      await tester.pumpAndSettle();
      expect(find.text('NSB-2611-00501'), findsOneWidget);
      expect(find.text('NSB-2611-00502'), findsNothing);

      await tester.tap(find.byKey(const Key('filter_support_complaint')));
      await tester.pumpAndSettle();
      expect(find.text('NSB-2611-00501'), findsNothing);
      expect(find.text('NSB-2611-00502'), findsOneWidget);
    });

    testWidgets('2. Empty list displays Arabic onboarding empty state',
        (tester) async {
      final repo = FakeSupportRepo();

      await tester.pumpWidget(
        _wrapSupportApp(const SupportTicketsScreen(), repo: repo),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا توجد استفسارات أو شكاوى بعد'), findsOneWidget);
      expect(find.byKey(const Key('btn_new_support_ticket')), findsOneWidget);
    });

    testWidgets('3. Creating a complaint validates inputs and opens detail screen',
        (tester) async {
      final repo = FakeSupportRepo();

      await tester.pumpWidget(
        _wrapSupportApp(const SupportTicketsScreen(), repo: repo),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_new_support_ticket')));
      await tester.pumpAndSettle();

      expect(find.text('إرسال استفسار أو شكوى'), findsOneWidget);

      // Select complaint type
      await tester.tap(find.byKey(const Key('type_complaint_btn')));
      await tester.pumpAndSettle();

      // Enter valid subject & message
      await tester.enterText(
        find.byKey(const Key('support_subject_field')),
        'شكوى بخصوص توثيق الحساب',
      );
      await tester.enterText(
        find.byKey(const Key('support_message_field')),
        'السلام عليكم، أرجو مراجعة الشكوى الخاصة بحسابي والتكرم بالرد.',
      );

      await tester.ensureVisible(find.byKey(const Key('btn_submit_support_ticket')));
      await tester.tap(find.byKey(const Key('btn_submit_support_ticket')));
      await tester.pumpAndSettle();

      expect(find.byType(SupportTicketDetailScreen), findsOneWidget);
      expect(find.text('شكوى بخصوص توثيق الحساب'), findsWidgets);
      expect(repo.tickets.length, 1);
      expect(repo.tickets.first.type, 'complaint');
    });

    testWidgets('4. Ticket detail shows admin reply and allows follow-up; closed blocks input',
        (tester) async {
      final repo = FakeSupportRepo(
        initialTickets: [_sampleAnsweredInquiry(), _sampleClosedComplaint()],
      );

      await tester.pumpWidget(
        _wrapSupportApp(
          SupportTicketDetailScreen(
            ticketId: 501,
            initialTicket: _sampleAnsweredInquiry(),
          ),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('إدارة نَصِيبُكَ'), findsOneWidget);
      expect(
        find.textContaining('تتم مراجعة جميع الملفات خلال 24 ساعة'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('support_reply_field')),
        'شكرًا لكم، متى يصل إشعار الاعتماد؟',
      );
      await tester.tap(find.byKey(const Key('btn_send_support_reply')));
      await tester.pumpAndSettle();

      expect(find.text('شكرًا لكم، متى يصل إشعار الاعتماد؟'), findsOneWidget);

      // Closed ticket test
      await tester.pumpWidget(
        _wrapSupportApp(
          SupportTicketDetailScreen(
            ticketId: 502,
            initialTicket: _sampleClosedComplaint(),
          ),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('support_reply_field')), findsNothing);
      expect(
        find.text('تم إغلاق هذا الطلب ولا يمكن إضافة ردود جديدة عليه.'),
        findsOneWidget,
      );
    });

    testWidgets('5. Responsive layout on 360px mobile viewport causes zero overflow errors',
        (tester) async {
      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);
      addTearDown(() => FlutterError.onError = originalOnError);

      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = FakeSupportRepo(
        initialTickets: [_sampleAnsweredInquiry(), _sampleClosedComplaint()],
      );

      await tester.pumpWidget(
        _wrapSupportApp(const SupportTicketsScreen(), repo: repo),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _wrapSupportApp(const CreateSupportTicketScreen(), repo: repo),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _wrapSupportApp(
          SupportTicketDetailScreen(
            ticketId: 501,
            initialTicket: _sampleAnsweredInquiry(),
          ),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(errors, isEmpty);
    });

    testWidgets('6. Notification deep link support_ticket navigates cleanly',
        (tester) async {
      final repo = FakeSupportRepo(
        initialTickets: [_sampleAnsweredInquiry()],
      );
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            googleAuthRepositoryProvider.overrideWithValue(_FakeGoogleAuthRepo()),
            supportRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            navigatorKey: navKey,
            home: Consumer(
              builder: (context, ref, _) {
                ref.watch(authControllerProvider);
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      ref
                          .read(notificationNavigationServiceProvider)
                          .handleNotificationNavigation(
                            context: context,
                            actionRoute: 'support_ticket',
                            routingMetadata: const {'ticket_id': 501},
                            fallbackReferenceId: 501,
                          );
                    },
                    child: const Text('open'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(SupportTicketDetailScreen), findsOneWidget);
      expect(find.text('NSB-2611-00501'), findsOneWidget);
    });

    testWidgets('7. MyProfileScreen displays Inquiries & Complaints button and opens SupportTicketsScreen',
        (tester) async {
      final repo = FakeSupportRepo(initialTickets: [_sampleAnsweredInquiry()]);
      final container = ProviderContainer(
        overrides: [
          supportRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      container.read(profileManagementProvider.notifier).syncFromRegistrationDraft(
            ProfileRegistrationDraft(
              fullName: 'سارة محمد',
              gender: 'female',
              dateOfBirth: DateTime(1992, 6, 15),
              maritalStatus: 'single',
              previouslyMarried: false,
              hasChildren: false,
              educationLevel: 'bachelor',
              occupation: 'مهندسة معمارية',
              heightCm: 165,
              smokingStatus: 'non_smoker',
              homeOwnership: 'owned',
              hobbies: const ['القراءة'],
              nationality: 'مصرية',
              countryOfResidence: 'مصر',
              region: 'القاهرة',
              bio: 'أبحث عن شريك جاد لبناء حياة مستقرة.',
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: MaterialApp(
              home: MyProfileScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final supportBtn = find.byKey(const Key('open_support_tickets_btn'));
      await tester.ensureVisible(supportBtn);
      expect(supportBtn, findsOneWidget);
      expect(find.text('الاستفسارات والشكاوى'), findsOneWidget);

      await tester.tap(supportBtn);
      await tester.pumpAndSettle();

      expect(find.byType(SupportTicketsScreen), findsOneWidget);
      expect(find.text('NSB-2611-00501'), findsOneWidget);
    });
  });
}
