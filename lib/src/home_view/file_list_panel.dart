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
    super.key,
    required this.files,
    required this.fileSvgIconMetadata,
    required this.folderSvgIconMetadata,
    required this.onSelectionChanged,
  });

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

        return Container(
          padding: const EdgeInsets.symmetric(
              vertical: 0), // Reduce vertical padding
          child: ListTile(
            dense: true,
            key: ValueKey(filePath),
            title: Text(fileName),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDirectory) ...[
                  IconButton(
                    icon: Icon(isExpanded(ref, filePath)
                        ? Icons.expand_more
                        : Icons.chevron_right),
                    onPressed: () => toggleFolderExpansion(ref, filePath),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(), // Adjust based on the actual size of your chevron
                  ),
                ] else ...[
                  // Placeholder for files to align with the chevron of folders
                  const SizedBox(
                      width: 24,
                      height: 24), // Ensure this matches the chevron size
                ],
                Padding(
                  padding: EdgeInsets.only(left: 30.0 * depth),
                  child: isDirectory
                      ? folderIconWidget(fileName, folderSvgIconMetadata)
                      : fileIconWidget(fileName, fileSvgIconMetadata),
                ),
              ],
            ),
            tileColor: isSelected ? Colors.green.withOpacity(0.3) : null,
            onTap: () => handleFileSelection(ref, filePath),
          ),
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

  Future<void> handleFileSelection(WidgetRef ref, String filePath) async {
    final currentSelectedFiles = ref.read(selectedFilesProvider.notifier).state;

    if (currentSelectedFiles.contains(filePath)) {
      await _recursiveDeselection(ref, filePath,
          currentSelectedFiles); // Assume this is also made async if needed
    } else {
      await _recursiveSelection(ref, filePath, currentSelectedFiles);
    }

    // Update the state with the new selection set
    ref.read(selectedFilesProvider.notifier).state = currentSelectedFiles;
    onSelectionChanged(
        currentSelectedFiles); // Ensure this can handle async updates

    // Assuming this method exists and is relevant to your logic
    await _updateEstimatedTokenCount(
        ref); // Make sure this method properly handles asynchronous operations
  }

  Future<void> _recursiveSelection(
      WidgetRef ref, String filePath, Set<String> selectionSet) async {
    final isDirectory = FileSystemEntity.isDirectorySync(filePath);
    selectionSet.add(filePath);

    if (isDirectory) {
      // Asynchronously fetch the folder contents.
      final folderContents =
          await ref.read(folderContentsProvider(filePath).future);
      for (final childPath in folderContents) {
        await _recursiveSelection(ref, childPath,
            selectionSet); // Wait for recursive selection to complete
      }
    }
  }

  Future<void> _recursiveDeselection(
    WidgetRef ref,
    String filePath,
    Set<String> selectionSet,
  ) async {
    final isDirectory = FileSystemEntity.isDirectorySync(filePath);
    selectionSet.remove(filePath);

    if (isDirectory) {
      // Assuming there's logic here similar to _recursiveSelection for fetching and processing contents
      final folderContents =
          await ref.read(folderContentsProvider(filePath).future);
      for (final childPath in folderContents) {
        await _recursiveDeselection(ref, childPath, selectionSet);
      }
    }
  }

  Future<void> _updateEstimatedTokenCount(WidgetRef ref) async {
    final currentSelectedFiles = ref.read(selectedFilesProvider.state).state;
    int tokenCount = 0;

    // Use a list of futures to track completion of all asynchronous operations
    var futures = <Future>[];

    for (var filePath in currentSelectedFiles) {
      futures.add(Future(() async {
        if (await isUtf8Encoded(filePath)) {
          final file = File(filePath);
          final fileContent = await file.readAsString();
          tokenCount += estimateTokenCount(fileContent);
        }
      }));
    }

    // Wait for all file processing operations to complete
    await Future.wait(futures);

    // Optionally add a delay to ensure the state update is the last operation
    Future.delayed(Duration.zero, () {
      // Update the estimated token count provider with the new count
      ref.read(estimatedTokenCountProvider.state).state = tokenCount;
    });
  }

  List<Map<String, dynamic>> _generateCombinedFilesList(
      WidgetRef ref, List<String> files, int depth) {
    List<Map<String, dynamic>> combinedList = [];
    for (final filePath in files) {
      final isDirectory = FileSystemEntity.isDirectorySync(filePath);
      // Add the file or directory with its current depth
      combinedList
          .add({'path': filePath, 'depth': depth, 'isDirectory': isDirectory});

      // If it's a directory and expanded, recursively add its contents with incremented depth
      if (isDirectory && isExpanded(ref, filePath)) {
        final folderContents =
            ref.read(folderContentsProvider(filePath)).asData?.value ?? [];
        combinedList
            .addAll(_generateCombinedFilesList(ref, folderContents, depth + 1));
      }
    }
    return combinedList;
  }
}
