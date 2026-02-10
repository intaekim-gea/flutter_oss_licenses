import 'dart:io';

import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

part 'package.g.dart';

@JsonSerializable(explicitToJson: true)
class Package {
  @JsonKey(ignore: true)
  final Directory? directory;
  @JsonKey(ignore: true)
  final Map? packageYaml;
  final String name;
  final String description;
  final String? homepage;
  final String? repository;
  final List<String> authors;
  final String version;
  final String? license;
  final bool isMarkdown;
  final bool isSdk;
  final bool isDirectDependency;

  const Package({
    this.directory,
    this.packageYaml,
    required this.name,
    required this.description,
    this.homepage,
    this.repository,
    required this.authors,
    required this.version,
    this.license,
    required this.isMarkdown,
    required this.isSdk,
    required this.isDirectDependency,
  });

  factory Package.fromJson(Map<String, dynamic> json) => _$PackageFromJson(json);
  Map<String, dynamic> toJson() => _$PackageToJson(this);


  static Future<Package?> fromMap({
    required String outerName,
    required Map packageJson,
    required String pubCacheDirPath,
    required String? flutterDir,
    required String pubspecLockPath,
  }) async {
    Directory directory;
    bool isSdk = false;
    final source = packageJson['source'];
    final desc = packageJson['description'];
    if (source == 'hosted') {
      final host = removePrefix(desc['url']);
      final name = desc['name'];
      final version = packageJson['version'];
      directory = Directory(path.join(pubCacheDirPath, 'hosted', host.replaceAll('/', '%47'), '$name-$version'));
    } else if (source == 'git') {
      final repo = gitRepoName(desc['url']);
      final commit = desc['resolved-ref'];
      directory = Directory(path.join(pubCacheDirPath, 'git/$repo-$commit', desc['path']));
    } else if (source == 'sdk' && flutterDir != null) {
      directory = Directory(path.join(flutterDir, 'packages', outerName));
      isSdk = true;
    } else if (source == 'path') {
      directory = Directory(path.absolute(path.dirname(pubspecLockPath), desc['path']));
      isSdk = true;
    } else {
      return null;
    }
    final isDirectDependency = packageJson['dependency'] == "direct main";

    String? license;
    bool isMarkdown = false;
    if (outerName == 'flutter' && flutterDir != null) {
      license = await File(path.join(flutterDir, 'LICENSE')).readAsString();
    } else {
      String licensePath = path.join(directory.path, 'LICENSE');
      try {
        license = await File(licensePath).readAsString();
      } catch (e) {
        if (await File(licensePath + '.md').exists()) {
          license = await File(licensePath + '.md').readAsString();
          isMarkdown = true;
        }
      }
    }

    if (license == '') {
      license = null;
    }

    dynamic yaml;
    try {
      yaml = loadYaml(await File(path.join(directory.path, 'pubspec.yaml')).readAsString());
    } catch (e) {
      // yaml may not be there
      yaml = {};
    }

    final name = yaml['name'];
    final description = yaml['description'];
    if (name is! String || description is! String) {
      return null;
    }

    final version =
        outerName == 'flutter' && flutterDir != null ? getFlutterVersionFromDirectory(flutterDir) : yaml['version'];
    if (version is! String) {
      return null;
    }

    return Package(
        directory: directory,
        packageYaml: yaml,
        name: name,
        description: description,
        homepage: yaml['homepage'],
        repository: yaml['repository'],
        authors: yaml['authors']?.cast<String>()?.toList() ?? (yaml['author'] != null ? [yaml['author']] : []),
        version: version.trim(),
        license: license?.trim().replaceAll('\r\n', '\n'),
        isMarkdown: isMarkdown,
        isSdk: isSdk,
        isDirectDependency: isDirectDependency);
  }

  /// Retrieves the Flutter SDK version from the specified Flutter directory.
  ///
  /// [flutterDir] is the path to the Flutter SDK directory.
  /// Returns the Flutter version as a string, or null if it cannot be determined.
  ///
  /// This method reads the `flutter.version.json` file located in the `bin/cache` directory of the Flutter SDK.
  static Future<String?> getFlutterVersionFromDirectory(String flutterDir) async {
    try {
      final versionFile = File(path.join(flutterDir, 'bin/cache/flutter.version.json'));
      if (await versionFile.exists()) {
        final versionJson = loadYaml(await versionFile.readAsString());
        if (versionJson is Map && versionJson['flutterVersion'] is String) {
          return versionJson['flutterVersion'];
        }
      }
    } catch (e) {
      // ignore
    }
    return null;
  }
}

String removePrefix(String url) {
  if (url.startsWith('https://')) return url.substring(8);
  if (url.startsWith('http://')) return url.substring(7); // are there any?
  return url;
}

String gitRepoName(String url) {
  final name = url.substring(url.lastIndexOf('/') + 1);
  return name.endsWith('.git') ? name.substring(0, name.length - 4) : name;
}
