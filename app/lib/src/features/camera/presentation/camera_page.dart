import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/scan_service.dart';
import 'verify_scan_page.dart';

class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({super.key});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Capture or select a food image. Gemini will autofill pantry fields for verification.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : () => _scan(ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Take Photo'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loading ? null : () => _scan(ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Choose From Gallery'),
          ),
          if (_loading) ...<Widget>[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _scan(ImageSource source) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final image = await _picker.pickImage(source: source, imageQuality: 80);
      if (image == null) {
        return;
      }

      final bytes = await image.readAsBytes();
      final response = await ref.read(scanServiceProvider).extractItemsFromImage(
            bytes: bytes,
            mimeType: image.mimeType ?? 'image/jpeg',
          );

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VerifyScanPage(
            initialItems: response.items,
            warnings: response.warnings,
          ),
        ),
      );
    } catch (error) {
      setState(() {
        _error = 'Scan failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }
}
