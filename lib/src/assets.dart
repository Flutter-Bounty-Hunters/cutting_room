import 'dart:io';

class Assets {
  static Assets? _instance;
  static Assets get instance {
    _instance ??= Assets._();
    return _instance!;
  }

  Assets._();

  Directory? _assetsDirectory;

  String getAssetPath(String assetFileName) {
    if (_assetsDirectory == null) {
      throw Exception('No assets directory was set before attempting to access: $assetFileName');
    }

    return File('${_assetsDirectory!.path}/$assetFileName').path;
  }

  void setAssetsDirectory(Directory directory) {
    if (!directory.existsSync()) {
      throw Exception('Assets directory does not exist: ${directory.path}');
    }

    _assetsDirectory = directory;
  }
}
