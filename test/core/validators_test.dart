import 'package:flutter_test/flutter_test.dart';
import 'package:sana/core/utils/validators.dart';

void main() {
  group('isAluEmail', () {
    test('accepts student and staff domains, any case', () {
      expect(Validators.isAluEmail('a.b@alustudent.com'), isTrue);
      expect(Validators.isAluEmail('Staff@ALUEducation.com'), isTrue);
    });

    test('rejects look-alikes and other domains', () {
      expect(Validators.isAluEmail('me@gmail.com'), isFalse);
      expect(Validators.isAluEmail('me@alustudent.com.evil.io'), isFalse);
      expect(Validators.isAluEmail('me@fakealustudent.com'), isFalse);
    });
  });

  group('password', () {
    test('needs 8 chars, a letter and a number', () {
      expect(Validators.password('short1'), isNotNull);
      expect(Validators.password('longenough'), isNotNull);
      expect(Validators.password('12345678'), isNotNull);
      expect(Validators.password('campus2026'), isNull);
    });
  });

  group('report fields mirror the security rule limits', () {
    test('title 5..80', () {
      expect(Validators.title('Leak'), isNotNull);
      expect(Validators.title('Leaky tap'), isNull);
      expect(Validators.title('x' * 81), isNotNull);
    });

    test('description 20..1000 and reports progress', () {
      expect(Validators.description('Too short'), contains('(9 so far)'));
      expect(Validators.description('Water has been off since 6am today.'), isNull);
    });

    test('whitespace does not count towards the minimum', () {
      expect(Validators.location('   '), isNotNull);
    });
  });
}
