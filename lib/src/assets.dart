// ignore: deprecated_member_use
import 'dart:cli';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:cutting_room/assets/black_base64.dart';
import 'package:cutting_room/assets/empty_base64.dart';
import 'package:cutting_room/assets/invisible_mov_base64.dart';
import 'package:cutting_room/assets/white_base64.dart';
import 'package:cutting_room/src/logging.dart';

class Assets {
  static const invisiblePng = Asset._("empty.png", emptyPngBase64);
  static const invisibleVideo = Asset._("invisible.mov", invisibleMovBase64);
  static const whitePng = Asset._("white.png", whitePngBase64);
  static const blackPng = Asset._("black.png", blackPngBase64);

  // static Assets? _instance;
  // static Assets get instance {
  //   _instance ??= Assets._();
  //   return _instance!;
  // }

  Assets._();

  // Directory? _assetsDirectory;
  // final Map<String, String> _fileLookupCache = {};
  //
  // String getAssetPath(String assetFileName) {
  //   // TODO: delete the initial implementation below
  //   // if (_assetsDirectory == null) {
  //   //   throw Exception('No assets directory was set before attempting to access: $assetFileName');
  //   // }
  //   //
  //   // return File('${_assetsDirectory!.path}/$assetFileName').path;
  //
  //   if (_fileLookupCache.containsKey(assetFileName)) {
  //     return _fileLookupCache[assetFileName]!;
  //   } else {
  //     assetsLog.info("Looking up file path for '$assetFileName'");
  //     final packageUri = Uri.parse('package:cutting_room/assets/$assetFileName');
  //     assetsLog.fine("Package URI: $packageUri");
  //     final future = Isolate.resolvePackageUri(packageUri);
  //
  //     // waitFor is strongly discouraged in general, but it is accepted as the
  //     // only reasonable way to load package assets outside of Flutter.
  //     // ignore: deprecated_member_use
  //     final absoluteUri = waitFor(future, timeout: const Duration(seconds: 5));
  //     assetsLog.fine("Resolved asset URI: $absoluteUri");
  //     if (absoluteUri != null) {
  //       final file = File.fromUri(absoluteUri);
  //       if (file.existsSync()) {
  //         return file.path;
  //       }
  //       assetsLog.warning(
  //           "Could not find asset '$assetFileName'. Asset URI was resolved ($absoluteUri), but no file was found at the path");
  //     } else {
  //       // Last ditch attempt: look in local folder
  //       final file = File(assetFileName);
  //       if (file.existsSync()) {
  //         return file.path;
  //       }
  //       assetsLog.warning(
  //           "Could not find asset '$assetFileName' because the package URI did not resolve to a file system path.");
  //     }
  //   }
  //   throw Exception('Could not find asset $assetFileName.');
  // }

  // TODO: delete this when we get package asset path lookup working
  // void setAssetsDirectory(Directory directory) {
  //   if (!directory.existsSync()) {
  //     throw Exception('Assets directory does not exist: ${directory.path}');
  //   }
  //
  //   _assetsDirectory = directory;
  // }
}

/// An asset file that's bundled with the cutting_room package.
class Asset {
  static final Map<String, String> _fileLookupCache = {};

  const Asset._(this.fileName, this.base64encoded);

  final String fileName;
  final String base64encoded;

  /// Attempts to find this asset in the cutting_room package, like
  /// [findAbsolutePathToPackageAsset], and falls back to creating a
  /// new file with the asset's bytes, like [inflateToLocalFile].
  String findOrInflate([Directory? destinationDirectory]) {
    return findAbsolutePathToPackageAsset() ?? inflateToLocalFile(destinationDirectory);
  }

  /// Attempts to find and return the absolute file path to this
  /// asset file, which is bundled with the cutting_room package.
  ///
  /// If the calling app is running as an executable, this attempt
  /// will fail because the executable doesn't include the entire
  /// cutting_room package structure. In this case, use
  /// [inflateToLocalFile], which will write the asset's bytes
  /// to a new file and return that path.
  String? findAbsolutePathToPackageAsset() {
    if (_fileLookupCache.containsKey(fileName)) {
      return _fileLookupCache[fileName]!;
    } else {
      assetsLog.info("Looking up file path for '$fileName'");
      final packageUri = Uri.parse('package:cutting_room/assets/$fileName');
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
        assetsLog.warning("Resolved asset absolute URI, but file doesn't exist");
        return null;
      } else {
        // Last ditch attempt: look in local folder
        final file = File(fileName);
        if (file.existsSync()) {
          return file.path;
        }
        return null;
      }
    }
  }

  /// Writes this asset to a new file on the host's file system.
  ///
  /// The file is written to [destinationDirectory], or the current
  /// working directory, if no destination is provided.
  String inflateToLocalFile([Directory? destinationDirectory]) {
    final directory = destinationDirectory ?? Directory.current;
    final file = File(directory.path + Platform.pathSeparator + fileName);

    file.createSync(recursive: true);
    final decodedBytes = base64Decode(base64encoded);
    file.writeAsBytesSync(decodedBytes);

    return file.path;
  }
}
