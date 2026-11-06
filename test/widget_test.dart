import 'package:flutter_test/flutter_test.dart';
import 'package:ijm_disposal/config.dart';
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

  test('limits text', () {
    expect(AuctionSettings.empty.hasLimits, isFalse);
    expect(AuctionSettings.empty.limitsText, 'No booking limits');
    const s = AuctionSettings(title: 't', maxPerItemPerPerson: 2, maxTotalPerPerson: 3);
    expect(s.limitsText, 'Max 2 per item · 3 in total per person');
    const t = AuctionSettings(title: 't', maxTotalPerPerson: 5);
    expect(t.limitsText, '5 in total per person');
  });

  test('allowed email domain', () {
    expect(isAllowedEmail('Jane.Doe@IJM.org'), isTrue);
    expect(isAllowedEmail('jane@gmail.com'), isFalse);
    expect(isAllowedEmail('jane@ijm.org.evil.com'), isFalse);
    expect(isAllowedEmail(null), isFalse);
  });
}
