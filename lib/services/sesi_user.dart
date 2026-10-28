import 'session_manager.dart'; 

Future<int> idUserLogin() async {
  final id = await SessionManager.instance.currentUserId();
  if (id == null) {
    throw StateError('Sesi login tidak ditemukan atau sudah kedaluwarsa');
  }
  return id;
}