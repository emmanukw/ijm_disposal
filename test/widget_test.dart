import 'package:flutter_test/flutter_test.dart';
import 'package:ijm_disposal/models/auction_settings.dart';

void main() {
  test('booking window', () {
    final s = AuctionSettings(
      title: 't',
      startsAt: DateTime(2026, 1, 1, 9),
      endsAt: DateTime(2026, 1, 1, 17),
    );
    expect(s.notStarted(DateTime(2026, 1, 1, 8)), isTrue);
    expect(s.isOpen(DateTime(2026, 1, 1, 12)), isTrue);
    expect(s.isOpen(DateTime(2026, 1, 1, 17)), isFalse);
    expect(AuctionSettings.empty.isOpen(DateTime.now()), isFalse);
  });
}
