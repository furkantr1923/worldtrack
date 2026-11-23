import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/models.dart';
import '../widgets/common.dart';

/// Tam ekran fotoğraf görüntüleyici: kaydırma, iki parmakla / tekerlekle yakınlaştırma,
/// klavye okları (Windows). Görsel ekran çözünürlüğüne göre çözülür (bellek dostu).
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({super.key, required this.photos, this.initialIndex = 0});
  final List<TravelPhoto> photos;
  final int initialIndex;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _pages.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = (_index + delta).clamp(0, widget.photos.length - 1);
    if (next != _index) {
      _pages.animateToPage(next, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodeWidth = (size.longestSide * dpr).clamp(800, 3200).round();
    final photo = widget.photos[_index];
    return KeyboardListener(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (e) {
        if (e is! KeyDownEvent) return;
        if (e.logicalKey == LogicalKeyboardKey.arrowRight) _go(1);
        if (e.logicalKey == LogicalKeyboardKey.arrowLeft) _go(-1);
        if (e.logicalKey == LogicalKeyboardKey.escape) Navigator.maybePop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text('${_index + 1} / ${widget.photos.length}',
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          actions: [
            if (photo.width != null && photo.height != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text('${photo.width}×${photo.height}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ),
          ],
        ),
        body: Stack(
          children: [
            PageView.builder(
              controller: _pages,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: LocalImage(
                    path: widget.photos[i].filePath,
                    fit: BoxFit.contain,
                    cacheWidth: decodeWidth,
                  ),
                ),
              ),
            ),
            if (widget.photos.length > 1 && isWide(context)) ...[
              Positioned(
                left: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton.filledTonal(
                    onPressed: _index > 0 ? () => _go(-1) : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton.filledTonal(
                    onPressed: _index < widget.photos.length - 1 ? () => _go(1) : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
