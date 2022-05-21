// ignore: deprecated_member_use
import 'dart:cli';
import 'dart:io';
import 'dart:isolate';

class Assets {
  static Assets? _instance;
  static Assets get instance {
    _instance ??= Assets._();
    return _instance!;
  }

  Assets._();

  // Directory? _assetsDirectory;
  final Map<String, String> _fileLookupCache = {};

  String getAssetPath(String assetFileName) {
    // TODO: delete the initial implementation below
    // if (_assetsDirectory == null) {
    //   throw Exception('No assets directory was set before attempting to access: $assetFileName');
    // }
    //
    // return File('${_assetsDirectory!.path}/$assetFileName').path;

    if (_fileLookupCache.containsKey(assetFileName)) {
      return _fileLookupCache[assetFileName]!;
    } else {
      final uri = Uri.parse('package:cutting_room/assets/$assetFileName');
      final future = Isolate.resolvePackageUri(uri);

      // waitFor is strongly discouraged in general, but it is accepted as the
      // only reasonable way to load package assets outside of Flutter.
      // ignore: deprecated_member_use
      final package = waitFor(future, timeout: const Duration(seconds: 5));
      if (package != null) {
        final file = File.fromUri(package);
        if (file.existsSync()) {
          return file.path;
        }
      } else {
        // Last ditch attempt: look in local folder
        final file = File(assetFileName);
        if (file.existsSync()) {
          return file.path;
        }
      }
    }
    throw Exception('Could not find asset $assetFileName.');
  }

  // TODO: delete this when we get package asset path lookup working
  // void setAssetsDirectory(Directory directory) {
  //   if (!directory.existsSync()) {
  //     throw Exception('Assets directory does not exist: ${directory.path}');
  //   }
  //
  //   _assetsDirectory = directory;
  // }
}
