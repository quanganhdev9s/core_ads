import 'package:core_ads/core_ads.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paid event exposes Adjust-ready revenue metadata', () {
    const event = AdsPaidEvent(
      placement: AdPlacement(key: 'level_complete', type: AdType.rewarded),
      network: AdNetwork.google,
      adUnitId: 'ca-app-pub-test/rewarded',
      valueMicros: 1234560,
      currencyCode: 'USD',
      precision: 'precise',
      responseId: 'response-id',
      mediationAdapterClassName: 'adapter',
      adSourceName: 'ad-source',
      adSourceId: 'source-id',
      adSourceInstanceName: 'source-instance',
      adSourceInstanceId: 'source-instance-id',
    );

    expect(event.revenue, 1.23456);
    expect(event.value, event.revenue);
    expect(event.adUnitId, 'ca-app-pub-test/rewarded');
    expect(event.adSourceName, 'ad-source');
    expect(event.adSourceInstanceId, 'source-instance-id');
  });
}
