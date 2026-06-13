import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../models/app_session.dart';
import '../widgets/terminal_primitives.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController(text: 'analyst@sportsterminal.local');
  final passwordController = TextEditingController(text: 'demo123');
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    widget.controller.signIn(
      email: emailController.text,
      password: passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: terminalBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;
            final content = compact
                ? Column(
                    children: [
                      const _LoginOverview(),
                      const SizedBox(height: 18),
                      _LoginForm(
                        controller: widget.controller,
                        emailController: emailController,
                        passwordController: passwordController,
                        obscurePassword: obscurePassword,
                        onTogglePassword: () => setState(() => obscurePassword = !obscurePassword),
                        onSubmit: _submit,
                        onDemoSelected: widget.controller.signInAsDemo,
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(child: _LoginOverview()),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _LoginForm(
                          controller: widget.controller,
                          emailController: emailController,
                          passwordController: passwordController,
                          obscurePassword: obscurePassword,
                          onTogglePassword: () => setState(() => obscurePassword = !obscurePassword),
                          onSubmit: _submit,
                          onDemoSelected: widget.controller.signInAsDemo,
                        ),
                      ),
                    ],
                  );

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 18 : 42,
                vertical: compact ? 24 : 52,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: content,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoginOverview extends StatelessWidget {
  const _LoginOverview();

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF152235),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: terminalBorder),
            ),
            child: const Icon(Icons.sports_basketball, color: terminalAccent, size: 28),
          ),
          const SizedBox(height: 18),
          const Text(
            'Sports Terminal',
            style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'A user-facing NBA research terminal with organization-scoped workspaces, controlled internal outputs, source-aware analysis, and separate platform administration.',
            style: TextStyle(color: terminalTextSoft, height: 1.55, fontSize: 15),
          ),
          const SizedBox(height: 22),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              InfoPill(label: 'User Mode'),
              InfoPill(label: 'Organization Scope'),
              InfoPill(label: 'Internal Spreadsheet'),
              InfoPill(label: 'Controlled SQL'),
              InfoPill(label: 'No Raw Download'),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: terminalBorder),
          const SizedBox(height: 18),
          const _FeatureLine(
            icon: Icons.person_outline,
            title: 'User mode is separate',
            description: 'Regular users see research, entity, workflow, and workspace surfaces—not Build Lab or Data Ops.',
          ),
          const _FeatureLine(
            icon: Icons.apartment_outlined,
            title: 'Organization-scoped work',
            description: 'Workbooks and SQL documents are attached to the signed-in organization in the current local prototype.',
          ),
          const _FeatureLine(
            icon: Icons.security_outlined,
            title: 'Internal-only output policy',
            description: 'Data moves into internal spreadsheets, SQL workspaces, reports, and saved views rather than unrestricted CSV downloads.',
          ),
        ],
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.icon, required this.title, required this.description});

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: terminalAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(color: terminalTextSoft, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.controller,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onDemoSelected,
  });

  final AuthController controller;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final ValueChanged<AppSession> onDemoSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return TerminalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sign in', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text(
                'Local development authentication. Real account persistence and invitations will require the backend phase.',
                style: TextStyle(color: terminalTextSoft, height: 1.45),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: _fieldDecoration('Email', Icons.mail_outline),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                style: const TextStyle(color: Colors.white),
                onSubmitted: (_) => onSubmit(),
                decoration: _fieldDecoration('Password', Icons.lock_outline).copyWith(
                  suffixIcon: IconButton(
                    onPressed: onTogglePassword,
                    icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
              ),
              if (controller.error != null) ...[
                const SizedBox(height: 12),
                Text(controller.error!, style: const TextStyle(color: Color(0xFFFF8A80))),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onSubmit,
                  icon: const Icon(Icons.login),
                  label: const Text('Enter Sports Terminal'),
                ),
              ),
              const SizedBox(height: 22),
              const Divider(color: terminalBorder),
              const SizedBox(height: 16),
              const Text('Demo roles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              for (final session in controller.demoSessions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onDemoSelected(session),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: terminalPanelDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: terminalBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_circle_outlined, color: terminalAccent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(session.role.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Text(session.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: terminalTextSoft, fontSize: 12)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward, color: terminalTextMuted, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

InputDecoration _fieldDecoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: terminalTextMuted),
    prefixIcon: Icon(icon, color: terminalTextMuted),
    filled: true,
    fillColor: terminalPanelDark,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: terminalBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: terminalAccent),
    ),
  );
}
