import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/session_provider.dart';
import 'widgets/location_picker.dart';

enum _AuthMode { login, register }

/// Login y registro. En web los campos usan keys estables y pasan a `readOnly`
/// (no deshabilitados) para no perder el foco.
class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  // Nueva key para limpiar errores sin borrar el texto.
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _phoneController = TextEditingController();
  final _restaurantNameController = TextEditingController();
  final _streetController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  GeoPoint? _restaurantLocation;

  final _nameFocus = FocusNode(debugLabel: 'auth-name');
  final _emailFocus = FocusNode(debugLabel: 'auth-email');
  final _passwordFocus = FocusNode(debugLabel: 'auth-password');
  final _confirmFocus = FocusNode(debugLabel: 'auth-confirm');
  final _phoneFocus = FocusNode(debugLabel: 'auth-phone');
  final _restaurantNameFocus = FocusNode(debugLabel: 'auth-restaurant-name');
  final _streetFocus = FocusNode(debugLabel: 'auth-street');
  final _neighborhoodFocus = FocusNode(debugLabel: 'auth-neighborhood');
  final _cityFocus = FocusNode(debugLabel: 'auth-city');
  final _postalCodeFocus = FocusNode(debugLabel: 'auth-postal-code');

  // Sigue siendo accesible con clic/toque, pero Tab no se detiene en él.
  final _visibilityToggleFocus =
      FocusNode(debugLabel: 'auth-visibility', skipTraversal: true);

  // Constantes para no reconfigurar el <input> en web en cada build.
  static const _nameHints = [AutofillHints.name];
  static const _emailHints = [AutofillHints.email];
  static const _passwordHints = [AutofillHints.password];
  static const _newPasswordHints = [AutofillHints.newPassword];
  static const _phoneHints = [AutofillHints.telephoneNumber];
  static const _streetHints = [AutofillHints.streetAddressLine1];
  static const _neighborhoodHints = [AutofillHints.sublocality];
  static const _cityHints = [AutofillHints.addressCity];
  static const _postalCodeHints = [AutofillHints.postalCode];

  _AuthMode _mode = _AuthMode.login;
  UserRole _role = UserRole.cliente;
  bool _obscurePassword = true;

  bool get _isRegister => _mode == _AuthMode.register;
  bool get _isRestaurant => _isRegister && _role == UserRole.restaurante;

  List<FocusNode> get _fieldOrder => [
        if (_isRegister) _nameFocus,
        _emailFocus,
        _passwordFocus,
        if (_isRegister) ...[_confirmFocus, _phoneFocus],
        if (_isRestaurant) ..._restaurantFocusNodes,
      ];

  List<FocusNode> get _restaurantFocusNodes => [
        _restaurantNameFocus,
        _streetFocus,
        _neighborhoodFocus,
        _cityFocus,
        _postalCodeFocus,
      ];

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _emailController,
      _passwordController,
      _confirmController,
      _phoneController,
      _restaurantNameController,
      _streetController,
      _neighborhoodController,
      _cityController,
      _postalCodeController,
    ]) {
      c.dispose();
    }
    for (final f in [
      _nameFocus,
      _emailFocus,
      _passwordFocus,
      _confirmFocus,
      _phoneFocus,
      ..._restaurantFocusNodes,
      _visibilityToggleFocus,
    ]) {
      f.dispose();
    }
    super.dispose();
  }

  void _setMode(_AuthMode mode) {
    if (mode == _mode) return;
    context.read<SessionProvider>().clearAuthError();
    setState(() {
      _mode = mode;
      _formKey = GlobalKey<FormState>();
    });
  }

  void _setRole(UserRole role) {
    // Evita que el foco quede en un campo que ya no existe.
    if (role == UserRole.cliente &&
        _restaurantFocusNodes.any((f) => f.hasFocus)) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    setState(() => _role = role);
  }

  TextInputAction _actionFor(FocusNode node) =>
      identical(_fieldOrder.last, node) ? TextInputAction.done : TextInputAction.next;

  void _advanceFrom(FocusNode node) {
    final order = _fieldOrder;
    final i = order.indexOf(node);
    if (i >= 0 && i < order.length - 1) {
      order[i + 1].requestFocus();
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    final session = context.read<SessionProvider>();
    if (session.isBusy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();

    if (_isRegister) {
      await session.register(
        displayName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        role: _role,
        phone: _phoneController.text,
        restaurantName: _isRestaurant ? _restaurantNameController.text : null,
        restaurantAddress: _isRestaurant
            ? RestaurantAddress(
                street: _streetController.text,
                neighborhood: _neighborhoodController.text,
                city: _cityController.text,
                postalCode: _postalCodeController.text,
              )
            : null,
        restaurantLocation: _isRestaurant ? _restaurantLocation : null,
      );
    } else {
      await session.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
    }

    if (mounted && session.authError != null) {
      _passwordFocus.requestFocus();
    }
  }

  static String? _required(String? value, String message) =>
      (value?.trim().isEmpty ?? true) ? message : null;

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Ingresa tu correo.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Ingresa un correo válido.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Ingresa tu contraseña.';
    if (_isRegister && value.length < 6) {
      return 'Usa al menos 6 caracteres.';
    }
    return null;
  }

  String? _validateConfirm(String? value) =>
      value != _passwordController.text ? 'Las contraseñas no coinciden.' : null;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final theme = Theme.of(context);
    final busy = session.isBusy;

    InputDecoration decoration(String label, IconData icon, {String? helper}) =>
        InputDecoration(
          labelText: label,
          helperText: helper,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        );

    Widget field({
      required String id,
      required TextEditingController controller,
      required FocusNode focusNode,
      required InputDecoration decoration,
      List<String>? autofillHints,
      TextInputType? keyboardType,
      TextCapitalization capitalization = TextCapitalization.none,
      bool obscure = false,
      bool clearsAuthError = false,
      FormFieldValidator<String>? validator,
    }) =>
        TextFormField(
          key: ValueKey('auth-field-$id'),
          controller: controller,
          focusNode: focusNode,
          readOnly: busy,
          obscureText: obscure,
          autocorrect: !obscure && keyboardType != TextInputType.emailAddress,
          enableSuggestions: !obscure,
          keyboardType: keyboardType,
          textCapitalization: capitalization,
          textInputAction: _actionFor(focusNode),
          autofillHints: autofillHints,
          decoration: decoration,
          validator: validator,
          onChanged: clearsAuthError ? (_) => session.clearAuthError() : null,
          onFieldSubmitted: (_) => _advanceFrom(focusNode),
        );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.eco, size: 64, color: theme.colorScheme.primary),
                      const SizedBox(height: 8),
                      Text(
                        'ResCAT',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rescata comida, ahorra dinero',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      SegmentedButton<_AuthMode>(
                        segments: const [
                          ButtonSegment(
                            value: _AuthMode.login,
                            label: Text('Iniciar sesión'),
                          ),
                          ButtonSegment(
                            value: _AuthMode.register,
                            label: Text('Crear cuenta'),
                          ),
                        ],
                        selected: {_mode},
                        showSelectedIcon: false,
                        onSelectionChanged:
                            busy ? null : (s) => _setMode(s.first),
                      ),
                      const SizedBox(height: 24),

                      // Solo registro
                      if (_isRegister) ...[
                        Text('¿Cómo usarás ResCAT?',
                            style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        SegmentedButton<UserRole>(
                          segments: const [
                            ButtonSegment(
                              value: UserRole.cliente,
                              icon: Icon(Icons.person_outline),
                              label: Text('Cliente'),
                            ),
                            ButtonSegment(
                              value: UserRole.restaurante,
                              icon: Icon(Icons.storefront_outlined),
                              label: Text('Restaurante'),
                            ),
                          ],
                          selected: {_role},
                          onSelectionChanged:
                              busy ? null : (s) => _setRole(s.first),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _role == UserRole.cliente
                              ? 'Aparta paquetes de comida a precio reducido.'
                              : 'Publica tus excedentes y entrégalos con PIN.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 20),
                        field(
                          id: 'name',
                          controller: _nameController,
                          focusNode: _nameFocus,
                          capitalization: TextCapitalization.words,
                          autofillHints: _nameHints,
                          decoration: decoration(
                            _isRestaurant
                                ? 'Nombre del responsable'
                                : 'Tu nombre',
                            Icons.badge_outlined,
                          ),
                          validator: (v) => _required(v, 'Ingresa tu nombre.'),
                        ),
                        const SizedBox(height: 16),
                      ],

                      field(
                        id: 'email',
                        controller: _emailController,
                        focusNode: _emailFocus,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: _emailHints,
                        clearsAuthError: true,
                        decoration:
                            decoration('Correo electrónico', Icons.email_outlined),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 16),
                      field(
                        id: 'password',
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        obscure: _obscurePassword,
                        keyboardType: TextInputType.visiblePassword,
                        autofillHints:
                            _isRegister ? _newPasswordHints : _passwordHints,
                        clearsAuthError: true,
                        decoration: decoration('Contraseña', Icons.lock_outline)
                            .copyWith(
                          suffixIcon: IconButton(
                            focusNode: _visibilityToggleFocus,
                            tooltip: _obscurePassword
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: _validatePassword,
                      ),

                      // Solo registro
                      if (_isRegister) ...[
                        const SizedBox(height: 16),
                        field(
                          id: 'confirm',
                          controller: _confirmController,
                          focusNode: _confirmFocus,
                          obscure: _obscurePassword,
                          keyboardType: TextInputType.visiblePassword,
                          autofillHints: _newPasswordHints,
                          decoration: decoration(
                              'Confirmar contraseña', Icons.lock_reset_outlined),
                          validator: _validateConfirm,
                        ),
                        const SizedBox(height: 16),
                        field(
                          id: 'phone',
                          controller: _phoneController,
                          focusNode: _phoneFocus,
                          keyboardType: TextInputType.phone,
                          autofillHints: _phoneHints,
                          decoration: decoration(
                              'Teléfono (opcional)', Icons.phone_outlined),
                        ),
                      ],
                      if (_isRestaurant) ...[
                        const SizedBox(height: 24),
                        Text('Datos del restaurante',
                            style: theme.textTheme.titleSmall),
                        const SizedBox(height: 12),
                        field(
                          id: 'restaurant-name',
                          controller: _restaurantNameController,
                          focusNode: _restaurantNameFocus,
                          capitalization: TextCapitalization.words,
                          decoration: decoration('Nombre del restaurante',
                              Icons.storefront_outlined),
                          validator: (v) => _required(
                              v, 'Ingresa el nombre del restaurante.'),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Dirección donde los clientes recogerán sus paquetes',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        field(
                          id: 'restaurant-street',
                          controller: _streetController,
                          focusNode: _streetFocus,
                          capitalization: TextCapitalization.words,
                          autofillHints: _streetHints,
                          decoration: decoration(
                              'Calle y número', Icons.place_outlined),
                          validator: (v) =>
                              _required(v, 'Ingresa la calle y el número.'),
                        ),
                        const SizedBox(height: 16),
                        field(
                          id: 'restaurant-neighborhood',
                          controller: _neighborhoodController,
                          focusNode: _neighborhoodFocus,
                          capitalization: TextCapitalization.words,
                          autofillHints: _neighborhoodHints,
                          decoration: decoration(
                              'Colonia', Icons.holiday_village_outlined),
                          validator: (v) =>
                              _required(v, 'Ingresa la colonia.'),
                        ),
                        const SizedBox(height: 16),
                        field(
                          id: 'restaurant-city',
                          controller: _cityController,
                          focusNode: _cityFocus,
                          capitalization: TextCapitalization.words,
                          autofillHints: _cityHints,
                          decoration: decoration('Ciudad y estado',
                              Icons.location_city_outlined),
                          validator: (v) =>
                              _required(v, 'Ingresa la ciudad.'),
                        ),
                        const SizedBox(height: 16),
                        field(
                          id: 'restaurant-postal-code',
                          controller: _postalCodeController,
                          focusNode: _postalCodeFocus,
                          keyboardType: TextInputType.number,
                          autofillHints: _postalCodeHints,
                          decoration: decoration('Código postal (opcional)',
                              Icons.markunread_mailbox_outlined),
                        ),
                        const SizedBox(height: 16),
                        LocationPicker(
                          value: _restaurantLocation,
                          enabled: !busy,
                          onChanged: (p) =>
                              setState(() => _restaurantLocation = p),
                        ),
                      ],

                      if (session.authError != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          session.authError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: busy
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : Text(_isRegister
                                ? 'Crear cuenta'
                                : 'Iniciar sesión'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
