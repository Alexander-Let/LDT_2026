/// Итог последней попытки синхронизации с бэкендом.
enum SyncStatus { unknown, online, offline }

class SyncState {
  final SyncStatus status;

  /// Точный текст последней ошибки (тип DioException / ответ сервера).
  /// null при успехе или если синка ещё не было.
  final String? error;

  const SyncState(this.status, [this.error]);

  static const SyncState unknown = SyncState(SyncStatus.unknown);
  static const SyncState online = SyncState(SyncStatus.online);
}
