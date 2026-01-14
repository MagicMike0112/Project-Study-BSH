// lib/screens/fridge_camera_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class FridgeCameraPage extends StatefulWidget {
  const FridgeCameraPage({super.key});

  @override
  State<FridgeCameraPage> createState() => _FridgeCameraPageState();
}

class _FridgeCameraPageState extends State<FridgeCameraPage> {
  static const String _backendBase = 'https://project-study-bsh.vercel.app';

  bool _loading = true;
  String? _error;
  String? _token;
  List<_FridgeDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      setState(() {
        _loading = false;
        _error = 'Please sign in to connect Home Connect.';
      });
      return;
    }

    final token = session.accessToken;
    _token = token;

    try {
      final r = await http.get(
        Uri.parse('$_backendBase/api/hc?action=fridgeImages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (r.statusCode == 409) {
        setState(() {
          _loading = false;
          _error = 'Home Connect is not connected.';
        });
        return;
      }
      if (r.statusCode != 200) {
        throw Exception('Fetch failed: ${r.statusCode} ${r.body}');
      }
      final obj = jsonDecode(r.body) as Map<String, dynamic>;
      final list = (obj['appliances'] as List? ?? [])
          .map((e) => _FridgeDevice.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      setState(() {
        _devices = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load images: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Fridge View',
          style: TextStyle(fontWeight: FontWeight.w700, color: colors.onSurface),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh_rounded, color: colors.onSurface),
            onPressed: _load,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildEmptyState(_error!);
    }
    if (_devices.isEmpty) {
      return _buildEmptyState('No fridge devices found.');
    }

    return ListView.separated(
      itemCount: _devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _buildDeviceCard(_devices[index]),
    );
  }

  Widget _buildDeviceCard(_FridgeDevice device) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F1F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.kitchen_rounded,
                  color: Color(0xFF005F87),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  device.name.isNotEmpty ? device.name : 'Fridge',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${device.images.length} images',
                style: TextStyle(
                  color: colors.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (device.error != null) ...[
            const SizedBox(height: 10),
            Text(
              device.error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
          if (device.images.isEmpty && device.error == null) ...[
            const SizedBox(height: 12),
            Text(
              'No images available.',
              style: TextStyle(color: colors.onSurface.withOpacity(0.6), fontSize: 12),
            ),
          ],
          if (device.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildImageGrid(device),
          ],
        ],
      ),
    );
  }

  Widget _buildImageGrid(_FridgeDevice device) {
    return GridView.builder(
      itemCount: device.images.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 4 / 3,
      ),
      itemBuilder: (context, index) {
        final img = device.images[index];
        return _buildImageTile(device.haId, img);
      },
    );
  }

  Widget _buildImageTile(String haId, _FridgeImage img) {
    final imageKey = img.imageKey;
    if (imageKey == null || _token == null) {
      return _imagePlaceholder(img.title);
    }
    final url = Uri.parse('$_backendBase/api/hc?action=fridgeImage&haId=$haId&imageKey=$imageKey');
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openImageViewer(url.toString(), img.title),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E232A)
              : const Color(0xFFF2F4F7),
          child: Image.network(
            url.toString(),
            fit: BoxFit.cover,
            headers: {'Authorization': 'Bearer $_token'},
            errorBuilder: (context, error, stack) => _imagePlaceholder(img.title),
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder(String title) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E232A) : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Center(
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSurface.withOpacity(0.6), fontSize: 12),
        ),
      ),
    );
  }

  void _openImageViewer(String url, String title) {
    if (_token == null) return;
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  headers: {'Authorization': 'Bearer $_token'},
                  errorBuilder: (context, error, stack) => const Center(
                    child: Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE6F1F7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.photo_camera_front_rounded,
              color: Color(0xFF005F87),
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _FridgeDevice {
  final String haId;
  final String name;
  final String? error;
  final List<_FridgeImage> images;

  _FridgeDevice({
    required this.haId,
    required this.name,
    required this.images,
    this.error,
  });

  factory _FridgeDevice.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List? ?? [])
        .map((e) => _FridgeImage.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return _FridgeDevice(
      haId: json['haId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      error: json['error']?.toString(),
      images: images,
    );
  }
}

class _FridgeImage {
  final String? imageKey;
  final String title;

  _FridgeImage({required this.imageKey, required this.title});

  factory _FridgeImage.fromJson(dynamic json) {
    if (json is String) {
      return _FridgeImage(imageKey: json, title: json);
    }
    final map = (json as Map).cast<String, dynamic>();
    final data = map['data'] is Map ? (map['data'] as Map).cast<String, dynamic>() : map;
    String? key = data['imageKey']?.toString();
    key ??= data['imagekey']?.toString();
    key ??= data['image_key']?.toString();
    key ??= data['key']?.toString();
    key ??= data['id']?.toString();
    key ??= data['uid']?.toString();

    final title = data['name']?.toString() ??
        data['title']?.toString() ??
        key ??
        'Image';
    return _FridgeImage(imageKey: key, title: title);
  }
}
