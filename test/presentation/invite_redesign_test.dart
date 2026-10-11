import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/data/remote/shared_lists_repository.dart';
import 'package:lista_compras_material/src/presentation/shared_lists_pages.dart';
import 'package:lista_compras_material/src/presentation/theme/editorial_workspace_theme.dart';

void main() {
  setUpAll(() async {
    for (final font in {
      'MercadoPublicSans': 'assets/fonts/PublicSans.ttf',
      'MercadoNewsreader': 'assets/fonts/Newsreader.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  testWidgets('invite mobile visual reference uses actual code and members', (
    tester,
  ) async {
    await _open(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/invite_stitch_390.png'),
    );
    expect(find.text('Você (dono)'), findsOneWidget);
    expect(find.text('MC-7829-CASA'), findsOneWidget);
    expect(find.textContaining('Expira'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'owner copies regenerates revokes and generates actual repository code',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final repo = await _open(tester);
      await tester.tap(find.text('Copiar'));
      await tester.pumpAndSettle();
      expect(copied, 'MC-7829-CASA');
      await tester.tap(find.text('Regenerar'));
      await tester.pumpAndSettle();
      expect(repo.generated, 1);
      expect(find.text('MC-9000-CASA'), findsOneWidget);
      await tester.tap(find.text('Revogar'));
      await tester.pumpAndSettle();
      expect(repo.revoked, 1);
      expect(find.text('Nenhum código ativo'), findsOneWidget);
      expect(find.text('Regenerar'), findsNothing);
      await tester.tap(find.text('Gerar código'));
      await tester.pumpAndSettle();
      expect(repo.generated, 2);
    },
  );

  testWidgets('owner confirms member removal and cannot remove owner', (
    tester,
  ) async {
    final repo = await _open(tester);
    expect(find.text('Remover membro'), findsNWidgets(2));
    await tester.tap(find.text('Remover membro').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repo.removed, isNull);
    await tester.tap(find.text('Remover membro').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();
    expect(repo.removed, 'member4102f');
    expect(find.text('Remover membro'), findsOneWidget);
  });

  testWidgets(
    'member permissions remain read only, closed list keeps existing invitation policy',
    (tester) async {
      await _open(tester, uid: 'member9014d', closed: true);
      expect(find.text('Copiar'), findsOneWidget);
      expect(find.text('Regenerar'), findsNothing);
      expect(find.text('Revogar'), findsNothing);
      expect(find.text('Remover membro'), findsNothing);
      expect(find.text('Você (membro)'), findsOneWidget);
      expect(
        find.text('Somente o dono pode gerenciar o código.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('open shared list closes sheet and calls existing callback', (
    tester,
  ) async {
    var opened = false;
    await _open(tester, onOpen: () async => opened = true);
    await tester.tap(find.text('Abrir lista compartilhada'));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
    expect(find.text('Convidar para lista'), findsNothing);
  });

  testWidgets(
    'compact dark enlarged text remains scrollable without overflow',
    (tester) async {
      await _open(tester, size: const Size(320, 568), dark: true, scale: 1.5);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Abrir lista compartilhada'), findsOneWidget);
    },
  );

  testWidgets(
    'stream failure and missing list remain recoverable by closing sheet',
    (tester) async {
      final repo = await _open(tester);
      repo.updates.addError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Não foi possível carregar o compartilhamento.'),
        findsOneWidget,
      );
      repo.updates.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Lista compartilhada não encontrada.'), findsOneWidget);
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(find.text('Convidar para lista'), findsNothing);
    },
  );
}

Future<_Repository> _open(
  WidgetTester tester, {
  String uid = 'owner7c3b1',
  bool closed = false,
  bool dark = false,
  double scale = 1,
  Size size = const Size(390, 884),
  Future<void> Function()? onOpen,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final repo = _Repository(closed: closed);
  addTearDown(repo.updates.close);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: editorialWorkspaceTheme(
        ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showSharedInviteSheet(
                context: context,
                repository: repo,
                listId: 'shared',
                currentUid: uid,
                onOpenSharedList: onOpen ?? () async {},
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pump(const Duration(milliseconds: 500));
  repo.updates.add(repo.list);
  await tester.pumpAndSettle();
  return repo;
}

class _Repository implements SharedListsRepository {
  _Repository({bool closed = false})
    : list = SharedShoppingListSummary(
        id: 'shared',
        name: 'Compras da semana',
        ownerUid: 'owner7c3b1',
        memberUids: ['owner7c3b1', 'member9014d', 'member4102f'],
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 10),
        inviteCode: 'MC-7829-CASA',
        isClosed: closed,
      );
  SharedShoppingListSummary list;
  final updates = StreamController<SharedShoppingListSummary?>.broadcast();
  int generated = 0;
  int revoked = 0;
  String? removed;
  @override
  Stream<SharedShoppingListSummary?> watchSharedList(String id) =>
      updates.stream;
  @override
  Future<String> generateInviteCode({
    required String listId,
    required String requesterUid,
  }) async {
    expect(listId, 'shared');
    expect(requesterUid, list.ownerUid);
    generated++;
    list = list.copyWith(inviteCode: 'MC-9000-CASA');
    updates.add(list);
    return 'MC-9000-CASA';
  }

  @override
  Future<void> revokeInviteCode({
    required String listId,
    required String requesterUid,
  }) async {
    revoked++;
    list = list.copyWith(clearInviteCode: true);
    updates.add(list);
  }

  @override
  Future<void> removeMember({
    required String listId,
    required String requesterUid,
    required String memberUid,
  }) async {
    removed = memberUid;
    list = list.copyWith(
      memberUids: list.memberUids.where((uid) => uid != memberUid).toList(),
    );
    updates.add(list);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
