import 'package:flutter/material.dart';

class MediaPreviewSheet extends StatefulWidget {
  final String postUrl;
  final List<Map<String, dynamic>> medias;
  final Function(List<Map<String, dynamic>>) onDownload;

  const MediaPreviewSheet({
    super.key,
    required this.postUrl,
    required this.medias,
    required this.onDownload,
  });

  @override
  State<MediaPreviewSheet> createState() => _MediaPreviewSheetState();
}

class _MediaPreviewSheetState extends State<MediaPreviewSheet> {
  late List<Map<String, dynamic>> _medias;

  @override
  void initState() {
    super.initState();
    _medias = List.from(widget.medias);
  }

  void _toggleSelection(int index) {
    setState(() {
      _medias[index]['selected'] = !_medias[index]['selected'];
    });
  }

  void _toggleAll(bool select) {
    setState(() {
      for (var media in _medias) {
        media['selected'] = select;
      }
    });
  }

  int get _selectedCount => _medias.where((m) => m['selected'] == true).length;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [_buildHeader(), _buildMediaGrid(), _buildBottomBar()],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCAF45)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Medya Seçin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'İndirmek istediğiniz medyaları seçin',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => _toggleAll(true),
                    child: const Text(
                      'Tümü',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _toggleAll(false),
                    child: const Text(
                      'Hiçbiri',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaGrid() {
    return Expanded(
      child: _medias.isEmpty
          ? const Center(child: Text('Medya bulunamadı'))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.75,
              ),
              itemCount: _medias.length,
              itemBuilder: (context, index) {
                final media = _medias[index];
                final isSelected = media['selected'] ?? false;

                return GestureDetector(
                  onTap: () => _toggleSelection(index),
                  child: _buildMediaItem(media, isSelected, index),
                );
              },
            ),
    );
  }

  Widget _buildMediaItem(
    Map<String, dynamic> media,
    bool isSelected,
    int index,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF833AB4) : Colors.grey[300]!,
          width: isSelected ? 3 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF833AB4).withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          _buildMediaThumbnail(media),
          _buildMediaTypeLabel(media),
          _buildSelectionIndicator(isSelected),
          _buildMediaIndex(index),
        ],
      ),
    );
  }

  Widget _buildMediaThumbnail(Map<String, dynamic> media) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: Image.network(
        media['thumbnail'],
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, color: Colors.grey),
          );
        },
      ),
    );
  }

  Widget _buildMediaTypeLabel(Map<String, dynamic> media) {
    return Positioned(
      top: 6,
      left: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              media['type'] == 'video' ? Icons.videocam : Icons.photo,
              color: Colors.white,
              size: 12,
            ),
            const SizedBox(width: 3),
            Text(
              media['type'] == 'video' ? 'VID' : 'IMG',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionIndicator(bool isSelected) {
    return Positioned(
      top: 6,
      right: 6,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF833AB4)
              : Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.grey[400]!,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
          ],
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 14)
            : null,
      ),
    );
  }

  Widget _buildMediaIndex(int index) {
    return Positioned(
      bottom: 6,
      left: 6,
      right: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
        ),
        child: Text(
          '#${index + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_selectedCount medya seçildi',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Toplam ${_medias.length} medya',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _selectedCount > 0
                  ? () {
                      final selected = _medias
                          .where((m) => m['selected'] == true)
                          .toList();
                      widget.onDownload(selected);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF833AB4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download),
                  SizedBox(width: 8),
                  Text(
                    'İndir',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
