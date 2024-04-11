import 'dart:convert';
import 'dart:io';

import 'package:code_fusion/src/custom_colors.dart';
import 'package:code_fusion/src/home_view/file_list_panel.dart';
import 'package:code_fusion/src/home_view/state_providers.dart';
import 'package:code_fusion/src/home_view/utils.dart';
import 'package:code_fusion/src/settings/settings_controller.dart';
import 'package:code_fusion/src/settings/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key, required this.controller});
  final SettingsController controller;
  static const routeName = '/';

  @override
  HomeViewState createState() => HomeViewState();
}

class HomeViewState extends ConsumerState<HomeView> {
  List<String> _directories = [];
  Map<String, List<String>> _filesByDirectory = {};
  String _selectedDirectory = '';

  Set<String> _selectedFiles = {};
  bool _isCopied = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  void selectDirectory(WidgetRef ref, String directoryPath) {
    ref.read(selectedDirectoryProvider.state).state = directoryPath;
    // Trigger loading of directory contents
    ref.refresh(directoryContentsLoaderProvider(directoryPath));
  }

  @override
  Widget build(BuildContext context) {
    final fileMetadata = ref.watch(fileSvgIconMetadataLoaderProvider);
    final folderMetadata = ref.watch(folderSvgIconMetadataLoaderProvider);
    final estimatedTokenCount = ref.watch(estimatedTokenCountProvider);

    // Check if a directory is selected or if the directory is empty
    bool shouldShowPickDirectory = _selectedDirectory.isEmpty ||
        (_filesByDirectory[_selectedDirectory]?.isEmpty ?? true);

    return Scaffold(
      appBar: AppBar(
        title: _selectedDirectory.isNotEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Consumer(builder: (context, ref, _) {
                    final folderMetadataAsyncValue =
                        ref.watch(folderSvgIconMetadataLoaderProvider);
                    return folderMetadataAsyncValue.when(
                      data: (folderSvgIconMetadata) => ElevatedButton(
                        onPressed: _addDirectory,
                        child: Row(
                          children: [
                            folderIconWidget(path.basename(_selectedDirectory),
                                folderSvgIconMetadata),
                            const SizedBox(width: 8),
                            Text(path.basename(_selectedDirectory)),
                          ],
                        ),
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (error, stack) => const Icon(Icons.error),
                    );
                  }),
                ],
              )
            : const SizedBox
                .shrink(), // If no directory is selected, show an empty widget
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
            child: shouldShowPickDirectory
                ? Center(
                    child: ElevatedButton(
                      onPressed: _addDirectory,
                      child: const Text("Pick Directory"),
                    ),
                  )
                : fileMetadata.when(
                    data: (fileSvgIconMetadata) => folderMetadata.when(
                      data: (folderSvgIconMetadata) => FileListPanel(
                        files: _filesByDirectory[_selectedDirectory] ?? [],
                        fileSvgIconMetadata: fileSvgIconMetadata,
                        folderSvgIconMetadata: folderSvgIconMetadata,
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _selectedFiles = newSelection;
                          });
                        },
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => const Center(
                          child: Text('Error loading folder icons')),
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) =>
                        const Center(child: Text('Error loading file icons')),
                  ),
          ),
          if (_selectedDirectory
              .isNotEmpty) // Only show the button when a directory is selected
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: _selectedFiles.isNotEmpty
                    ? _copySelectedFilesToClipboard
                    : null,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Conditional icon based on the _isCopied state
                    _isCopied
                        ? const Icon(Icons.check, size: 16.0)
                        : const Icon(Icons.content_copy, size: 16.0),
                    const SizedBox(width: 8),
                    _isCopied
                        ? const Text('Copied!')
                        : _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                'Copy code (~${_formatTokens(estimatedTokenCount)} tokens)',
                              ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _addDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      // Directly set the UI state for selected directory to refresh the UI
      setState(() {
        _selectedDirectory = selectedDirectory;
        _isLoading = true; // Indicate loading UI
      });

      // Load directory contents here and update UI state accordingly
      try {
        final contents = await loadDirectoryContents(selectedDirectory);
        setState(() {
          _filesByDirectory[selectedDirectory] = contents;
        });
      } catch (error) {
        // Handle error (e.g., show a toast or log the error)
      } finally {
        setState(() {
          _isLoading = false; // Reset loading UI
        });
      }
    }
  }

  void _copySelectedFilesToClipboard() async {
    String combinedContent = '';
    for (var filePath in _selectedFiles) {
      // No need to extract the file name from the path, as we'll use the full path
      var fileEntity = FileSystemEntity.typeSync(filePath);
      if (fileEntity == FileSystemEntityType.file) {
        try {
          final file = File(filePath);
          String fileContent = await file.readAsString();
          // Use filePath for START and END markers instead of just the fileName
          combinedContent +=
              '### START OF FILE: $filePath ###\n$fileContent\n### END OF FILE: $filePath ###\n\n';
        } catch (e) {
          // Handle the case where the file cannot be read (if necessary)
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

  String _formatTokens(int tokens) {
    if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}k';
    }
    return tokens.toString();
  }
}
