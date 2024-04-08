import 'dart:io';

import 'package:code_fusion/src/home_view/state_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

String iconNameFromFileName(
    String fileName, Map<String, dynamic>? svgIconMetadata) {
  if (svgIconMetadata == null) return 'default_icon_name';
  String extension = fileName.split('.').last.toLowerCase();
  String iconName =
      svgIconMetadata['defaultIcon']?['name'] ?? 'default_icon_name';
  List<dynamic> icons = svgIconMetadata['icons'] ?? [];

  for (var icon in icons) {
    List<dynamic> fileExtensions =
        icon['fileExtensions'] as List<dynamic>? ?? [];
    List<dynamic> fileNames = icon['fileNames'] as List<dynamic>? ?? [];
    if (fileExtensions.contains(extension) ||
        fileNames.contains(fileName.toLowerCase())) {
      iconName = icon['name'] ?? iconName; // Use existing iconName as fallback
      break;
    }
  }
  return iconName;
}

Widget fileIconWidget(String fileName, Map<String, dynamic>? svgIconMetadata) {
  String iconName = iconNameFromFileName(fileName, svgIconMetadata);
  String assetPath = 'assets/icons/files/$iconName.svg';
  return SvgPicture.asset(assetPath, width: 24, height: 24);
}

String iconNameFromFolderName(
    Map<String, dynamic>? folderSvgIconMetadata, String folderName) {
  if (folderSvgIconMetadata == null) return 'default_folder_icon_name';
  String iconName = folderSvgIconMetadata['defaultIcon']?['name'] ??
      'default_folder_icon_name';
  List<dynamic> icons = folderSvgIconMetadata['icons'] ?? [];

  for (var icon in icons) {
    List<dynamic> folderNames = icon['folderNames'] as List<dynamic>? ?? [];
    if (folderNames.contains(folderName.toLowerCase())) {
      iconName = icon['name'] ?? iconName;
      break;
    }
  }
  return iconName;
}

Widget folderIconWidget(
    String folderName, Map<String, dynamic>? folderSvgIconMetadata) {
  String iconName = iconNameFromFolderName(folderSvgIconMetadata, folderName);
  String assetPath = 'assets/icons/folders/$iconName.svg';
  return SvgPicture.asset(assetPath, width: 24, height: 24);
}

Future<List<String>> loadDirectoryContents(String directoryPath) async {
  Directory directory = Directory(directoryPath);
  List<String> contents = [];
  await for (var entity in directory.list()) {
    contents.add(entity.path);
  }
  return contents;
}

String normalizePath(String path) {
  // Normalize path to avoid issues with trailing slashes and case sensitivity.
  return path.replaceAll('\\', '/').toLowerCase().trim();
}