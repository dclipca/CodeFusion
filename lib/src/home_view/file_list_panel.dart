import 'dart:io';

import 'package:code_fusion/src/home_view/utils.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class FileListPanel extends StatefulWidget {
  final List<String> files;
  final Set<String> selectedFiles;
  final Map<String, dynamic> fileSvgIconMetadata;
  final Map<String, dynamic> folderSvgIconMetadata;
  final Function(Set<String>) onSelectionChanged;

  const FileListPanel({
    super.key,
    required this.files,
    required this.selectedFiles,
    required this.fileSvgIconMetadata,
    required this.folderSvgIconMetadata,
    required this.onSelectionChanged,
  });

  @override
  _FileListPanelState createState() => _FileListPanelState();
}

class _FileListPanelState extends State<FileListPanel> {
  Map<String, bool> _expandedFolders = {};

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.files.length,
      itemBuilder: (context, index) {
        String filePath = widget.files[index];
        String fileName = path.basename(filePath);
        bool isDirectory = Directory(filePath).existsSync() &&
            Directory(filePath).statSync().type == FileSystemEntityType.directory;

        Widget iconWidget = isDirectory
            ? folderIconWidget(fileName, widget.folderSvgIconMetadata)
            : fileIconWidget(fileName, widget.fileSvgIconMetadata);

        bool isExpanded = _expandedFolders[filePath] ?? false;

        Widget trailingIcon = isDirectory
            ? GestureDetector(
                onTap: () => _handleChevronTap(filePath),
                child: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
              )
            : SizedBox.shrink();

        double leftPadding = _shouldBeIndented(filePath) ? 20.0 : 0.0;
        bool isSelected = widget.selectedFiles.contains(filePath) ||
            (isDirectory && _checkIfFolderSelected(filePath));

        return Padding(
          padding: EdgeInsets.only(left: leftPadding),
          child: ListTile(
            dense: true,
            leading: iconWidget,
            title: Text(fileName),
            trailing: trailingIcon,
            tileColor: isSelected ? Colors.green.withOpacity(0.3) : null,
            onTap: () {
              if (!isDirectory) {
                _toggleFileSelection(filePath);
              } else {
                _toggleFolderSelection(filePath);
              }
            },
          ),
        );
      },
    );
  }

  bool _shouldBeIndented(String filePath) {
    var parentDir = path.dirname(filePath);
    return _expandedFolders.containsKey(parentDir) && _expandedFolders[parentDir]!;
  }

  void _handleChevronTap(String folderPath) {
    final isExpanded = _expandedFolders[folderPath] ?? false;
    setState(() {
      _expandedFolders[folderPath] = !isExpanded;
      // Optionally implement logic here to dynamically load or unload folder contents
    });
  }

  void _toggleFileSelection(String filePath) {
    Set<String> newSelection = Set.from(widget.selectedFiles);
    if (newSelection.contains(filePath)) {
      newSelection.remove(filePath);
    } else {
      newSelection.add(filePath);
    }
    widget.onSelectionChanged(newSelection);
  }

  void _toggleFolderSelection(String folderPath) {
    // Implement your logic here for recursive folder selection
    // This should iterate through the folder's contents, selecting or deselecting them as appropriate
  }

  bool _checkIfFolderSelected(String folderPath) {
    // Implement your logic here to check if a folder is selected
    // This likely involves checking if all files within the folder are currently selected
    return false; // Placeholder return
  }

  // Add any additional methods or logic required for folder expansion and content selection
}