import 'dart:io';
import 'dart:convert';

import 'package:code_fusion/src/home_view/utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final isLoadingProvider = StateProvider<bool>((ref) => false);
final fileSvgIconMetadataProvider =
    StateProvider<Map<String, dynamic>>((ref) => {});
final folderSvgIconMetadataProvider =
    StateProvider<Map<String, dynamic>>((ref) => {});
final fileSvgIconMetadataLoaderProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final jsonString =
      await rootBundle.loadString('assets/icons/files/metadata.json');
  return json.decode(jsonString) as Map<String, dynamic>;
});
final folderSvgIconMetadataLoaderProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final jsonString =
      await rootBundle.loadString('assets/icons/folders/metadata.json');
  return json.decode(jsonString) as Map<String, dynamic>;
});
final directoriesProvider = StateProvider<List<String>>((ref) => []);
final selectedDirectoryProvider = StateProvider<String?>((ref) => null);
final directoryContentsProvider = StateProvider<List<String>>((ref) => []);
final selectedFilesProvider = StateProvider<Set<String>>((ref) => {});
final directoryContentsLoaderProvider =
    FutureProvider.family<List<String>, String>((ref, directoryPath) async {
  List<String> contents = await loadDirectoryContents(directoryPath);
  return contents;
});
