import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/branding/ather_logo.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ather_card.dart';
import '../../core/widgets/ather_controls.dart';
import '../../core/widgets/ather_toast.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/pressable.dart' show Pressable, kMinTarget;
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_providers.dart';

/// The one screen a student sees before their data.
///
/// Built entirely from the existing kit — white card on the grey page, one
/// black button, one red for errors, no new pattern invented for it. It also
/// states the deal up front: **sign in once, then the app works with no
/// connection.** An offline-first product that suddenly demands an account owes
/// the student that sentence.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  /// Minimum length for a **new** password, matching the Identity Platform
  /// policy. Firebase's own default floor is 6, which is what this was before
  /// and is too low for a record a student keeps for two years.
  static const int _minPasswordLength = 8;

  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _registering = false;
  bool _busy = false;
  bool _obscure = true;
  AuthFailure? _failure;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _message(L l, AuthFailure failure) => switch (failure) {
    AuthFailure.invalidEmail => l.authErrorEmailInvalid,
    AuthFailure.weakPassword => l.authErrorPasswordShort,
    AuthFailure.wrongCredentials => l.authErrorWrongCredentials,
    AuthFailure.emailInUse => l.authErrorEmailInUse,
    AuthFailure.network => l.authErrorNoNetwork,
    AuthFailure.tooManyRequests => l.authErrorTooManyAttempts,
    AuthFailure.requiresRecentLogin => l.authErrorRecentLogin,
    AuthFailure.cancelled || AuthFailure.unknown => l.authErrorGeneric,
  };

  /// Runs an auth call and turns any failure into a rendered message.
  ///
  /// Validation happens here rather than by disabling the button: a student
  /// staring at a dead control learns nothing about why it is dead.
  Future<void> _run(
    Future<void> Function() action, {
    bool validate = true,
  }) async {
    if (_busy) return;

    if (validate) {
      if (!_email.text.trim().contains('@')) {
        setState(() => _failure = AuthFailure.invalidEmail);
        return;
      }
      // Checked **only when registering**, and that distinction is the whole
      // point. The minimum was 6 for both paths, and raising it to 8 across the
      // board would have locked out every student who already has a 6- or
      // 7-character password: sign-in does not care how long a password is, so
      // a client-side floor applied there rejects a *correct* password and
      // leaves the student staring at "too short" about an account they own.
      //
      // 8 matches the Identity Platform policy this pairs with. Enforced here
      // too so the student gets the answer instantly instead of after a round
      // trip -- the server remains the one that actually decides.
      if (_registering && _password.text.length < _minPasswordLength) {
        setState(() => _failure = AuthFailure.weakPassword);
        return;
      }
    }

    setState(() {
      _busy = true;
      _failure = null;
    });

    try {
      await action();
      // On success the router's redirect takes over; this screen is popped out
      // from under us, so it must not touch state afterwards.
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        // Backing out of the Google sheet is a decision, not an error.
        _failure = e.failure == AuthFailure.cancelled ? null : e.failure;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final l = L.of(context);
    if (!_email.text.trim().contains('@')) {
      setState(() => _failure = AuthFailure.invalidEmail);
      return;
    }
    final messenger = Overlay.maybeOf(context, rootOverlay: true);
    final direction = Directionality.of(context);
    final message = l.authResetSent;

    await _run(validate: false, () async {
      await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
      if (messenger != null) {
        showAtherToastOn(messenger, direction, message);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final auth = ref.watch(authRepositoryProvider);

    return Scaffold(
      backgroundColor: context.colors.pageBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageMargin,
                AppSpacing.xxxl,
                AppSpacing.pageMargin,
                AppSpacing.xxxl,
              ),
              children: <Widget>[
                // The one screen that is the app introducing itself, so it is
                // the one screen that carries the mark. Glyph rather than the
                // plated icon: the plate is the page's own grey, and a square
                // of it would only draw a box around the symbol.
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AtherGlyph(size: 44),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  _registering ? l.authRegisterTitle : l.authSignInTitle,
                  style: AppTypography.today,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l.authSubtitle,
                  style: context.text.secondary.copyWith(height: 1.6),
                ),
                const SizedBox(height: AppSpacing.section),
                AtherCard(
                  padding: AppSpacing.cardPaddingLarge,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      AtherTextField(
                        controller: _email,
                        label: l.authEmail,
                        hint: l.authEmailHint,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const <String>[AutofillHints.username],
                        onChanged: (_) => _clearFailure(),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AtherTextField(
                        controller: _password,
                        label: l.authPassword,
                        obscure: _obscure,
                        textInputAction: TextInputAction.done,
                        autofillHints: const <String>[AutofillHints.password],
                        onChanged: (_) => _clearFailure(),
                        onSubmitted: (_) => _submit(auth),
                        trailing: Pressable(
                          onTap: () => setState(() => _obscure = !_obscure),
                          // Was an untranslated literal — '•••' / 'abc' — Latin
                          // text sitting inside an Arabic form, unreadable to a
                          // screen reader and unlocalised in either direction.
                          semanticLabel: _obscure
                              ? l.authShowPassword
                              : l.authHidePassword,
                          minTarget: kMinTarget,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            child: Text(
                              // A dot for hidden, an open eye's absence for
                              // shown. Geometry rather than words, so it needs
                              // no translation and matches the icon family.
                              _obscure ? '•••' : '———',
                              style: AppTypography.style(
                                size: 13,
                                weight: AppTypography.bold,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_failure != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.lg),
                        ErrorBanner(
                          height: 1.5,
                          message: _message(l, _failure!),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                      PrimaryButton(
                        // A ring rather than the old literal '…', which was an
                        // untranslated string standing in for a loading state
                        // and read as a stuck button.
                        busy: _busy,
                        label: _registering ? l.authRegister : l.authSignIn,
                        onTap: () => _submit(auth),
                      ),
                      if (!_registering) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        Pressable(
                          onTap: _resetPassword,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xxs),
                            child: Text(
                              l.authForgotPassword,
                              textAlign: TextAlign.center,
                              style: AppTypography.style(
                                size: 13.5,
                                weight: AppTypography.semiBold,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Text only, no Google mark. The design system allows no
                // coloured icons at all, and a monochrome redraw of a brand
                // logo is worse than not showing it.
                PrimaryButton(
                  label: l.authGoogle,
                  tone: PrimaryButtonTone.secondary,
                  onTap: _busy
                      ? null
                      : () => _run(validate: false, auth.signInWithGoogle),
                ),
                const SizedBox(height: AppSpacing.section),
                Pressable(
                  onTap: () => setState(() {
                    _registering = !_registering;
                    _failure = null;
                  }),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Text(
                      _registering ? l.authToSignIn : l.authToRegister,
                      textAlign: TextAlign.center,
                      style: AppTypography.style(
                        size: 14,
                        weight: AppTypography.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _clearFailure() {
    if (_failure != null) setState(() => _failure = null);
  }

  void _submit(AuthRepository auth) {
    _run(
      () => _registering
          ? auth.register(email: _email.text, password: _password.text)
          : auth.signIn(email: _email.text, password: _password.text),
    );
  }
}
