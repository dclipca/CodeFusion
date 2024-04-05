// svg_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

// Provider for loading SVG metadata from a JSON file
final svgMetadataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final jsonString = await rootBundle.loadString('assets/icons/programming_languages/metadata.json');
  return json.decode(jsonString);
});

// Provider for loading an SVG asset based on the metadata
// svg_providers.dart
final svgLoaderProvider = FutureProvider.family<SvgPicture?, String>((ref, String extension) async {
  final metadata = await ref.watch(svgMetadataProvider.future);
  if (metadata.containsKey(extension)) {
    final String deviconName = metadata[extension]['deviconName'];
    return SvgPicture.asset('assets/icons/programming_languages/$deviconName/$deviconName-original.svg', width: 20, height: 20);
  }
  // Return null or a specific error signal if not found
  return null;
});