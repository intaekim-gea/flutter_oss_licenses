import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_pubspec_licenses/dart_pubspec_licenses.dart' as oss;
import 'package:path/path.dart' as path;

main(List<String> args) async {
  final parser = getArgParser();
  final results = parser.parse(args);

  try {
    if (results['help']) {
      printUsage(parser);
      return 0;
    } else if (results['input'] == null) {
      printUsage(parser);
      return 3;
    } else if (results.rest.isNotEmpty) {
      print('WARNING: extra parameter given\n');
      printUsage(parser);
      return 3;
    }

    final inputFilePath = results['input'];
    final outputFilePath =
        results['output'] ?? path.join('.', 'oss_licenses.md');
    final metaFilePath = results['meta'];

    final json = await File(inputFilePath).readAsString();
    final packages = List<oss.Package>.from(
      jsonDecode(json).map((e) => oss.Package.fromJson(e)),
    );
    var meta = <String, String>{};
    if (metaFilePath != null) {
      final metaJson = await File(metaFilePath).readAsString();
      final intermediate = Map<String, List<dynamic>>.from(
        jsonDecode(metaJson),
      );
      for (var entry in intermediate.entries) {
        for (var name in entry.value) {
          meta[name] = entry.key;
        }
      }
    }

    final output = await oss.generateMarkdownTable(packages, meta);

    if (path.dirname(outputFilePath) != '.') {
      Directory.fromUri(Uri.directory(path.dirname(outputFilePath))).createSync(
        recursive: true,
      );
    }
    await File(outputFilePath).writeAsString(output);
    return 0;
  } catch (e, s) {
    stderr.writeln('$e: $s');
    return 4;
  }
}

ArgParser getArgParser() {
  final parser = ArgParser();

  parser.addOption(
    'input',
    abbr: 'i',
    defaultsTo: null,
    help:
        'Specify input file path of JSON file that is including list of Package.',
  );
  parser.addOption('output', abbr: 'o', defaultsTo: null, help: '''
Specify output file path.
The default output file: oss_licenses.md
''');
  parser.addOption(
    'meta',
    abbr: 'm',
    defaultsTo: null,
    help: '''
Metafile to be added to the table. JSON format.
e.g.) 
  {
    "Yes; Security Data; Personal Data, Sensitive Personal Data\n\n(Identifiable, Diagnostic)": [
        "flutter_lints",
        "source_span"
    ],
    "Yes; Personal Data\n\n(Diagnostic)": [
        "term_glyph"
    ]
  } 
''',
  );
  parser.addFlag('help',
      abbr: 'h', defaultsTo: false, negatable: false, help: 'Show the help.');

  return parser;
}

void printUsage(ArgParser parser) {
  print('Usage: ${path.basename(Platform.script.toString())} [OPTION]\n');
  print(parser.usage);
}
