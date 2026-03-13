import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whitenoise/src/rust/api/media_files.dart';

final _logger = Logger('useMediaUpload');

enum MediaUploadStatus { uploading, uploaded, error }

typedef MediaUploadItem = ({
  String filePath,
  String originalFilename,
  MediaUploadStatus status,
  MediaFile? file,
  VoidCallback? retry,
});

/// Maximum file size accepted for upload (50 MiB).
/// Most Blossom servers enforce a similar cap server-side; rejecting early
/// gives the user clear feedback instead of a silent failure.
const maxUploadBytes = 50 * 1024 * 1024;

typedef MediaUploadState = ({
  List<MediaUploadItem> items,
  bool canSend,
  List<({MediaFile file, String originalFilename})> uploadedFiles,
  Future<void> Function() pickImages,
  /// Picks one or more files to attach.
  /// Returns the names of any files that exceeded [maxUploadBytes] so the
  /// caller can show appropriate feedback (e.g. a SnackBar).
  Future<List<String>> Function() pickFiles,
  void Function(String filePath) removeItem,
  VoidCallback clearAll,
});

typedef UploadFunction =
    Future<MediaFile> Function({
      required String accountPubkey,
      required String groupId,
      required String filePath,
    });

MediaUploadState useMediaUpload({
  required String pubkey,
  required String groupId,
  ImagePicker? imagePicker,
  UploadFunction? uploadFn,
}) {
  final items = useState<List<MediaUploadItem>>([]);
  final picker = useMemoized(() => imagePicker ?? ImagePicker(), [imagePicker]);
  final upload = uploadFn ?? uploadChatMedia;

  List<MediaUploadItem> updateItem(
    List<MediaUploadItem> currentItems,
    String filePath,
    MediaUploadItem Function(MediaUploadItem) update,
  ) {
    return currentItems.map((item) {
      if (item.filePath == filePath) {
        return update(item);
      }
      return item;
    }).toList();
  }

  Future<void> performUpload(String filePath) async {
    _logger.info('performUpload START filePath=$filePath groupId=$groupId');
    try {
      final file = await upload(
        accountPubkey: pubkey,
        groupId: groupId,
        filePath: filePath,
      );
      _logger.info(
        'performUpload OK filePath=$filePath blossomUrl=${file.blossomUrl} '
        'mimeType=${file.mimeType} mediaType=${file.mediaType}',
      );
      items.value = updateItem(
        items.value,
        filePath,
        (item) => (
          filePath: item.filePath,
          originalFilename: item.originalFilename,
          status: MediaUploadStatus.uploaded,
          file: file,
          retry: null,
        ),
      );
    } catch (e, st) {
      _logger.severe('performUpload FAILED filePath=$filePath groupId=$groupId', e, st);
      items.value = updateItem(
        items.value,
        filePath,
        (item) => (
          filePath: item.filePath,
          originalFilename: item.originalFilename,
          status: MediaUploadStatus.error,
          file: null,
          retry: () {
            _logger.info('performUpload retry filePath=$filePath');
            items.value = updateItem(
              items.value,
              filePath,
              (i) => (
                filePath: i.filePath,
                originalFilename: i.originalFilename,
                status: MediaUploadStatus.uploading,
                file: null,
                retry: null,
              ),
            );
            unawaited(performUpload(filePath));
          },
        ),
      );
    }
  }

  Future<void> pickImages() async {
    _logger.info('pickImages groupId=$groupId');
    final pickedFiles = await picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (pickedFiles.isEmpty) {
      _logger.info('pickImages no files selected');
      return;
    }

    final existingPaths = items.value.map((item) => item.filePath).toSet();
    final uniqueFiles = pickedFiles.where((xFile) => !existingPaths.contains(xFile.path)).toList();
    if (uniqueFiles.isEmpty) {
      _logger.info('pickImages all ${pickedFiles.length} files already queued, skipping');
      return;
    }

    _logger.info(
      'pickImages picked=${pickedFiles.length} unique=${uniqueFiles.length} groupId=$groupId',
    );

    final newItems = uniqueFiles.map((xFile) {
      return (
            filePath: xFile.path,
            originalFilename: xFile.path.split('/').last,
            status: MediaUploadStatus.uploading,
            file: null,
            retry: null,
          )
          as MediaUploadItem;
    }).toList();

    items.value = [...items.value, ...newItems];

    for (final item in newItems) {
      unawaited(performUpload(item.filePath));
    }
  }

  Future<List<String>> pickFiles() async {
    _logger.info('pickFiles groupId=$groupId');
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      _logger.info('pickFiles no files selected');
      return [];
    }

    final existingPaths = items.value.map((item) => item.filePath).toSet();
    final resolvedItems = <({String path, String originalFilename})>[];
    final oversizedNames = <String>[];

    for (final f in result.files) {
      // Reject files that exceed the upload size cap up front.
      if (f.size > maxUploadBytes) {
        _logger.warning('pickFiles rejected ${f.name}: ${f.size} bytes exceeds $maxUploadBytes');
        oversizedNames.add(f.name);
        continue;
      }

      if (f.path != null && !existingPaths.contains(f.path)) {
        // f.name is the original display name used by the Rust for encryption
        resolvedItems.add((path: f.path!, originalFilename: f.name));
      } else if (f.path == null) {
        // Android content URI — no direct path, stream bytes to a temp file.
        // Use f.name so the temp file keeps the original name (Rust uses it for key derivation).
        if (f.bytes != null) {
          try {
            final tmpDir = await getTemporaryDirectory();
            final tmpFile = File('${tmpDir.path}/${f.name}');
            await tmpFile.writeAsBytes(f.bytes!, flush: true);
            _logger.info('pickFiles streamed content URI to ${tmpFile.path}');
            if (!existingPaths.contains(tmpFile.path)) {
              resolvedItems.add((path: tmpFile.path, originalFilename: f.name));
            }
          } catch (e) {
            _logger.severe('pickFiles failed to stream ${f.name} to temp file: $e');
            oversizedNames.add(f.name);
          }
        } else {
          _logger.warning('pickFiles skipping ${f.name}: no path and no bytes');
          oversizedNames.add(f.name);
        }
      }
    }

    if (resolvedItems.isNotEmpty) {
      _logger.info('pickFiles queuing ${resolvedItems.length} files groupId=$groupId');

      final newItems = resolvedItems
          .map(
            (r) =>
                (
                  filePath: r.path,
                  originalFilename: r.originalFilename,
                  status: MediaUploadStatus.uploading,
                  file: null,
                  retry: null,
                ) as MediaUploadItem,
          )
          .toList();

      items.value = [...items.value, ...newItems];

      for (final item in newItems) {
        unawaited(performUpload(item.filePath));
      }
    }

    return oversizedNames;
  }

  void removeItem(String filePath) {
    items.value = items.value.where((item) => item.filePath != filePath).toList();
  }

  void clearAll() {
    items.value = [];
  }

  final canSend =
      items.value.isNotEmpty &&
      items.value.every((item) => item.status == MediaUploadStatus.uploaded);

  final uploadedFiles = items.value
      .where((item) => item.status == MediaUploadStatus.uploaded && item.file != null)
      .map((item) => (file: item.file!, originalFilename: item.originalFilename))
      .toList();

  return (
    items: items.value,
    canSend: canSend,
    uploadedFiles: uploadedFiles,
    pickImages: pickImages,
    pickFiles: pickFiles,
    removeItem: removeItem,
    clearAll: clearAll,
  );
}
