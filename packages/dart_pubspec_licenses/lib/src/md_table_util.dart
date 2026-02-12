library dart_oss_licenses;

import 'package.dart';
import 'package:collection/collection.dart';
// ignore: implementation_imports
import 'package:pana/src/license_detection/license_detector.dart' as detector;

Future<String> generateMarkdownTable(
  List<Package> packages,
  Map<String, String> meta,
) async {
  final licenses = <int, String>{};
  for (var i = 0; i < packages.length; i++) {
    // * [PANA's default threshold value](https://github.com/dart-lang/pana/blob/b598d45051ba4e028e9021c2aeb9c04e4335de76/lib/src/license.dart#L48)
    const defaultDetectionThreshold = 0.95;
    final package = packages[i];
    final licenseString = package.license;
    if (licenseString == null) continue;
    try {
      final result = await detector.detectLicense(
        licenseString,
        defaultDetectionThreshold,
      );
      final rawLicense = result.matches
          // ignore: invalid_use_of_visible_for_testing_member
          .map((match) => match.license.identifier)
          .toSet();

      const licenseException = {'hive': 'Apache-2.0', 'rxdart': 'Apache-2.0'};
      if (rawLicense.isEmpty && licenseException[package.name] != null) {
        rawLicense.add(licenseException[package.name]!);
      }
      // licenses[i] = rawLicense.join(', ');
      licenses[i] = rawLicense.firstOrNull ?? 'unknown';
    } catch (e) {
      final errorMessage = '''[${package.name}] Failed to detect license: $e''';
      print('\n$errorMessage');
    }
  }

  final output = packages
      .mapIndexed(
        (index, package) => {
          'Item #': index + 1,
          'Name, Version, Website':
              '${package.name}<br>${package.version}<br>${package.repository ?? package.homepage}',
          'License': licenses[index] ?? 'unknown',
          'Description of Use': package.description.replaceAll('\n', ''),
          'Used for Security Function':
              meta[package.name]?.replaceAll('\n', '<br>') ?? 'N/A',
        },
      )
      .toList();

  // Extract column names (headers) from the JSON data
  final headers = output.firstOrNull?.keys.toList();

  // Create the Markdown table header row
  final headerRow = '| ${headers?.join(' | ')} |';

  // Create the Markdown separator row
  final separatorRow = '| ${headers?.map((_) => '---').join(' | ')} |';

  // Create the Markdown table rows
  final tableRows = output.map((data) {
    final rowValues =
        '| ${headers?.map((header) => data[header]).join(' | ')} |';
    return rowValues;
  }).join('\n');

  // Combine all rows to create the Markdown table
  final markdown = '$headerRow\n$separatorRow\n$tableRows';

  return markdown;
}
