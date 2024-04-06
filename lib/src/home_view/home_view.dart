import 'dart:convert';
import 'dart:io';

import 'package:code_fusion/src/custom_colors.dart';
import 'package:code_fusion/src/settings/settings_controller.dart';
import 'package:code_fusion/src/settings/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as path;

// Provider for managing the list of directories
final directoriesProvider = StateProvider<List<String>>((ref) => []);

// Provider for managing the set of selected files
final selectedFilesProvider = StateProvider<Set<String>>((ref) => {});

// Provider for managing the loading state
final isLoadingProvider = StateProvider<bool>((ref) => false);

// Provider for managing the metadata of file icons
final fileSvgIconMetadataProvider =
    StateProvider<Map<String, dynamic>>((ref) => {});

// Provider for managing the metadata of folder icons
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

class FileListPanel extends StatefulWidget {
  final List<String> files;
  final Set<String> selectedFiles;
  final Map<String, dynamic> fileSvgIconMetadata;
  final Map<String, dynamic> folderSvgIconMetadata;
  final Function(Set<String>) onSelectionChanged;

  const FileListPanel(
      {super.key,
      required this.files,
      required this.selectedFiles,
      required this.fileSvgIconMetadata,
      required this.folderSvgIconMetadata,
      required this.onSelectionChanged});

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

        Widget iconWidget = isDirectory
            ? folderIconWidget(fileName, widget.folderSvgIconMetadata)
            : fileIconWidget(fileName, widget.fileSvgIconMetadata);

        double leftPadding = _shouldBeIndented(filePath) ? 20.0 : 0.0;
        bool isSelected = widget.selectedFiles.contains(filePath) ||
            (isDirectory && _checkIfFolderSelected(filePath));

        return Padding(
          padding: EdgeInsets.only(left: leftPadding),
          child: ListTile(
            dense: true,
            leading: iconWidget,
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
