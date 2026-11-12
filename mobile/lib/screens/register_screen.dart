import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/auth_bloc.dart';
import '../widgets/common.dart';
import 'login_screen.dart' show emailRegExp;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(AuthRegisterRequested(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (a, b) => b.error != null && a.error != b.error,
      listener: (context, state) => showSnack(context, state.error!, error: true),
      child: Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Регистрация', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    'Создайте аккаунт продавца — данные видны только вам',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Имя или название магазина', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => (v?.trim() ?? '').isEmpty ? 'Введите имя' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email)),
                    validator: (v) => emailRegExp.hasMatch(v?.trim() ?? '') ? null : 'Введите корректный email',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Пароль',
                      helperText: 'Не меньше 6 символов',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v ?? '').length < 6 ? 'Минимум 6 символов' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirm,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(labelText: 'Повторите пароль', prefixIcon: Icon(Icons.lock_reset)),
                    validator: (v) => v != _password.text ? 'Пароли не совпадают' : null,
                  ),
                  const SizedBox(height: 28),
                  BlocBuilder<AuthBloc, AuthState>(
                    buildWhen: (a, b) => a.isSubmitting != b.isSubmitting,
                    builder: (context, state) => FilledButton(
                      onPressed: state.isSubmitting ? null : _submit,
                      child: state.isSubmitting
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : const Text('Создать аккаунт'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Уже есть аккаунт? Войти'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
