library dart_oss_licenses;

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import 'package.dart';

final flutterDir = Platform.environment['FLUTTER_ROOT'];
String? guessPubCacheDir() {
  var pubCache = Platform.environment['PUB_CACHE'];
  if (pubCache != null && Directory(pubCache).existsSync()) return pubCache;

  if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'];
    if (appData != null) {
      pubCache = path.join(appData, 'Pub', 'Cache');
      if (Directory(pubCache).existsSync()) return pubCache;
    }
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null) {
      pubCache = path.join(localAppData, 'Pub', 'Cache');
      if (Directory(pubCache).existsSync()) return pubCache;
    }
  }

  final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (homeDir != null) {
    return path.join(homeDir, '.pub-cache');
  }
  return null;
}

Future<List<Package>> generateLicenseInfo({required String pubspecLockPath}) async {
  final pubCacheDir = guessPubCacheDir();
  if (pubCacheDir == null) {
    throw "could not find pub cache directory";
  }
  final pubspecLock = await File(pubspecLockPath).readAsString();
  final pubspec = loadYaml(pubspecLock);
  final packages = pubspec['packages'] as Map;

  final loadedPackages = await Future.wait(
    packages.keys.map(
      (node) => Package.fromMap(
        outerName: node,
        packageJson: packages[node],
        pubCacheDirPath: pubCacheDir,
        flutterDir: flutterDir,
        pubspecLockPath: pubspecLockPath,
      ),
    ),
  );

  final filtered =
      loadedPackages.where((p) => p != null).cast<Package>().toList();
  // Skip...
  // ex)
  // shared_preferences
  // ㄴ shared_preferences_android <-- skip
  // ㄴ shared_preferences_ios <-- skip
  var previous = '';
  final notPrevious = {
    'file',
    'xml',
    'get',
    'http',
    'http2',
    'json',
    'path',
    'plugin',
    'shelf',
    'sqflite',
    'video',
    'flutter',
    'web',
  };
  final newFiltered = filtered.where((e) {
    if (previous.isEmpty || !e.name.contains(previous)) {
      if (!notPrevious.contains(e.name)) previous = e.name;
      if (e.homepage != null || e.repository != null) {
        if (!e.name.startsWith('_')) {
          // if (!(e.repository ?? '').contains('https://github.com/dart-lang')) {
          return true;
          // }
        }
      }
    }
    print('excluded: ${e.name}, ${e.homepage}, ${e.repository}');
    return false;
  }).toList();
  return newFiltered;
}
