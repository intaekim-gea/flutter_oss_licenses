library dart_oss_licenses;

import 'package.dart';
import 'package:collection/collection.dart';

Future<String> generateMarkdownTable(
  List<Package> packages,
  Map<String, String> meta,
) async {
  final output = packages
      .mapIndexed(
        (index, package) => {
          'Item #': index + 1,
          'Name, Version, Website':
              '${package.name}<br>${package.version}<br>${package.repository ?? package.homepage}<br>',
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
