import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'template_editor.dart';

final Map<String, ImageProvider> _imageCache = {};

class TemplateData {
  final String id;
  final String name;
  final int standard;
  final int maxMarks;
  final String? imagePath;

  TemplateData({
    required this.id,
    required this.name,
    required this.standard,
    required this.maxMarks,
    this.imagePath,
  });

  factory TemplateData.fromJson(Map<String, dynamic> json) {
    return TemplateData(
      id: json['id'],
      name: json['name'] ?? 'Untitled',
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

  List<Map<String, dynamic>> _schools = [];
  String? _selectedSchoolId;

  List<int> _marksOptions = [];
  int? _selectedMarks;

  List<TemplateData> _templates = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;
    _initData();
  }

  Future<void> _initData() async {
    try {
      // Fetch schools
      final response = await _supabase.from('schools').select('id, name');
      final schools = List<Map<String, dynamic>>.from(response);

      if (schools.isNotEmpty) {
        _selectedSchoolId = schools.first['id'];
        _schools = schools;

        // Fetch marks for first school
        await _fetchMarks(_selectedSchoolId!, autoSelectFirst: true);
      }
    } catch (e) {
      debugPrint("❌ Error init data: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchMarks(String schoolId,
      {bool autoSelectFirst = false}) async {
    try {
      final response = await _supabase
          .from('templates')
          .select('max_marks')
          .eq('school_id', schoolId);

      final marks = (response as List)
          .map((row) => row['max_marks'] as int)
          .toSet()
          .toList()
        ..sort();

      if (marks.isNotEmpty) {
        _marksOptions = marks;
        if (autoSelectFirst) {
          _selectedMarks = marks.first;
          await _fetchTemplates(schoolId, _selectedMarks!);
        }
      }
    } catch (e) {
      debugPrint("❌ Error fetching marks: $e");
    }
  }

  Future<void> _fetchTemplates(String schoolId, int marks) async {
    try {
      final response = await _supabase
          .from('templates')
          .select()
          .eq('school_id', schoolId)
          .eq('max_marks', marks);

      final templates = (response as List)
          .map((json) => TemplateData.fromJson(json))
          .toList();

      setState(() {
        _templates = templates;
      });
    } catch (e) {
      debugPrint("❌ Error fetching templates: $e");
    }
  }

Future<List<String>> _fetchSubjects(String schoolId, int standard) async {
  try {
    final response = await _supabase
        .from('subjects')
        .select('subject, standard_range')
        .eq('school_id', schoolId);

    final subjects = <String>[];

    for (var row in response) {
      final range = row['standard_range'] as String?;
      final subject = row['subject'] as String;

      if (range != null) {
        // Example standard_range: "1-5"
        final parts = range.split('-');
        if (parts.length == 2) {
          final start = int.tryParse(parts[0]) ?? 0;
          final end = int.tryParse(parts[1]) ?? 0;
          if (standard >= start && standard <= end) {
            subjects.add(subject);
          }
        }
      }
    }

    return subjects;
  } catch (e) {
    debugPrint("❌ Error fetching subjects: $e");
    return [];
  }
}

  void _onTemplateTap(TemplateData template) async {
  final imagePath = template.imagePath ?? '';
  final cachedImage = _imageCache[imagePath];

  // Fetch subjects before opening editor
  final subjects =
      await _fetchSubjects(_selectedSchoolId!, template.standard);

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TemplateEditor(
        backgroundImage: imagePath,
        templateName: template.name,
        subjects: subjects, // ✅ dynamic subjects now
        preloadedBackgroundImage: cachedImage,
        maxMarks: template.maxMarks,
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Top row with school + marks side by side
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // School dropdown
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                    value: _selectedSchoolId,
                    items: _schools
                        .map((school) => DropdownMenuItem<String>(
                              value: school['id'] as String,
                              child: Text(
                                school['name'] as String,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                  decoration: const InputDecoration(
                    labelText: "School",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) async {
                    if (value != null) {
                      setState(() {
                        _selectedSchoolId = value;
                        _marksOptions.clear();
                        _templates.clear();
                      });
                      await _fetchMarks(value, autoSelectFirst: true);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Marks dropdown
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedMarks,
                  items: _marksOptions
                      .map((m) =>
                          DropdownMenuItem(value: m, child: Text("$m Marks")))
                      .toList(),
                  decoration: const InputDecoration(
                    labelText: "Marks",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (marks) async {
                    if (marks != null && _selectedSchoolId != null) {
                      setState(() => _selectedMarks = marks);
                      await _fetchTemplates(_selectedSchoolId!, marks);
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        // Templates list
        Expanded(
          child: _templates.isEmpty
              ? const Center(child: Text("No templates found"))
              : ListView.builder(
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final template = _templates[index];
                    return _TemplateCard(
                      template: template,
                      onTap: () => _onTemplateTap(template),
                    );
                  },
                ),
        ),
      ],
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
                    "${template.standard} Std • ${template.maxMarks} Marks",
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
