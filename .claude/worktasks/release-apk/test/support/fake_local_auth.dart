import 'package:local_auth/local_auth.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart'
    show AuthMessages;

/// A [LocalAuthentication] that answers however a test needs it to.
///
/// The real one talks to the platform, so without this the lock's behaviour is
/// only assertable on a device -- which is exactly how it shipped bypassable.
class FakeLocalAuth implements LocalAuthentication {
  FakeLocalAuth({
    this.result = false,
    this.throwCode,
    this.supported = true,
    this.enrolled = const <BiometricType>[BiometricType.fingerprint],
  });

  /// What `authenticate` returns when it does not throw.
  ///
  /// `false` is the plugin's documented answer for "the user failed the
  /// challenge without side effects" -- a refusal or a cancellation, including
  /// the back button on the system prompt.
  bool result;

  /// A [LocalAuthExceptionCode] to throw instead of returning.
  LocalAuthExceptionCode? throwCode;

  bool supported;
  List<BiometricType> enrolled;

  int attempts = 0;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const <AuthMessages>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    attempts++;
    final code = throwCode;
    if (code != null) {
      throw LocalAuthException(code: code, description: 'fake');
    }
    return result;
  }

  @override
  Future<bool> get canCheckBiometrics async => enrolled.isNotEmpty;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => enrolled;

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<bool> stopAuthentication() async => true;
}
