import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../services/repository.dart';
import '../services/session.dart';
import '../theme.dart';
import 'home_page.dart' show LogoMark;

enum _Mode { signIn, register, reset }

/// Staff sign-in / registration. Only @ijm.org emails can register.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  bool _showPass = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    for (final c in [_name, _email, _pass, _pass2]) {
      c.dispose();
    }
    super.dispose();
  }

  void _switch(_Mode m) => setState(() {
    _mode = m;
    _error = null;
    _info = null;
  });

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final repo = Repository.instance;
    try {
      switch (_mode) {
        case _Mode.signIn:
          await repo.signIn(_email.text, _pass.text);
        case _Mode.register:
          await repo.register(
            name: _name.text,
            email: _email.text,
            password: _pass.text,
          );
        case _Mode.reset:
          await repo.sendPasswordReset(_email.text);
          setState(() {
            _info =
                'If an account exists for ${_email.text.trim()}, a password '
                'reset link has been sent. Check your inbox (and spam folder).';
          });
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = authErrorMessage(e));
    } on AuthMessage catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _emailValidator(String? v) {
    final e = (v ?? '').trim();
    if (e.isEmpty || !e.contains('@')) return 'Enter your email address';
    if (_mode == _Mode.register && !isAllowedEmail(e)) {
      return 'Use your @$allowedEmailDomain email';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, button) = switch (_mode) {
      _Mode.signIn => (
        'Sign in',
        'For $orgName staff. Use your @$allowedEmailDomain email.',
        'Sign in',
      ),
      _Mode.register => (
        'Create your account',
        'Only @$allowedEmailDomain email addresses can register. '
            'We’ll send you a link to confirm it.',
        'Create account',
      ),
      _Mode.reset => (
        'Reset password',
        'We’ll email you a link to choose a new password.',
        'Send reset link',
      ),
    };

    return AuthBackground(
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LogoMark(size: 52),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7A90)),
              ),
              const SizedBox(height: 22),
              if (_mode == _Mode.register) ...[
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v ?? '').trim().length < 2
                      ? 'Enter your full name'
                      : null,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'name@$allowedEmailDomain',
                  prefixIcon: const Icon(Icons.mail_outline),
                ),
                validator: _emailValidator,
              ),
              if (_mode != _Mode.reset) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pass,
                  obscureText: !_showPass,
                  autofillHints: [
                    _mode == _Mode.register
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _showPass ? 'Hide password' : 'Show password',
                      icon: Icon(
                        _showPass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => setState(() => _showPass = !_showPass),
                    ),
                  ),
                  validator: (v) {
                    if ((v ?? '').isEmpty) return 'Enter your password';
                    if (_mode == _Mode.register && v!.length < 8) {
                      return 'At least 8 characters';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) =>
                      _mode == _Mode.signIn ? _submit() : null,
                ),
              ],
              if (_mode == _Mode.register) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pass2,
                  obscureText: !_showPass,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) =>
                      v != _pass.text ? 'Passwords don’t match' : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
              if (_mode == _Mode.signIn)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _switch(_Mode.reset),
                    child: const Text('Forgot password?'),
                  ),
                )
              else
                const SizedBox(height: 16),
              if (_error != null) _Message(_error!, error: true),
              if (_info != null) _Message(_info!),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Please wait…' : button),
                ),
              ),
              const SizedBox(height: 12),
              if (_mode == _Mode.signIn)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('New here?'),
                    TextButton(
                      onPressed: () => _switch(_Mode.register),
                      child: const Text('Create an account'),
                    ),
                  ],
                )
              else
                TextButton.icon(
                  onPressed: () => _switch(_Mode.signIn),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back to sign in'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown after registration until the user clicks the link in their inbox.
class VerifyEmailPage extends StatefulWidget {
  final User user;
  const VerifyEmailPage({super.key, required this.user});
  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  Timer? _poll;
  bool _busy = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;
  String? _msg;

  @override
  void initState() {
    super.initState();
    // Check automatically every 5 seconds so the user doesn't have to.
    _poll = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _check(silent: true),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _check({bool silent = false}) async {
    if (_busy) return;
    if (!silent) setState(() => _busy = true);
    try {
      await SessionController.instance.refresh();
      if (!silent &&
          mounted &&
          !(FirebaseAuth.instance.currentUser?.emailVerified ?? false)) {
        setState(
          () => _msg =
              'Not verified yet. Click the link in the email, then try again.',
        );
      }
    } catch (_) {
      // ignore transient errors while polling
    } finally {
      if (mounted && !silent) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await Repository.instance.resendVerification();
      setState(() {
        _msg = 'Email sent again.';
        _cooldown = 60;
      });
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _cooldown--);
        if (_cooldown <= 0) t.cancel();
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _msg = authErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackground(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Brand.teal.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_unread_outlined,
              color: Brand.teal,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Confirm your email',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'We sent a confirmation link to\n'),
                TextSpan(
                  text: widget.user.email ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Brand.navy,
                  ),
                ),
                const TextSpan(
                  text:
                      '\n\nClick the link in that email. This page continues '
                      'automatically once you’ve confirmed.',
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7A90), height: 1.45),
          ),
          const SizedBox(height: 14),
          const _Message(
            'Can’t find it? Check your spam or junk folder. It comes from '
            'noreply@…firebaseapp.com.',
          ),
          if (_msg != null) _Message(_msg!),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : () => _check(),
              child: Text(_busy ? 'Checking…' : 'I’ve confirmed — continue'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _cooldown > 0 ? null : _resend,
                child: Text(
                  _cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend email',
                ),
              ),
              const Text('·', style: TextStyle(color: Color(0xFF8593A6))),
              TextButton(
                onPressed: () => Repository.instance.signOut(),
                child: const Text('Use a different email'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Signed in with an email outside @ijm.org (and not an admin).
class NotAllowedPage extends StatelessWidget {
  final User user;
  const NotAllowedPage({super.key, required this.user});
  @override
  Widget build(BuildContext context) => AuthBackground(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.block, color: Brand.red, size: 48),
        const SizedBox(height: 12),
        Text('Staff only', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          '${user.email} is not an @$allowedEmailDomain address. '
          'This site is only for $orgName staff.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF6B7A90)),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Repository.instance.signOut(),
          child: const Text('Sign out'),
        ),
      ],
    ),
  );
}

/// Gradient page with a centred white card, shared by the auth screens.
class AuthBackground extends StatelessWidget {
  final Widget child;
  const AuthBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: Brand.heroGradient),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(padding: const EdgeInsets.all(28), child: child),
          ),
        ),
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  final String text;
  final bool error;
  const _Message(this.text, {this.error = false});
  @override
  Widget build(BuildContext context) {
    final c = error ? Brand.red : Brand.blue;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: c, fontSize: 13)),
    );
  }
}

String authErrorMessage(FirebaseAuthException e) => switch (e.code) {
  'invalid-email' => 'That email address looks wrong.',
  'email-already-in-use' =>
    'An account already exists for this email. Sign in instead, or use '
        '“Forgot password?”.',
  'weak-password' =>
    'Please choose a stronger password (at least 8 characters).',
  'user-disabled' => 'This account has been disabled. Contact the admin.',
  'too-many-requests' =>
    'Too many attempts. Please wait a few minutes and try again.',
  'network-request-failed' => 'Network error. Check your connection.',
  'operation-not-allowed' =>
    'Email/password sign-in is not enabled. Contact the admin.',
  _ => 'Incorrect email or password.',
};
