// T11 (SPEC 10.5, 11; SYSTEM_DESIGN 11): the restricted market-data gateway
// stub, off by default.
//
// The stub implements the allowed request contract (SYSTEM_DESIGN 11.1) and
// rejects every request while the network gate is off. It performs no I/O:
// no socket, no HTTP client, no file access. Production adapters land only
// behind an explicitly enabled public provider (SPEC 10.5).
//
// Privacy invariants:
//   - request DTOs carry public identifiers only: provider namespace,
//     exchange, symbol or provider id, range and rendition;
//   - no balances, quantities, holdings, account names, transaction dates,
//     files, transcripts or database ids ever enter a request (SPEC 10.5);
//   - no remote FX, email, arbitrary URLs or exports exist.
library;

/// The network gate. Off by default (SPEC 10.5); only the explicit Settings
/// action for a public provider can turn it on, and lock/background stops
/// new fetches (SYSTEM_DESIGN 11.2).
final class NetworkGate {
  NetworkGate({required this.enabled});

  /// The gate starts off.
  NetworkGate.off() : enabled = false;

  bool enabled;

  int policyEpoch = 0;

  /// Turning the gate on or off advances the policy epoch (SYSTEM_DESIGN
  /// 11.2: network off increments the epoch and rejects late responses).
  void set(bool value) {
    if (enabled == value) {
      return;
    }
    enabled = value;
    policyEpoch++;
  }
}

/// Typed, safe gateway failure codes.
enum GatewayErrorCode {
  disabled,
  badIdentifier,
}

class GatewayError implements Exception {
  const GatewayError(this.code);

  final GatewayErrorCode code;

  @override
  String toString() => 'GatewayError(${code.name})';
}

/// A validated public instrument id: provider namespace plus a bounded
/// provider key. No other field is ever requestable.
final class PublicInstrumentId {
  const PublicInstrumentId({
    required this.providerNamespace,
    required this.providerKey,
  });

  final String providerNamespace;
  final String providerKey;

  PublicInstrumentId validated() {
    if (providerNamespace.isEmpty || providerNamespace.length > 128) {
      throw const GatewayError(GatewayErrorCode.badIdentifier);
    }
    if (providerKey.isEmpty || providerKey.length > 256) {
      throw const GatewayError(GatewayErrorCode.badIdentifier);
    }
    return this;
  }

  @override
  String toString() =>
      'PublicInstrumentId($providerNamespace/…)'; // never the raw key
}

/// A validated public asset id for the logo request.
final class PublicAssetId {
  const PublicAssetId({required this.providerNamespace, required this.key});

  final String providerNamespace;
  final String key;
}

/// The bounded history ranges (SYSTEM_DESIGN 11.1).
enum PublicRange { oneMonth, oneYear, fiveYears, tenYears, allAvailable }

/// The logo renditions.
enum PublicRendition { logo64, logo128, logo256 }

/// The allowed request contract (SYSTEM_DESIGN 11.1). Every method returns
/// a typed rejection while the gate is off; the stub never opens any
/// transport.
abstract interface class MarketDataGateway {
  Future<void> catalogPage({
    required String publicMarket,
    required String boundedProviderCursor,
  });

  Future<void> latestQuotes(List<PublicInstrumentId> ids);

  Future<void> priceHistory({
    required PublicInstrumentId id,
    required PublicRange range,
  });

  Future<void> instrumentDetails(PublicInstrumentId id);

  Future<void> publicAsset(PublicAssetId id, PublicRendition rendition);
}

/// The Phase 1 stub. Off by default; rejects every request with
/// [GatewayErrorCode.disabled] while the gate is off, validates identifiers
/// before anything else, and performs no I/O in either state.
final class GatewayOffStub implements MarketDataGateway {
  GatewayOffStub(this.gate);

  final NetworkGate gate;

  void _check(PublicInstrumentId? id) {
    if (!gate.enabled) {
      throw const GatewayError(GatewayErrorCode.disabled);
    }
    id?.validated();
  }

  @override
  Future<void> catalogPage({
    required String publicMarket,
    required String boundedProviderCursor,
  }) async {
    if (!gate.enabled) {
      throw const GatewayError(GatewayErrorCode.disabled);
    }
  }

  @override
  Future<void> latestQuotes(List<PublicInstrumentId> ids) async {
    if (ids.length > 50) {
      // SYSTEM_DESIGN 11.1: max 50 symbols per latest-price batch.
      throw const GatewayError(GatewayErrorCode.badIdentifier);
    }
    _check(ids.isEmpty ? null : ids.first);
    for (final id in ids) {
      id.validated();
    }
  }

  @override
  Future<void> priceHistory({
    required PublicInstrumentId id,
    required PublicRange range,
  }) async {
    _check(id);
  }

  @override
  Future<void> instrumentDetails(PublicInstrumentId id) async {
    _check(id);
  }

  @override
  Future<void> publicAsset(PublicAssetId id, PublicRendition rendition) async {
    if (!gate.enabled) {
      throw const GatewayError(GatewayErrorCode.disabled);
    }
    if (id.providerNamespace.isEmpty || id.providerNamespace.length > 128) {
      throw const GatewayError(GatewayErrorCode.badIdentifier);
    }
    if (id.key.isEmpty || id.key.length > 128) {
      throw const GatewayError(GatewayErrorCode.badIdentifier);
    }
  }
}
