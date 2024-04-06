import 'dart:convert';
import 'dart:io';

import 'package:code_fusion/src/settings/settings_controller.dart';
import 'package:code_fusion/src/settings/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as path;

String iconNameFromFileName(String fileName, Map<String, dynamic> svgIconMetadata) {
  String extension = fileName.split('.').last.toLowerCase();
  String iconName = svgIconMetadata['defaultIcon']['name']; // Default icon name
  List<dynamic> icons = svgIconMetadata['icons'];

  for (var icon in icons) {
    List<dynamic> fileExtensions = icon['fileExtensions'] as List<dynamic>? ?? [];
    List<dynamic> fileNames = icon['fileNames'] as List<dynamic>? ?? [];

    if (fileExtensions.contains(extension) || fileNames.contains(fileName.toLowerCase())) {
      iconName = icon['name'];
      break; // Found a specific icon, break the loop
    }
  }

  return iconName;
}

// Example Widget to display an SVG based on the file name
Widget fileIconWidget(String fileName, Map<String, dynamic> svgIconMetadata) {
  String iconName = iconNameFromFileName(fileName, svgIconMetadata);
  String assetPath = 'assets/icons/files/$iconName.svg';

  return SvgPicture.asset(assetPath, width: 24, height: 24);
}

class HomeView extends StatefulWidget {
  const HomeView({Key? key, required this.controller}) : super(key: key);

  final SettingsController controller;

  static const routeName = '/';

  @override
  _HomeViewState createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  List<String> _files = [];
  Set<String> _selectedFiles = {};
  Map<String, dynamic> _svgIconMetadata = {};
  int _estimatedTokenCount = 0;
  bool _isCopied = false; // Flag to indicate if the code has been copied
  bool _isLoading =
      false; // Flag to indicate loading state during async operations

  @override
  void initState() {
    super.initState();
    _loadSvgIconMetadata();
  }

  Future<void> _loadSvgIconMetadata() async {
    final jsonString =
        await rootBundle.loadString('assets/icons/files/metadata.json');
    setState(() {
      _svgIconMetadata = json.decode(jsonString);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.restorablePushNamed(context, SettingsView.routeName);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _files.isEmpty
                ? Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        String? selectedDirectory =
                            await FilePicker.platform.getDirectoryPath();
                        if (selectedDirectory != null) {
                          await _handleFolderSelected(selectedDirectory);
                        }
                      },
                      child: const Text('Pick a Directory'),
                    ),
                  )
                : FileListPanel(
                    files: _files,
                    selectedFiles: _selectedFiles,
                    svgIconMetadata: _svgIconMetadata,
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _selectedFiles = newSelection;
                        _updateEstimatedTokenCount();
                      });
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedFiles.isNotEmpty
                    ? _copySelectedFilesToClipboard
                    : null,
                child: _isCopied
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check),
                          Text(' Copied!'),
                        ],
                      )
                    : _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ) // Show loading indicator
                        : Text(
                            'Copy code (~${_formatTokens(_estimatedTokenCount)} tokens)'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleFolderSelected(String directory) async {
    setState(() {
      _isLoading = true;
    });

    Directory dir = Directory(directory);
    List<String> folders = [];
    List<String> files = [];

    await for (var entity in dir.list(recursive: false)) {
      if (entity is Directory) {
        folders.add(entity.path);
      } else if (entity is File && await isUtf8Encoded(entity.path)) {
        files.add(entity.path);
      }
    }

    setState(() {
      _files = folders..addAll(files);
      _isLoading = false;
    });
  }

  Future<bool> isUtf8Encoded(String filePath) async {
    File file = File(filePath);
    try {
      await file.openRead(0, 1024).transform(utf8.decoder).first;
      return true;
    } catch (e) {
      return false;
    }
  }

  void _updateEstimatedTokenCount() async {
    setState(() {
      _isLoading = true;
    });

    int tokenCount = 0;
    for (var filePath in _selectedFiles) {
      final fileSystemEntity = FileSystemEntity.typeSync(filePath);
      if (fileSystemEntity == FileSystemEntityType.file) {
        try {
          final file = File(filePath);
          String fileContent = await file.readAsString();
          tokenCount += estimateTokenCount(fileContent);
        } catch (e) {
          // Ignoring files that cannot be read as UTF-8
        }
      }
    }

    setState(() {
      _estimatedTokenCount = tokenCount;
      _isLoading = false;
    });
  }

  void _copySelectedFilesToClipboard() async {
    String combinedContent = '';
    for (var filePath in _selectedFiles) {
      var fileEntity = FileSystemEntity.typeSync(filePath);
      if (fileEntity == FileSystemEntityType.file) {
        try {
          final file = File(filePath);
          String fileContent = await file.readAsString();
          combinedContent += fileContent + '\n\n';
        } catch (e) {
          // Ignoring files that cannot be read as UTF-8
        }
      }
    }
    if (combinedContent.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: combinedContent));
      setState(() {
        _isCopied = true;
      });
      Future.delayed(const Duration(seconds: 2), () {
        setState(() {
          _isCopied = false;
        });
      });
    }
  }

  static int estimateTokenCount(String prompt) {
    int baseWordCount = prompt.length ~/ 5;
    var punctuationRegex = RegExp(r'[,.!?;:]');
    int punctuationCount = punctuationRegex.allMatches(prompt).length;
    double subwordAdjustmentFactor = 1.1;
    int estimatedTokens =
        ((baseWordCount + punctuationCount) * subwordAdjustmentFactor).round();
    return estimatedTokens;
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}k';
    }
    return tokens.toString();
  }
}

class FileListPanel extends StatefulWidget {
  final List<String> files;
  final Set<String> selectedFiles;
  final Map<String, dynamic> svgIconMetadata;
  final Function(Set<String>) onSelectionChanged;

  const FileListPanel(
      {Key? key,
      required this.files,
      required this.selectedFiles,
      required this.svgIconMetadata,
      required this.onSelectionChanged})
      : super(key: key);

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
            Directory(filePath).statSync().type ==
                FileSystemEntityType.directory;

        Widget fileIcon = isDirectory
            ? Icon(Icons.folder) // Use a folder icon for directories
            : fileIconWidget(
                fileName, widget.svgIconMetadata); // Use the function for files

        double leftPadding = _shouldBeIndented(filePath) ? 20.0 : 0.0;
        bool isSelected = widget.selectedFiles.contains(filePath) ||
            (isDirectory && _checkIfFolderSelected(filePath));

        return Padding(
          padding: EdgeInsets.only(left: leftPadding),
          child: ListTile(
            leading: fileIcon,
            title: Text(fileName),
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
    return _expandedFolders.containsKey(parentDir) &&
        _expandedFolders[parentDir]!;
  }

  void _handleFolderTap(String folderPath) {
    final isExpanded = _expandedFolders[folderPath] ?? false;
    setState(() {
      _expandedFolders[folderPath] = !isExpanded;
      if (!isExpanded) {
        final directory = Directory(folderPath);
        var entities = directory.listSync(recursive: false);
        List<String> folders = [];
        List<String> files = [];

        for (var entity in entities) {
          if (entity is Directory) {
            folders.add(entity.path);
          } else if (entity is File) {
            files.add(entity.path);
          }
        }

        var combinedList = folders..addAll(files);
        widget.files
            .insertAll(widget.files.indexOf(folderPath) + 1, combinedList);
      } else {
        List<String> contentsToRemove = [];
        for (var i = widget.files.indexOf(folderPath) + 1;
            i < widget.files.length;
            i++) {
          if (widget.files[i].startsWith(folderPath)) {
            contentsToRemove.add(widget.files[i]);
          } else {
            break;
          }
        }
        widget.files.removeWhere((path) => contentsToRemove.contains(path));
      }
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
    final directory = Directory(folderPath);
    var entities = directory.listSync(recursive: true);
    Set<String> newSelection = Set.from(widget.selectedFiles);

    bool isCurrentlySelected = _checkIfFolderSelected(folderPath);
    for (var entity in entities) {
      if (entity is File) {
        if (isCurrentlySelected) {
          newSelection.remove(entity.path);
        } else {
          newSelection.add(entity.path);
        }
      }
    }

    widget.onSelectionChanged(newSelection);
  }

  bool _checkIfFolderSelected(String folderPath) {
    final directory = Directory(folderPath);
    var entities = directory.listSync(recursive: true);

    for (var entity in entities) {
      if (entity is File && !widget.selectedFiles.contains(entity.path)) {
        return false;
      }
    }
    return true; // All files in the folder are selected
  }
}
