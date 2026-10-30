import 'package:flutter/material.dart';

/// Full-screen photo with pinch-to-zoom, so staff can read a meter or a
/// label in the picture.
class PhotoViewerPage extends StatelessWidget {
  const PhotoViewerPage({super.key, required this.url, required this.heroId});

  final String url;
  final String heroId;

  static Route<void> route(String url, String heroId) =>
      MaterialPageRoute(builder: (_) => PhotoViewerPage(url: url, heroId: heroId));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Photo', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Hero(tag: 'photo-$heroId', child: Image.network(url, fit: BoxFit.contain)),
        ),
      ),
    );
  }
}
