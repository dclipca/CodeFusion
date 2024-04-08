import 'dart:io';
import 'package:code_fusion/src/home_view/state_providers.dart';
import 'package:code_fusion/src/home_view/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

class FileListPanel extends ConsumerWidget {
  final List<String> files;
  final Map<String, dynamic> fileSvgIconMetadata;
  final Map<String, dynamic> folderSvgIconMetadata;
  final Function(Set<String>) onSelectionChanged;

  const FileListPanel({
    Key? key,
    required this.files,
    required this.fileSvgIconMetadata,
    required this.folderSvgIconMetadata,
    required this.onSelectionChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Assuming 'files' is already available and contains the root level files/folders
    final combinedFiles = _generateCombinedFilesList(ref, files, 0);

    return ListView.builder(
      itemCount: combinedFiles.length,
      itemBuilder: (context, index) {
        final item = combinedFiles[index];
        final filePath = item['path'];
        final depth = item['depth'];
        final isDirectory = item['isDirectory'];
        final fileName = path.basename(filePath);
        final isSelected = ref.watch(selectedFilesProvider).contains(filePath);

        return ListTile(
          dense: true,
          key: ValueKey(filePath),
          title: Text(fileName),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDirectory)
                IconButton(
                  icon: Icon(isExpanded(ref, filePath)
                      ? Icons.expand_less
                      : Icons.expand_more),
                  onPressed: () => toggleFolderExpansion(ref, filePath),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              Padding(
                // Adjusted padding logic here
                padding: EdgeInsets.only(
                    left: 20.0 * depth + (isDirectory ? 0 : 20.0)),
                child: isDirectory
                    ? folderIconWidget(fileName, folderSvgIconMetadata)
                    : fileIconWidget(fileName, fileSvgIconMetadata),
              ),
            ],
          ),
          tileColor: isSelected ? Colors.green.withOpacity(0.3) : null,
          onTap: () => handleFileSelection(ref, filePath),
        );
      },
    );
  }

  bool isExpanded(WidgetRef ref, String filePath) {
    return ref.watch(expandedFoldersProvider).contains(filePath);
  }

  void toggleFolderExpansion(WidgetRef ref, String filePath) {
    final currentSet = ref.read(expandedFoldersProvider.notifier).state;
    if (currentSet.contains(filePath)) {
      currentSet.remove(filePath);
    } else {
      currentSet.add(filePath);
      // Triggering a refresh on the folderContentsProvider if you need to fetch new data
      ref.refresh(folderContentsProvider(filePath));
    }
    // Explicitly setting the state to a new instance of the set to ensure notification
    ref.read(expandedFoldersProvider.notifier).state = {...currentSet};
  }

  void handleFileSelection(WidgetRef ref, String filePath) {
    final currentSelectedFiles = ref.read(selectedFilesProvider.notifier).state;
    final isDirectory = FileSystemEntity.isDirectorySync(filePath);

    if (currentSelectedFiles.contains(filePath)) {
      // If the item is already selected, remove it and its children if it's a directory
      _recursiveDeselection(ref, filePath, currentSelectedFiles);
    } else {
      // If the item is not selected, add it and its children if it's a directory
      _recursiveSelection(ref, filePath, currentSelectedFiles);
    }

    // Update the state with the new selection set
    ref.read(selectedFilesProvider.notifier).state = currentSelectedFiles;
    onSelectionChanged(currentSelectedFiles);
  }

  void _recursiveSelection(
      WidgetRef ref, String filePath, Set<String> selectionSet) {
    final isDirectory = FileSystemEntity.isDirectorySync(filePath);
    selectionSet.add(filePath);

    if (isDirectory) {
      final folderContents =
          ref.read(folderContentsProvider(filePath)).asData?.value ?? [];
      for (final childPath in folderContents) {
        _recursiveSelection(ref, childPath, selectionSet);
      }
    }
  }

  void _recursiveDeselection(
      WidgetRef ref, String filePath, Set<String> selectionSet) {
    final isDirectory = FileSystemEntity.isDirectorySync(filePath);
    selectionSet.remove(filePath);

    if (isDirectory) {
      final folderContents =
          ref.read(folderContentsProvider(filePath)).asData?.value ?? [];
      for (final childPath in folderContents) {
        _recursiveDeselection(ref, childPath, selectionSet);
      }
    }
  }

  List<Map<String, dynamic>> _generateCombinedFilesList(
      WidgetRef ref, List<String> files, int depth) {
    List<Map<String, dynamic>> combinedList = [];
    for (final filePath in files) {
      final isDirectory = FileSystemEntity.isDirectorySync(filePath);
      final isExpanded = ref.watch(expandedFoldersProvider).contains(filePath);
      combinedList
          .add({'path': filePath, 'depth': depth, 'isDirectory': isDirectory});

      if (isDirectory && isExpanded) {
        final folderContents =
            ref.watch(folderContentsProvider(filePath)).asData?.value ?? [];
        combinedList
            .addAll(_generateCombinedFilesList(ref, folderContents, depth + 1));
      }
    }
    return combinedList;
  }
}
