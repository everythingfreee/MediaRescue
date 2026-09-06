class FileItem {
  final String path;
  final String name;
  final String extension;
  final String? mimeType;
  final int size;
  final int modifiedDate;
  final bool isDirectory;
  final String fileType;
  final String parentDirectory;

  const FileItem({
    required this.path,
    required this.name,
    required this.size,
    required this.modifiedDate,
    required this.isDirectory,
    this.extension = '',
    this.mimeType,
    this.fileType = 'other',
    this.parentDirectory = '',
  });

  /// Backward-compatible alias — the absolute filesystem path.
  String get uri => path;

  factory FileItem.fromMap(Map<Object?, Object?> map) {
    return FileItem(
      path: map['path'] as String? ?? '',
      name: map['name'] as String? ?? '',
      size: (map['size'] as num?)?.toInt() ?? 0,
      modifiedDate: (map['modifiedDate'] as num?)?.toInt() ?? 0,
      isDirectory: map['isDirectory'] as bool? ?? false,
      extension: map['extension'] as String? ?? '',
      mimeType: map['mimeType'] as String?,
      fileType: map['fileType'] as String? ?? 'other',
      parentDirectory: map['parentDirectory'] as String? ?? '',
    );
  }

  FileItem copyWith({String? path}) {
    return FileItem(
      path: path ?? this.path,
      name: name,
      extension: extension,
      mimeType: mimeType,
      size: size,
      modifiedDate: modifiedDate,
      isDirectory: isDirectory,
      fileType: fileType,
      parentDirectory: parentDirectory,
    );
  }

  bool get isImage => fileType == 'image';
  bool get isVideo => fileType == 'video';
  bool get isAudio => fileType == 'audio';
  bool get isPdf => fileType == 'pdf';
  bool get isDocument => fileType == 'document';
  bool get isArchive => fileType == 'archive';
  bool get isApk => fileType == 'apk';
  bool get isText => fileType == 'text';
  bool get isFolder => fileType == 'folder';
}