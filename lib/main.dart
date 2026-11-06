import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'firebase_options.dart';
import 'pages/admin_page.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'services/session.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // nice URLs: /admin instead of /#/admin
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // flutter run -d chrome --dart-define=USE_EMULATOR=true
  if (const bool.fromEnvironment('USE_EMULATOR')) {
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  }
  SessionController.instance; // start listening to sign-in state
  runApp(const DisposalApp());
}

final _router = GoRouter(routes: [
  GoRoute(path: '/', builder: (_, _) => const StaffGate(child: HomePage())),
  GoRoute(path: '/admin', builder: (_, _) => const StaffGate(child: AdminPage())),
]);

/// Shows [child] only to verified @ijm.org staff (or admins); otherwise the
/// sign-in, verify-email or "staff only" screen.
class StaffGate extends StatelessWidget {
  final Widget child;
  const StaffGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: SessionController.instance,
        builder: (context, _) {
          final s = SessionController.instance.value;
          if (s.loading) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (!s.signedIn) return const LoginPage();
          if (s.canUseSite) return child;
          if (!s.allowedDomain) return NotAllowedPage(user: s.user!);
          return VerifyEmailPage(user: s.user!);
        },
      );
}

class DisposalApp extends StatelessWidget {
  const DisposalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'IJM Disposal of Items',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: buildTheme(),
    );
  }
}
