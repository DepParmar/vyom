import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'template_editor.dart';

/// Cache for images so they don’t reload unnecessarily
final Map<String, ImageProvider> _imageCache = {};

/// Template model
class TemplateData {
  final String name;
  final String school;
  final int standard;
  final int maxMarks;
  final String? imagePath;

  TemplateData({
    required this.name,
    required this.school,
    required this.standard,
    required this.maxMarks,
    this.imagePath,
  });

  factory TemplateData.fromJson(Map<String, dynamic> json, String schoolName) {
    return TemplateData(
      name: json['name'] ?? 'Untitled',
      school: schoolName,
      standard: json['standard'] ?? 0,
      maxMarks: json['max_marks'] ?? 0,
      imagePath: json['image_url'],
    );
  }
}

class SupabaseTemplatesPage extends StatefulWidget {
  const SupabaseTemplatesPage({super.key});

  @override
  State<SupabaseTemplatesPage> createState() => _SupabaseTemplatesPageState();
}

class _SupabaseTemplatesPageState extends State<SupabaseTemplatesPage> {
  late final SupabaseClient _supabase;

  final List<TemplateData> _loadedTemplates = [];
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 0;
  final int _limit = 20; // load 20 at a time

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;
    _fetchTemplates();

    // Add scroll listener for infinite scroll
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _fetchTemplates();
      }
    });
  }

  Future<void> _fetchTemplates() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final from = _page * _limit;
    final to = from + _limit - 1;

    try {
      final response = await _supabase
          .from('templates')
          .select()
          .range(from, to);

      final fetched = (response as List)
          .map((json) => TemplateData.fromJson(json, "My School"))
          .toList();

      setState(() {
        _page++;
        _loadedTemplates.addAll(fetched);
        if (fetched.length < _limit) {
          _hasMore = false; // no more data
        }
      });
    } catch (e) {
      debugPrint("❌ Error fetching templates: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onTemplateTap(TemplateData template) {
    final imagePath = template.imagePath ?? '';
    ImageProvider? cachedImage = _imageCache[imagePath];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateEditor(
          backgroundImage: imagePath,
          templateName: template.name,
          subjects: const ["Math", "Science", "English"], // TODO: dynamic
          preloadedBackgroundImage: cachedImage,
          maxMarks: template.maxMarks,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Templates",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: const Color(0xFFE3F2FD),
        elevation: 1,
      ),
      body: _loadedTemplates.isEmpty && _isLoading
          ? _buildLoadingPlaceholders()
          : ListView.builder(
              controller: _scrollController,
              itemCount: _loadedTemplates.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _loadedTemplates.length) {
                  // Loader at bottom when fetching more
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final template = _loadedTemplates[index];
                return _TemplateCard(
                  template: template,
                  onTap: () => _onTemplateTap(template),
                );
              },
            ),
    );
  }

  Widget _buildLoadingPlaceholders() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 220,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final TemplateData template;
  final VoidCallback onTap;

  const _TemplateCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imagePath = template.imagePath ?? '';
    final isNetwork = imagePath.startsWith("http");

    final ImageProvider provider = isNetwork
        ? CachedNetworkImageProvider(imagePath)
        : const AssetImage('assets/placeholder.png');

    if (!_imageCache.containsKey(imagePath)) {
      _imageCache[imagePath] = provider;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: isNetwork
                  ? CachedNetworkImage(
                      imageUrl: imagePath,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, _) => Container(
                        height: 200,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 200,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.broken_image, size: 60),
                      ),
                    )
                  : Image(
                      image: provider,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${template.school} • ${template.maxMarks} Marks",
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey.shade700),
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
