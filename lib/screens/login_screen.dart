import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../models/app_session.dart';
import '../widgets/terminal_primitives.dart';
import 'product_platform_content_legal_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});
  final AuthController controller;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final displayName = TextEditingController();
  final organizationName = TextEditingController();
  bool createAccount = false;
  bool organizationAccount = false;
  bool obscure = true;
  bool acceptedTerms = false;
  bool acceptedPrivacy = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    displayName.dispose();
    organizationName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (createAccount) {
      await widget.controller.signUp(
        email: email.text,
        password: password.text,
        displayName: displayName.text,
        organizationAccount: organizationAccount,
        organizationName: organizationName.text,
        acceptedTerms: acceptedTerms,
        acceptedPrivacy: acceptedPrivacy,
      );
    } else {
      await widget.controller.signIn(email: email.text, password: password.text);
    }
  }

  Future<void> _openLegal(String kind) => Navigator.of(context).push<void>(
        MaterialPageRoute(
          settings: RouteSettings(name: '/legal/$kind'),
          builder: (_) => Scaffold(
            backgroundColor: terminalBackground,
            appBar: AppBar(
              backgroundColor: terminalPanel,
              foregroundColor: Colors.white,
              title: Text(kind == 'privacy' ? 'Privacy Policy' : 'Terms & Conditions'),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: ProductPlatformLegalScreen(kind: kind),
                ),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: terminalBackground,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 36),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final overview = const _Overview();
                    final form = AnimatedBuilder(
                      animation: widget.controller,
                      builder: (context, _) => _Form(
                        controller: widget.controller,
                        email: email,
                        password: password,
                        displayName: displayName,
                        organizationName: organizationName,
                        createAccount: createAccount,
                        organizationAccount: organizationAccount,
                        obscure: obscure,
                        acceptedTerms: acceptedTerms,
                        acceptedPrivacy: acceptedPrivacy,
                        onMode: (value) => setState(() {
                          createAccount = value;
                          widget.controller.clearError();
                        }),
                        onOrganization: (value) => setState(() => organizationAccount = value),
                        onObscure: () => setState(() => obscure = !obscure),
                        onTerms: (value) => setState(() => acceptedTerms = value),
                        onPrivacy: (value) => setState(() => acceptedPrivacy = value),
                        onOpenTerms: () => _openLegal('terms'),
                        onOpenPrivacy: () => _openLegal('privacy'),
                        onSubmit: _submit,
                        onDemo: widget.controller.signInAsDemo,
                      ),
                    );
                    if (constraints.maxWidth < 820) {
                      return Column(children: [overview, const SizedBox(height: 18), form]);
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Expanded(child: overview), const SizedBox(width: 22), Expanded(child: form)],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
}

class _Overview extends StatelessWidget {
  const _Overview();
  @override
  Widget build(BuildContext context) => const TerminalCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.sports_basketball_rounded, color: terminalAccent, size: 46),
            SizedBox(height: 16),
            Text('Sports Terminal', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
            SizedBox(height: 10),
            Text('A connected sports data, research, transaction, editorial and community operating system—starting with the NBA.', style: TextStyle(color: terminalTextSoft, fontSize: 15, height: 1.55)),
            SizedBox(height: 20),
            Wrap(spacing: 8, runSpacing: 8, children: [
              InfoPill(label: 'NBA Research'), InfoPill(label: 'Linked Entities'), InfoPill(label: 'Trade Machine'), InfoPill(label: 'Python Lab'), InfoPill(label: 'Community'),
            ]),
            SizedBox(height: 22),
            Divider(color: terminalBorder),
            SizedBox(height: 16),
            Text('One account connects your preferences, favorite teams, player watchlists, research context, workspaces, community identity and organization workflows.', style: TextStyle(color: terminalTextSoft, height: 1.5)),
          ],
        ),
      );
}

class _Form extends StatelessWidget {
  const _Form({
    required this.controller,
    required this.email,
    required this.password,
    required this.displayName,
    required this.organizationName,
    required this.createAccount,
    required this.organizationAccount,
    required this.obscure,
    required this.acceptedTerms,
    required this.acceptedPrivacy,
    required this.onMode,
    required this.onOrganization,
    required this.onObscure,
    required this.onTerms,
    required this.onPrivacy,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
    required this.onSubmit,
    required this.onDemo,
  });
  final AuthController controller;
  final TextEditingController email, password, displayName, organizationName;
  final bool createAccount, organizationAccount, obscure, acceptedTerms, acceptedPrivacy;
  final ValueChanged<bool> onMode, onOrganization, onTerms, onPrivacy;
  final VoidCallback onObscure, onOpenTerms, onOpenPrivacy, onSubmit;
  final ValueChanged<AppSession> onDemo;

  @override
  Widget build(BuildContext context) => TerminalCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Sign in'), icon: Icon(Icons.login_rounded)),
              ButtonSegment(value: true, label: Text('Create account'), icon: Icon(Icons.person_add_alt_1_rounded)),
            ],
            selected: {createAccount},
            onSelectionChanged: controller.busy ? null : (values) => onMode(values.first),
          ),
          const SizedBox(height: 18),
          Text(createAccount ? 'Create your terminal' : 'Welcome back', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
          if (createAccount) ...[
            const SizedBox(height: 14),
            TextField(controller: displayName, enabled: !controller.busy, style: const TextStyle(color: Colors.white), decoration: _field('Display name', Icons.badge_outlined)),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: organizationAccount, onChanged: controller.busy ? null : onOrganization, title: const Text('Organization terminal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), subtitle: const Text('Shared members, cases, approvals and organization controls.', style: TextStyle(color: terminalTextSoft))),
            if (organizationAccount) TextField(controller: organizationName, enabled: !controller.busy, style: const TextStyle(color: Colors.white), decoration: _field('Organization name', Icons.apartment_rounded)),
          ],
          const SizedBox(height: 12),
          TextField(controller: email, enabled: !controller.busy, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: Colors.white), decoration: _field('Email', Icons.mail_outline)),
          const SizedBox(height: 12),
          TextField(controller: password, enabled: !controller.busy, obscureText: obscure, style: const TextStyle(color: Colors.white), onSubmitted: (_) => controller.busy ? null : onSubmit(), decoration: _field('Password', Icons.lock_outline).copyWith(suffixIcon: IconButton(onPressed: onObscure, icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
          if (createAccount) ...[
            const SizedBox(height: 14),
            _LegalConsent(value: acceptedTerms, onChanged: onTerms, title: 'I agree to the Terms & Conditions', onOpen: onOpenTerms),
            _LegalConsent(value: acceptedPrivacy, onChanged: onPrivacy, title: 'I acknowledge and agree to the Privacy Policy', onOpen: onOpenPrivacy),
            const SizedBox(height: 6),
            const Text('Both agreements are required. Sports Terminal records the accepted legal-document version and acceptance timestamp with account creation.', style: TextStyle(color: terminalTextMuted, fontSize: 11, height: 1.4)),
          ],
          if (controller.error != null) ...[
            const SizedBox(height: 12),
            Container(width: double.infinity, padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: const Color(0xFF3A1F26), border: Border.all(color: const Color(0xFF9B4455)), borderRadius: BorderRadius.circular(10)), child: Text(controller.error!, style: const TextStyle(color: Color(0xFFFFB4C0)))),
          ],
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: controller.busy || (createAccount && (!acceptedTerms || !acceptedPrivacy)) ? null : onSubmit, icon: controller.busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(createAccount ? Icons.person_add_alt_1_rounded : Icons.login_rounded), label: Text(createAccount ? 'Create Sports Terminal account' : 'Enter Sports Terminal'))),
          const SizedBox(height: 20),
          const Divider(color: terminalBorder),
          const SizedBox(height: 12),
          const Text('Development demo roles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final session in controller.demoSessions)
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.account_circle_outlined, color: terminalAccent), title: Text(session.role.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), subtitle: Text(session.email, style: const TextStyle(color: terminalTextSoft)), trailing: const Icon(Icons.arrow_forward_rounded, color: terminalTextMuted), onTap: controller.busy ? null : () => onDemo(session)),
        ]),
      );
}

class _LegalConsent extends StatelessWidget {
  const _LegalConsent({required this.value, required this.onChanged, required this.title, required this.onOpen});
  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Checkbox(value: value, onChanged: (next) => onChanged(next == true)),
        Expanded(child: Padding(padding: const EdgeInsets.only(top: 7), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), TextButton(onPressed: onOpen, style: TextButton.styleFrom(padding: EdgeInsets.zero), child: const Text('Read full document'))]))),
      ]);
}

InputDecoration _field(String label, IconData icon) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: terminalTextMuted),
      prefixIcon: Icon(icon, color: terminalTextMuted),
      filled: true,
      fillColor: terminalPanelDark,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: terminalBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: terminalAccent)),
    );
