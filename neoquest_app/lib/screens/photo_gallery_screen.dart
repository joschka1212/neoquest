// lib/screens/photo_gallery_screen.dart
// 20250711 11:43 V1.0: Gallery screen to view captured checkpoint photos
// 20250801 XX:XX V1.1: Refactored to use centralized AppColors

import 'package:flutter/material.dart';
import 'dart:io';
import '../services/photo_capture_service.dart';
import '../constants/app_colors.dart';

class PhotoGalleryScreen extends StatefulWidget {
  final String? sessionId;
  final int? checkpointId;

  const PhotoGalleryScreen({
    super.key,
    this.sessionId,
    this.checkpointId,
  });

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  final PhotoCaptureService _photoService = PhotoCaptureService();
  List<CheckpointPhoto> _photos = [];
  PhotoStorageStats? _storageStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    print('📍 Current Screen: ${runtimeType.toString()}');
    _loadPhotos();
    _loadStorageStats();
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<CheckpointPhoto> photos;
      
      if (widget.sessionId != null) {
        photos = await _photoService.getSessionPhotos(widget.sessionId!);
      } else if (widget.checkpointId != null) {
        photos = await _photoService.getCheckpointPhotos(widget.checkpointId!);
      } else {
        // Get all photos - would need additional method in service
        photos = [];
      }

      setState(() {
        _photos = photos;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading photos: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStorageStats() async {
    try {
      final stats = await _photoService.getStorageStats();
      setState(() {
        _storageStats = stats;
      });
    } catch (e) {
      print('❌ Error loading storage stats: $e');
    }
  }

  Future<void> _deletePhoto(CheckpointPhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Photo?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderInactive),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.file(
                  File(photo.filePath),
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Delete photo from ${photo.checkpointName}?',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.redAlert,
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _photoService.deletePhoto(photo.id);
      if (success) {
        _loadPhotos();
        _loadStorageStats();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Photo deleted',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete photo',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            backgroundColor: AppColors.redAlert,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _viewFullPhoto(CheckpointPhoto photo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullPhotoViewer(photo: photo),
      ),
    );
  }

  Widget _buildStorageInfo() {
    if (_storageStats == null) return Container();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.emeraldPrimary.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.emeraldPrimary.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Photo Storage',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStorageStat(
                'Photos',
                '${_storageStats!.totalPhotos}',
                Icons.photo,
              ),
              _buildStorageStat(
                'Storage',
                _storageStats!.formattedTotalSize,
                Icons.storage,
              ),
              _buildStorageStat(
                'Pending',
                '${_storageStats!.pendingUploads}',
                Icons.cloud_upload,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStorageStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.emeraldPrimary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoGrid() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.emeraldPrimary),
        ),
      );
    }

    if (_photos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_library,
                size: 80,
                color: AppColors.disabled,
              ),
              const SizedBox(height: 24),
              Text(
                widget.sessionId != null
                    ? 'No Photos in Session'
                    : widget.checkpointId != null
                        ? 'No Photos at Checkpoint'
                        : 'No Photos Available',
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Photos will appear here after capturing them at checkpoints',
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        final photo = _photos[index];
        return _buildPhotoCard(photo);
      },
    );
  }

  Widget _buildPhotoCard(CheckpointPhoto photo) {
    return Card(
      elevation: 4,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _viewFullPhoto(photo),
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.emeraldPrimary.withOpacity(0.1),
        highlightColor: AppColors.emeraldPrimary.withOpacity(0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photo thumbnail
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: FutureBuilder<bool>(
                  future: File(photo.filePath).exists(),
                  builder: (context, snapshot) {
                    if (snapshot.data == true) {
                      return Image.file(
                        File(photo.filePath),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: AppColors.inputBackground,
                            child: Center(
                              child: Icon(
                                Icons.broken_image,
                                color: AppColors.disabled,
                                size: 40,
                              ),
                            ),
                          );
                        },
                      );
                    } else {
                      return Container(
                        color: AppColors.inputBackground,
                        child: Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: AppColors.disabled,
                            size: 40,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
            
            // Photo info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      photo.checkpointName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      photo.playerName,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            photo.formattedFileSize,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.emeraldPrimary,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            color: AppColors.textSecondary,
                            size: 16,
                          ),
                          color: AppColors.cardBackground,
                          onSelected: (value) {
                            if (value == 'delete') {
                              _deletePhoto(photo);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: AppColors.redAlert, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Delete',
                                    style: TextStyle(color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        title: Text(
          widget.sessionId != null
              ? 'Session Photos'
              : widget.checkpointId != null
                  ? 'Checkpoint Photos'
                  : 'Photo Gallery',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.primaryDark,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            onPressed: () {
              _loadPhotos();
              _loadStorageStats();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh photos',
          ),
        ],
      ),
      body: Column(
        children: [
          // Storage info
          _buildStorageInfo(),
          
          // Photo grid
          Expanded(
            child: _buildPhotoGrid(),
          ),
        ],
      ),
    );
  }
}

/// Full photo viewer widget
class _FullPhotoViewer extends StatelessWidget {
  final CheckpointPhoto photo;

  const _FullPhotoViewer({required this.photo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          photo.checkpointName,
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              _showPhotoInfo(context);
            },
            icon: Icon(
              Icons.info_outline,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4.0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.emeraldPrimary.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(photo.filePath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image,
                        color: AppColors.disabled,
                        size: 80,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Photo not found',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPhotoInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Photo Information',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Container(
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Checkpoint', photo.checkpointName),
              _buildInfoRow('Player', photo.playerName),
              _buildInfoRow('Date', _formatDateTime(photo.timestamp)),
              _buildInfoRow('Size', photo.formattedFileSize),
              if (photo.imageWidth != null && photo.imageHeight != null)
                _buildInfoRow('Dimensions', '${photo.imageWidth}x${photo.imageHeight}'),
              if (photo.latitude != null && photo.longitude != null)
                _buildInfoRow('Location', '${photo.latitude!.toStringAsFixed(6)}, ${photo.longitude!.toStringAsFixed(6)}'),
              _buildInfoRow('Status', photo.uploadStatus.toUpperCase()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: AppColors.emeraldPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}';
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
}