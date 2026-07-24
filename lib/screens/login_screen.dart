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
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final displayNameController = TextEditingController();
  final organizationNameController = TextEditingController();

  bool obscurePassword = true;
  bool createAccount = false;
  bool organizationAccount = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    displayNameController.dispose();
    organizationNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (createAccount) {
      await widget.controller.signUp(
        email: emailController.text,
        password: passwordController.text,
        displayName: displayNameController.text,
        organizationAccount: organizationAccount,
        organizationName: organizationNameController.text,
      );
      return;
    }
    await widget.controller.signIn(
      email: emailController.text,
      password: passwordController.text,
    );
  }

  void _setMode(bool nextCreateAccount) {
    widget.controller.clearError();
    setState(() => createAccount = nextCreateAccount);
  }

  void _useDemo(AppSession session) {
    widget.controller.signInAsDemo(session);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: terminalBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;
            final overview = const _LoginOverview();
            final form = AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) => _LoginForm(
                controller: widget.controller,
                emailController: emailController,
                passwordController: passwordController,
                displayNameController: displayNameController,
                organizationNameController: organizationNameController,
                createAccount: createAccount,
                organizationAccount: organizationAccount,
                obscurePassword: obscurePassword,
                onModeChanged: _setMode,
                onOrganizationChanged: (value) {
                  setState(() => organizationAccount = value);
                },
                onTogglePassword: () {
                  setState(() => obscurePassword = !obscurePassword);
                },
                onSubmit: _submit,
                onDemoSelected: _useDemo,
              ),
            );
            final content = compact
                ? Column(
                    children: [overview, const SizedBox(height: 18), form],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(child: _LoginOverview()),
                      const SizedBox(width: 24),
                      Expanded(child: form),
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
            child: const Icon(
              Icons.sports_basketball,
              color: terminalAccent,
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Sports Terminal',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The professional NBA research and transaction operating system—built around a certified 2025–26 data release, structured analysis, personal work, and organization decision workflows.',
            style: TextStyle(
              color: terminalTextSoft,
              height: 1.55,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 22),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              InfoPill(label: '2025–26 Launch'),
              InfoPill(label: 'Individual Terminal'),
              InfoPill(label: 'Organization Terminal'),
              InfoPill(label: 'Source-Aware Data'),
              InfoPill(label: 'Structured Workflows'),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: terminalBorder),
          const SizedBox(height: 18),
          const _FeatureLine(
            icon: Icons.query_stats_rounded,
            title: 'Research that becomes work',
            description:
                'Player, team, game, cap, contract, draft, and trade objects can move directly into workspaces and governed transaction cases.',
          ),
          const _FeatureLine(
            icon: Icons.apartment_rounded,
            title: 'Individual and organization products',
            description:
                'Personal analysis and shared organization review use one connected workflow while preserving role-specific tools and permissions.',
          ),
          const _FeatureLine(
            icon: Icons.cloud_done_rounded,
            title: 'Remote-first with local resilience',
            description:
                'Customer sessions and collaboration use the launch backend when available; analytical work retains a local fallback during development or temporary outages.',
          ),
          const _FeatureLine(
            icon: Icons.verified_user_rounded,
            title: 'No fabricated launch claims',
            description:
                'The app exposes dataset certification and launch blockers instead of presenting modeled or incomplete data as sourced professional intelligence.',
          ),
        ],
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({
    required this.icon,
    required this.title,
    required this.description,
  });

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
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: terminalTextSoft,
                    height: 1.4,
                  ),
                ),
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
    required this.displayNameController,
    required this.organizationNameController,
    required this.createAccount,
    required this.organizationAccount,
    required this.obscurePassword,
    required this.onModeChanged,
    required this.onOrganizationChanged,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onDemoSelected,
  });

  final AuthController controller;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController displayNameController;
  final TextEditingController organizationNameController;
  final bool createAccount;
  final bool organizationAccount;
  final bool obscurePassword;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<bool> onOrganizationChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final ValueChanged<AppSession> onDemoSelected;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Sign in'),
                icon: Icon(Icons.login_rounded),
              ),
              ButtonSegment(
                value: true,
                label: Text('Create account'),
                icon: Icon(Icons.person_add_alt_1_rounded),
              ),
            ],
            selected: {createAccount},
            onSelectionChanged: controller.busy
                ? null
                : (values) => onModeChanged(values.first),
          ),
          const SizedBox(height: 18),
          Text(
            createAccount ? 'Create your terminal' : 'Welcome back',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            createAccount
                ? 'Create an individual research account or an organization workspace. The launch backend issues a durable session immediately.'
                : 'Sign in through the launch account service. Development demo roles remain available below when the backend is offline.',
            style: const TextStyle(color: terminalTextSoft, height: 1.45),
          ),
          if (createAccount) ...[
            const SizedBox(height: 18),
            TextField(
              controller: displayNameController,
              enabled: !controller.busy,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: Colors.white),
              decoration: _fieldDecoration(
                'Display name',
                Icons.badge_outlined,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: organizationAccount,
              title: const Text(
                'Create an organization terminal',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: const Text(
                'Includes shared cases, members, assignments, approvals, and organization operations.',
                style: TextStyle(color: terminalTextSoft),
              ),
              onChanged: controller.busy ? null : onOrganizationChanged,
            ),
            if (organizationAccount) ...[
              const SizedBox(height: 8),
              TextField(
                controller: organizationNameController,
                enabled: !controller.busy,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: Colors.white),
                decoration: _fieldDecoration(
                  'Organization name',
                  Icons.apartment_rounded,
                ),
              ),
            ],
          ],
          const SizedBox(height: 14),
          TextField(
            controller: emailController,
            enabled: !controller.busy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration('Email', Icons.mail_outline),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: passwordController,
            enabled: !controller.busy,
            obscureText: obscurePassword,
            autofillHints: createAccount
                ? const [AutofillHints.newPassword]
                : const [AutofillHints.password],
            style: const TextStyle(color: Colors.white),
            onSubmitted: (_) => controller.busy ? null : onSubmit(),
            decoration:
                _fieldDecoration('Password', Icons.lock_outline).copyWith(
              helperText: createAccount
                  ? 'At least 10 characters with mixed case and a number.'
                  : null,
              helperStyle: const TextStyle(color: terminalTextMuted),
              suffixIcon: IconButton(
                onPressed: controller.busy ? null : onTogglePassword,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          if (controller.error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3A1F26),
                border: Border.all(color: const Color(0xFF9B4455)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                controller.error!,
                style: const TextStyle(color: Color(0xFFFFB4C0)),
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: controller.busy ? null : onSubmit,
              icon: controller.busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      createAccount
                          ? Icons.person_add_alt_1_rounded
                          : Icons.login_rounded,
                    ),
              label: Text(
                controller.busy
                    ? 'Connecting…'
                    : createAccount
                        ? 'Create Sports Terminal account'
                        : 'Enter Sports Terminal',
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Divider(color: terminalBorder),
          const SizedBox(height: 16),
          const Text(
            'Development demo roles',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'These bypass the account server and should be disabled in a public production build.',
            style: TextStyle(color: terminalTextSoft, fontSize: 12),
          ),
          const SizedBox(height: 10),
          for (final session in controller.demoSessions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: controller.busy ? null : () => onDemoSelected(session),
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
                      const Icon(
                        Icons.account_circle_outlined,
                        color: terminalAccent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.role.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              session.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: terminalTextSoft,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward,
                        color: terminalTextMuted,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
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
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: terminalBorder),
    ),
  );
}
