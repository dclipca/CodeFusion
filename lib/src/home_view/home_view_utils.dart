import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

String iconNameFromFileName(
    String fileName, Map<String, dynamic> svgIconMetadata) {
  String extension = fileName.split('.').last.toLowerCase();
  String iconName = svgIconMetadata['defaultIcon']['name']; // Default icon name
  List<dynamic> icons = svgIconMetadata['icons'];

  for (var icon in icons) {
    List<dynamic> fileExtensions =
        icon['fileExtensions'] as List<dynamic>? ?? [];
    List<dynamic> fileNames = icon['fileNames'] as List<dynamic>? ?? [];

    if (fileExtensions.contains(extension) ||
        fileNames.contains(fileName.toLowerCase())) {
      iconName = icon['name'];
      break; // Found a specific icon
    }
  }

  return iconName;
}

Widget fileIconWidget(String fileName, Map<String, dynamic> svgIconMetadata) {
  String iconName = iconNameFromFileName(fileName, svgIconMetadata);
  String assetPath = 'assets/icons/files/$iconName.svg';

  return SvgPicture.asset(assetPath, width: 24, height: 24);
}

String iconNameFromFolderName(
    Map<String, dynamic> folderSvgIconMetadata, String folderName) {
  String iconName = folderSvgIconMetadata['defaultIcon']['name'];
  List<dynamic> icons = folderSvgIconMetadata['icons'];

  for (var icon in icons) {
    List<dynamic> folderNames = icon['folderNames'] as List<dynamic>? ?? [];

    if (folderNames.contains(folderName.toLowerCase())) {
      iconName = icon['name'];
      break;
    }
  }

  return iconName;
}

Widget folderIconWidget(
    String folderName, Map<String, dynamic> folderSvgIconMetadata) {
  String iconName = iconNameFromFolderName(folderSvgIconMetadata, folderName);
  String assetPath = 'assets/icons/folders/$iconName.svg';

  return SvgPicture.asset(assetPath, width: 24, height: 24);
}