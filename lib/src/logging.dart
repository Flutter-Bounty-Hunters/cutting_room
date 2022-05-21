import 'package:logging/logging.dart';

final compositionLog = Logger("compositions");
final assetsLog = Logger("assets");

class CuttingRoomLogs {
  static CuttingRoomLogs? _instance;
  static CuttingRoomLogs get instance {
    _instance ??= CuttingRoomLogs();
    return _instance!;
  }

  final _activeLoggers = <Logger>{};

  void initAllLogs(Level level) {
    initLoggers(level, {Logger.root});
  }

  void initLoggers(Level level, Set<Logger> loggers) {
    hierarchicalLoggingEnabled = true;

    for (final logger in loggers) {
      if (!_activeLoggers.contains(logger)) {
        // ignore: avoid_print
        print('Initializing logger: ${logger.name}');
        logger
          ..level = level
          ..onRecord.listen(_printLog);

        _activeLoggers.add(logger);
      }
    }
  }

  void _printLog(LogRecord record) {
    // ignore: avoid_print
    print(
        '(${record.time.second}.${record.time.millisecond.toString().padLeft(3, '0')}) ${record.loggerName} > ${record.level.name}: ${record.message}');
  }

  void deactivateLoggers(Set<Logger> loggers) {
    for (final logger in loggers) {
      if (_activeLoggers.contains(logger)) {
        // ignore: avoid_print
        print('Deactivating logger: ${logger.name}');
        logger.clearListeners();

        _activeLoggers.remove(logger);
      }
    }
  }
}
