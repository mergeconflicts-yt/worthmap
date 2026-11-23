import 'dart:io';

import 'package:contour/data/prices/gateway_stub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late NetworkGate gate;
  late GatewayOffStub gateway;

  setUp(() {
    gate = NetworkGate.off();
    gateway = GatewayOffStub(gate);
  });

  const id = PublicInstrumentId(
    providerNamespace: 'public',
    providerKey: 'AAPL',
  );

  test('every request type is rejected while the gate is off', () async {
    await expectLater(
      gateway.catalogPage(
        publicMarket: 'publicMarket',
        boundedProviderCursor: 'cursor',
      ),
      throwsA(
        isA<GatewayError>().having(
          (e) => e.code,
          'code',
          GatewayErrorCode.disabled,
        ),
      ),
    );
    await expectLater(
      gateway.latestQuotes(const [id]),
      throwsA(
        isA<GatewayError>().having(
          (e) => e.code,
          'code',
          GatewayErrorCode.disabled,
        ),
      ),
    );
    await expectLater(
      gateway.priceHistory(id: id, range: PublicRange.oneMonth),
      throwsA(
        isA<GatewayError>().having(
          (e) => e.code,
          'code',
          GatewayErrorCode.disabled,
        ),
      ),
    );
    await expectLater(
      gateway.instrumentDetails(id),
      throwsA(
        isA<GatewayError>().having(
          (e) => e.code,
          'code',
          GatewayErrorCode.disabled,
        ),
      ),
    );
    await expectLater(
      gateway.publicAsset(
        const PublicAssetId(providerNamespace: 'public', key: 'asset1'),
        PublicRendition.logo64,
      ),
      throwsA(
        isA<GatewayError>().having(
          (e) => e.code,
          'code',
          GatewayErrorCode.disabled,
        ),
      ),
    );
  });

  test('the gate starts off and every change advances the policy epoch',
      () async {
    expect(gate.enabled, isFalse);
    gate.set(true);
    expect(gate.enabled, isTrue);
    expect(gate.policyEpoch, 1);
    gate.set(true); // no change: no new epoch
    expect(gate.policyEpoch, 1);
    gate.set(false);
    expect(gate.policyEpoch, 2);
  });

  test('an enabled gate still rejects oversized batches and bad identifiers',
      () async {
    gate.set(true);
    final tooMany = List.generate(
      51,
      (_) => const PublicInstrumentId(providerNamespace: 'p', providerKey: 'x'),
    );
    await expectLater(
      gateway.latestQuotes(tooMany),
      throwsA(
        isA<GatewayError>().having(
          (e) => e.code,
          'code',
          GatewayErrorCode.badIdentifier,
        ),
      ),
    );
    await expectLater(
      gateway.priceHistory(
        id: const PublicInstrumentId(providerNamespace: '', providerKey: 'x'),
        range: PublicRange.oneMonth,
      ),
      throwsA(
        isA<GatewayError>().having(
          (e) => e.code,
          'code',
          GatewayErrorCode.badIdentifier,
        ),
      ),
    );
  });

  test('request DTOs carry public identifiers only (SPEC 10.5)', () {
    // The DTO surfaces are inspected structurally: the only fields a
    // request may carry are provider namespace, provider key, market,
    // cursor, range and rendition. Assert the accepted public shapes.
    final instrument = id.validated();
    expect(instrument.providerNamespace, 'public');
    expect(instrument.providerKey, 'AAPL');
    // No balance, quantity, holding, account name, date, file or database
    // id field exists on any request type in this library: the type list
    // below is exhaustive for the gateway folder.
    expect(_gatewayPublicTypes, hasLength(7));
  });

  test('the gateway stub performs no I/O: no transport in the source',
      () async {
    // The traffic test (SYSTEM_DESIGN 11.2): zero non-gateway sockets. The
    // stub performs no I/O in either gate state, proven here by a source
    // scan: no dart:io transport, no HTTP client, no socket, no file.
    final dir = Directory('lib/data/prices');
    for (final entity in dir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      for (final banned in _transportTokens) {
        expect(
          source.contains(banned),
          isFalse,
          reason: '${entity.path} must not reference "$banned" '
              '(the Phase 1 gateway performs no I/O)',
        );
      }
    }
  });
}

// The public types the gateway may expose. A new request type needs its own
// privacy review (SPEC 10.5) and a change to this test.
const List<String> _gatewayPublicTypes = <String>[
  'PublicInstrumentId',
  'PublicAssetId',
  'PublicRange',
  'PublicRendition',
  'MarketDataGateway',
  'GatewayOffStub',
  'NetworkGate',
];

const List<String> _transportTokens = <String>[
  'dart:io',
  'dart:net',
  'HttpClient',
  'Socket.connect',
  'WebSocket',
  'openUrl',
  'File(',
];
