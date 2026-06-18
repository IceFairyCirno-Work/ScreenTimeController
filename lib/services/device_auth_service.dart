import 'package:local_auth/local_auth.dart';

class DeviceAuthService {
  DeviceAuthService._();

  static final DeviceAuthService instance = DeviceAuthService._();

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> authenticate({required String reason}) async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      if (e.code == LocalAuthExceptionCode.userCanceled ||
          e.code == LocalAuthExceptionCode.systemCanceled) {
        return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
