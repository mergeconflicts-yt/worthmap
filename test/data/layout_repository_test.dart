import 'package:contour/data/db/db.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Vault vault;
  late DriftLayoutRepository repo;
  var nowMs = 1700000000000;

  setUp(() async {
    vault = await Vault.openInMemory(
      cipher: const UnverifiedOpenCipher(),
      keySource: () => 'ff' * 32,
      dbEpochFactory: () => '00000000-0000-7000-8000-000000000001',
    );
    repo = DriftLayoutRepository(
      db: vault.database,
      clockUtc: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
    );
  });

  tearDown(() async {
    await repo.dispose();
    await vault.close();
  });

  StoredSection section(String key, List<(String, String)> items) =>
      StoredSection(key: key, items: items);

  test('save and load round-trip sections and items', () async {
    final revision = await repo.save(
      surfaceKey: 'screen:home',
      catalogueVersion: 1,
      baseLayoutVersion: 1,
      sections: [
        section('favorites', [
          ('test.alpha', 'full'),
          ('test.beta', 'half'),
        ]),
        section('spending', [('test.gamma', 'full')]),
      ],
    );
    expect(revision, 1);

    final loaded = await repo.load('screen:home');
    expect(loaded, isNotNull);
    expect(loaded!.catalogueVersion, 1);
    expect(loaded.baseLayoutVersion, 1);
    expect(loaded.sections.map((s) => s.key), ['favorites', 'spending']);
    expect(loaded.sections.first.items, [
      ('test.alpha', 'full'),
      ('test.beta', 'half'),
    ]);
    expect(loaded.sections[1].items, [('test.gamma', 'full')]);

    final state = await vault.database
        .customSelect('SELECT read_revision FROM db_state')
        .getSingle();
    expect(state.data['read_revision'], 1);
  });

  test('positions are dense from zero per section (DB4-5)', () async {
    await repo.save(
      surfaceKey: 'screen:home',
      catalogueVersion: 1,
      baseLayoutVersion: 1,
      sections: [
        section('favorites', [('a', 'full'), ('b', 'half')]),
      ],
    );
    final positions = await vault.database
        .customSelect(
          'SELECT position, item_key FROM layout_items WHERE section_key = '
          "'favorites' ORDER BY position",
        )
        .get();
    expect(
      positions.map((r) => (r.data['position'], r.data['item_key'])),
      [(0, 'a'), (1, 'b')],
    );
  });

  test('an explicit empty surface keeps its row with no section (DB4-4)',
      () async {
    await repo.save(
      surfaceKey: 'screen:tax',
      catalogueVersion: 1,
      baseLayoutVersion: 1,
      sections: const [],
    );
    final loaded = await repo.load('screen:tax');
    expect(loaded, isNotNull);
    expect(loaded!.sections, isEmpty);

    // The row exists, so the surface does NOT inherit the default file.
    final rows = await vault.database
        .customSelect('SELECT count(*) AS n FROM layout_surfaces '
            "WHERE surface_key = 'screen:tax'")
        .getSingle();
    expect(rows.data['n'], 1);
  });

  test('an absent surface returns null (inherit the default)', () async {
    expect(await repo.load('screen:wealth'), isNull);
  });

  test('save replaces the previous patch with an explicit DELETE', () async {
    await repo.save(
      surfaceKey: 'screen:home',
      catalogueVersion: 1,
      baseLayoutVersion: 1,
      sections: [
        section('favorites', [('a', 'full')]),
      ],
    );
    await repo.save(
      surfaceKey: 'screen:home',
      catalogueVersion: 1,
      baseLayoutVersion: 1,
      sections: [
        section('spending', [('b', 'half')]),
      ],
    );
    final loaded = await repo.load('screen:home');
    expect(loaded!.sections.map((s) => s.key), ['spending']);
    final sections = await vault.database
        .customSelect('SELECT count(*) AS n FROM layout_sections')
        .getSingle();
    expect(sections.data['n'], 1);
  });

  test('clear removes the row; clearing an absent row writes nothing',
      () async {
    await repo.save(
      surfaceKey: 'screen:home',
      catalogueVersion: 1,
      baseLayoutVersion: 1,
      sections: [
        section('favorites', [('a', 'full')]),
      ],
    );
    final notifications = <String>[];
    final subscription = repo.changes.listen(notifications.add);
    await repo.clear('screen:home');
    await repo.clear('screen:home'); // absent: no write, no notify
    expect(await repo.load('screen:home'), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(notifications, ['screen:home']);
    await subscription.cancel();
  });

  test('an unknown surface key is rejected', () async {
    await expectLater(
      repo.save(
        surfaceKey: 'screen:unknown',
        catalogueVersion: 1,
        baseLayoutVersion: 1,
        sections: const [],
      ),
      throwsA(
        isA<LayoutStoreError>().having(
          (e) => e.code,
          'code',
          LayoutStoreErrorCode.unknownSurface,
        ),
      ),
    );
  });

  test('a case variant of untitled is rejected (DB4-7)', () async {
    for (final key in const ['Untitled', 'UNTITLED', 'untitled ']) {
      await expectLater(
        repo.save(
          surfaceKey: 'screen:home',
          catalogueVersion: 1,
          baseLayoutVersion: 1,
          sections: [section(key, const [])],
        ),
        throwsA(
          isA<LayoutStoreError>().having(
            (e) => e.code,
            'code',
            LayoutStoreErrorCode.badSectionKey,
          ),
        ),
      );
    }
  });

  test('section keys sort before untitled or equal it (table rule)', () async {
    // The table CHECK admits only the exact reserved key or keys whose
    // lowercase sorts strictly before 'untitled'. The writer mirrors it.
    await repo.save(
      surfaceKey: 'screen:home',
      catalogueVersion: 1,
      baseLayoutVersion: 1,
      sections: [
        section('quickActions', [('a', 'full')]),
      ],
    );
    await expectLater(
      repo.save(
        surfaceKey: 'screen:home',
        catalogueVersion: 1,
        baseLayoutVersion: 1,
        sections: [
          section('zeta', [('a', 'full')]),
        ],
      ),
      throwsA(
        isA<LayoutStoreError>().having(
          (e) => e.code,
          'code',
          LayoutStoreErrorCode.badSectionKey,
        ),
      ),
    );
  });

  test('the tile surface admits only untitled sections and full sizes',
      () async {
    await expectLater(
      repo.save(
        surfaceKey: 'tiles:quickLook',
        catalogueVersion: 1,
        baseLayoutVersion: 1,
        sections: [section('favorites', const [])],
      ),
      throwsA(
        isA<LayoutStoreError>().having(
          (e) => e.code,
          'code',
          LayoutStoreErrorCode.tileSurfaceRule,
        ),
      ),
    );
    await expectLater(
      repo.save(
        surfaceKey: 'tiles:quickLook',
        catalogueVersion: 1,
        baseLayoutVersion: 1,
        sections: [
          section('untitled', [('tile.a', 'half')]),
        ],
      ),
      throwsA(
        isA<LayoutStoreError>().having(
          (e) => e.code,
          'code',
          LayoutStoreErrorCode.tileSurfaceRule,
        ),
      ),
    );
  });

  test('a duplicate item key on one surface is rejected', () async {
    await expectLater(
      repo.save(
        surfaceKey: 'screen:home',
        catalogueVersion: 1,
        baseLayoutVersion: 1,
        sections: [
          section('favorites', [('a', 'full')]),
          section('spending', [('a', 'full')]),
        ],
      ),
      throwsA(
        isA<LayoutStoreError>().having(
          (e) => e.code,
          'code',
          LayoutStoreErrorCode.duplicateItem,
        ),
      ),
    );
  });

  test('the count limits are enforced independently', () async {
    final sections = List.generate(
      17,
      (i) => section('sec$i', const <(String, String)>[]),
    );
    await expectLater(
      repo.save(
        surfaceKey: 'screen:home',
        catalogueVersion: 1,
        baseLayoutVersion: 1,
        sections: sections,
      ),
      throwsA(
        isA<LayoutStoreError>().having(
          (e) => e.code,
          'code',
          LayoutStoreErrorCode.sectionLimit,
        ),
      ),
    );

    final items = List.generate(
      257,
      (i) => ('item$i', 'full'),
    );
    await expectLater(
      repo.save(
        surfaceKey: 'screen:home',
        catalogueVersion: 1,
        baseLayoutVersion: 1,
        sections: [section('untitled', items)],
      ),
      throwsA(
        isA<LayoutStoreError>().having(
          (e) => e.code,
          'code',
          LayoutStoreErrorCode.itemLimit,
        ),
      ),
    );
  });

  test('the 64 KiB canonical byte bound is enforced (DB4-6)', () async {
    // Retained keys may hold any 64 Unicode characters, so a descriptor can
    // exceed the bound while staying inside the count limits. Multi-byte
    // characters reach the 65,536-byte bound with 256 items.
    String key(int index) =>
        '\u{1F600}' * 63 + String.fromCharCode(0x21 + index);
    final items = List.generate(256, (i) => (key(i), 'full'));
    await expectLater(
      repo.save(
        surfaceKey: 'screen:home',
        catalogueVersion: 1,
        baseLayoutVersion: 1,
        sections: [section('untitled', items)],
      ),
      throwsA(
        isA<LayoutStoreError>().having(
          (e) => e.code,
          'code',
          LayoutStoreErrorCode.byteBound,
        ),
      ),
    );
  });

  test('the no-replace triggers abort a conflicting insert', () async {
    await repo.save(
      surfaceKey: 'screen:home',
      catalogueVersion: 1,
      baseLayoutVersion: 1,
      sections: [
        section('favorites', [('a', 'full')]),
      ],
    );
    await expectLater(
      vault.database.customStatement(
        'INSERT INTO layout_surfaces (surface_key, catalogue_version, '
        'base_layout_version, updated_at) '
        "VALUES ('screen:home', 1, 1, 0)",
      ),
      throwsA(isA<Exception>()),
    );
    // The stored row is untouched (no replacement happened).
    final loaded = await repo.load('screen:home');
    expect(loaded!.sections.first.items, [('a', 'full')]);
  });

  test('reads accept position gaps and sort by position', () async {
    await repo.save(
      surfaceKey: 'screen:home',
      catalogueVersion: 1,
      baseLayoutVersion: 1,
      sections: [
        section('favorites', [('a', 'full'), ('b', 'half'), ('c', 'full')]),
      ],
    );
    // Simulate an old stored form with a gap (the writer writes densely).
    await vault.database.customStatement(
      "UPDATE layout_items SET position = 5 WHERE item_key = 'c'",
    );
    final loaded = await repo.load('screen:home');
    expect(
      loaded!.sections.first.items,
      [
        ('a', 'full'),
        ('b', 'half'),
        ('c', 'full'),
      ],
    );
  });
}
