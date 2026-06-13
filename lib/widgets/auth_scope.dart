import 'package:flutter/widgets.dart';

import '../controllers/auth_controller.dart';

class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController controller,
    required super.child,
  }) : super(notifier: controller);

  static AuthController of(BuildContext context) {
    final controller = context.dependOnInheritedWidgetOfExactType<AuthScope>()?.notifier;
    assert(controller != null, 'AuthScope was not found above this context.');
    return controller!;
  }
}
