import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/auth_bloc.dart';
import '../core/api_client.dart';
import '../widgets/common.dart';
import 'register_screen.dart';

final emailRegExp = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(AuthLoginRequested(email: _email.text, password: _password.text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (a, b) => b.error != null && a.error != b.error,
      listener: (context, state) => showSnack(context, state.error!, error: true),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.storefront_rounded, size: 56, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('Вход', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      'Войдите, чтобы вести учёт продаж на Wildberries',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email)),
                      validator: (v) => emailRegExp.hasMatch(v?.trim() ?? '') ? null : 'Введите корректный email',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Пароль',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v ?? '').isEmpty ? 'Введите пароль' : null,
                    ),
                    const SizedBox(height: 24),
                    BlocBuilder<AuthBloc, AuthState>(
                      buildWhen: (a, b) => a.isSubmitting != b.isSubmitting,
                      builder: (context, state) => FilledButton(
                        onPressed: state.isSubmitting ? null : _submit,
                        child: state.isSubmitting
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                            : const Text('Войти'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
                      ),
                      child: const Text('Нет аккаунта? Зарегистрироваться'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Сервер: ${ApiClient.baseUrl}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
