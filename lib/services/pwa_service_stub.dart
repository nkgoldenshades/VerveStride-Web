// Stub implementation for non-web platforms (Android, iOS, Desktop)
class PWAService {
  PWAService._();
  static final PWAService instance = PWAService._();

  bool get canInstall => false;
  bool get isInstalled => false;

  void initialize() {}
  Future<bool> showInstallPrompt() async => false;
  String getInstallInstructions() => '';
  String getDisplayMode() => 'native';
  bool get supportsPWA => false;
  String? getAppStoreLink() => null;
  Future<bool> requestNotificationPermission() async => false;
  void showNotification(
      {required String title, required String body, String? icon}) {}
}
