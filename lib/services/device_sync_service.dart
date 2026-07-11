import 'package:shared_preferences/shared_preferences.dart';

class DeviceSyncService {
  static const String _firstSyncKey = "first_sync_completed";

  Future<bool> isFirstLoginOnDevice() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_firstSyncKey) ?? false);
  }

  Future<void> markFirstSyncCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstSyncKey, true);
  }
}