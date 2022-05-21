// ignore: deprecated_member_use
import 'dart:cli';
import 'dart:io';
import 'dart:isolate';

import 'package:cutting_room/src/logging.dart';

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
      assetsLog.info("Looking up file path for '$assetFileName'");
      final packageUri = Uri.parse('package:cutting_room/assets/$assetFileName');
      assetsLog.fine("Package URI: $packageUri");
      final future = Isolate.resolvePackageUri(packageUri);

      // waitFor is strongly discouraged in general, but it is accepted as the
      // only reasonable way to load package assets outside of Flutter.
      // ignore: deprecated_member_use
      final absoluteUri = waitFor(future, timeout: const Duration(seconds: 5));
      assetsLog.fine("Resolved asset URI: $absoluteUri");
      if (absoluteUri != null) {
        final file = File.fromUri(absoluteUri);
        if (file.existsSync()) {
          return file.path;
        }
        assetsLog.warning(
            "Could not find asset '$assetFileName'. Asset URI was resolved ($absoluteUri), but no file was found at the path");
      } else {
        // Last ditch attempt: look in local folder
        final file = File(assetFileName);
        if (file.existsSync()) {
          return file.path;
        }
        assetsLog.warning(
            "Could not find asset '$assetFileName' because the package URI did not resolve to a file system path.");
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
