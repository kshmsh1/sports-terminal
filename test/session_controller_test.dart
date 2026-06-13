import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/controllers/auth_controller.dart';

void main() {
  test('demo session signs in', () {
    final controller = AuthController();
    expect(controller.signIn(email: 'analyst@sportsterminal.local', password: 'demo123'), isTrue);
    expect(controller.session, isNotNull);
  });
}
