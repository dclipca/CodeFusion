import 'dart:convert';
import 'dart:io';

import 'package:code_fusion/src/custom_colors.dart';
import 'package:code_fusion/src/home_view/file_list_panel.dart';
import 'package:code_fusion/src/home_view/state_providers.dart';
import 'package:code_fusion/src/settings/settings_controller.dart';
import 'package:code_fusion/src/settings/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

class HomeView extends ConsumerStatefulWidget {
  const HomeView({Key? key, required this.controller}) : super(key: key);
  final SettingsController controller;
  static const routeName = '/';

  @override
  _HomeViewState createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  List<String> _directories = [];
  Set<String> _expandedDirectories = Set<String>();
  Map<String, List<String>> _filesByDirectory = {};
  String _selectedDirectory = '';

  Set<String> _selectedFiles = {};
  Map<String, dynamic> _fileSvgIconMetadata = {};
  Map<String, dynamic> _folderSvgIconMetadata = {};
  int _estimatedTokenCount = 0;
  bool _isCopied = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final fileMetadata = ref.watch(fileSvgIconMetadataLoaderProvider);
    final folderMetadata = ref.watch(folderSvgIconMetadataLoaderProvider);

    final customColors = Theme.of(context).extension<CustomColors>();

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
            child: Row(
              children: [
                // Directory List
                Expanded(
                  flex: 1,
                  child: Container(
                    color: customColors?.leftPanelColor ??
                        Theme.of(context).scaffoldBackgroundColor,
                    child: _directories.isEmpty
                        ? Center(
                            child: ElevatedButton(
                            onPressed: _addDirectory,
                            child: const Text("Add Directory"),
                          ))
                        : _buildDirectoryList(),
                  ),
                ),
                // File List for the Selected Directory
                Expanded(
                  flex: 3,
                  child: fileMetadata.when(
                    data: (fileSvgIconMetadata) => folderMetadata.when(
                      data: (folderSvgIconMetadata) => FileListPanel(
                        files: _filesByDirectory[_selectedDirectory] ?? [],
                        selectedFiles: _selectedFiles,
                        fileSvgIconMetadata: fileSvgIconMetadata,
                        folderSvgIconMetadata: folderSvgIconMetadata,
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _selectedFiles = newSelection;
                            _updateEstimatedTokenCount();
                          });
                        },
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) =>
                          Center(child: Text('Error loading folder icons')),
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) =>
                        Center(child: Text('Error loading file icons')),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: _selectedFiles.isNotEmpty
                  ? _copySelectedFilesToClipboard
                  : null,
              child: _isCopied
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check),
                        SizedBox(width: 8),
                        Text('Copied!')
                      ],
                    )
                  : _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(
                          'Copy code (~${_formatTokens(_estimatedTokenCount)} tokens)'),
            ),
          ),
        ],
      ),
    );
  }

  void _addDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      await _handleFolderSelected(selectedDirectory);
    }
  }

  Widget _buildDirectoryList() {
    return ListView.builder(
      itemCount: _directories.length,
      itemBuilder: (context, index) {
        String directoryPath = _directories[index];
        bool isExpanded = _expandedDirectories.contains(directoryPath);

        return ListTile(
          title: Text(path.basename(directoryPath)),
          trailing: IconButton(
            icon:
                isExpanded ? Icon(Icons.expand_less) : Icon(Icons.expand_more),
            onPressed: () {
              setState(() {
                if (isExpanded) {
                  _expandedDirectories.remove(directoryPath);
                } else {
                  _expandedDirectories.add(directoryPath);
                }
              });
            },
          ),
          selected: directoryPath == _selectedDirectory,
          onTap: () {
            if (isExpanded) {
              // If the directory is expanded, collapse it
              _expandedDirectories.remove(directoryPath);
            } else {
              // Expand the directory and optionally load its contents
              _expandedDirectories.add(directoryPath);
              // Optional: Load the directory's contents if not already loaded
            }
            setState(() {
              _selectedDirectory = directoryPath;
            });
          },
        );
      },
    );
  }

  Future<void> _handleFolderSelected(String directory) async {
    setState(() {
      _isLoading = true;
      if (!_directories.contains(directory)) {
        _directories.add(directory); // Add the new directory to the list
      }
      // Now handle files for the selected directory
      _selectedDirectory = directory; // Set the selected directory
    });

    // Load files for the newly added directory
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
      _filesByDirectory[directory] = folders
        ..addAll(files); // Associate files with their directory
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
