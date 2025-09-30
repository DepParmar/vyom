import 'dart:io';
import 'dart:ui' as ui;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';

class TemplateEditor extends StatefulWidget {
  final String backgroundImage;
  final String templateName;
  final List<String> subjects;
  final ImageProvider? preloadedBackgroundImage;
  final int? maxMarks;

  const TemplateEditor({
    super.key,
    required this.backgroundImage,
    required this.templateName,
    required this.subjects,
    this.preloadedBackgroundImage,
    this.maxMarks,
  });

  @override
  State<TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<TemplateEditor> {
  final GlobalKey _posterKey = GlobalKey();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController unitTestController = TextEditingController();
  final TextEditingController percentageController = TextEditingController();
  
  late final int totalMarksPerSubject;

  late Map<String, TextEditingController> marksControllers;
  late Map<String, FocusNode> marksFocusNodes;

  File? _selectedImage;
  bool _isSaving = false;

  // Image transformation properties
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  Offset _lastFocalPoint = Offset.zero;

  bool _showDeleteIcon = false;
  
  // Cache the background image provider to avoid reloading
  late final ImageProvider _backgroundImageProvider;

  @override
  void initState() {
    super.initState();
    
    // Set dynamic marks per subject based on what was selected in template page
    totalMarksPerSubject = widget.maxMarks ?? 40;
    
    // Use preloaded image if available, otherwise create new provider
    _backgroundImageProvider = widget.preloadedBackgroundImage ?? 
        (widget.backgroundImage.startsWith('http')
            ? NetworkImage(widget.backgroundImage)
            : AssetImage(widget.backgroundImage) as ImageProvider);
    
    // Initialize controllers and focus nodes
    marksControllers = {};
    marksFocusNodes = {};
    
    for (String subject in widget.subjects) {
      marksControllers[subject] = TextEditingController();
      marksFocusNodes[subject] = FocusNode();
    }
    
    // Initialize percentage calculation
    _calculatePercentage();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        // Reset transformation when new image is selected
        _scale = 1.0;
        _offset = Offset.zero;
      });
    }
  }

  void _calculatePercentage() {
    int totalObtained = 0;
    int subjectCount = marksControllers.length;

    for (var controller in marksControllers.values) {
      totalObtained += int.tryParse(controller.text) ?? 0;
    }

    if (subjectCount > 0 && totalMarksPerSubject > 0) {
      double percentage = (totalObtained / (subjectCount * totalMarksPerSubject)) * 100;
      percentageController.text = percentage.toStringAsFixed(2);
    } else {
      percentageController.text = '0.00';
    }
  }

  Future<void> _saveToGallery() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _showDeleteIcon = false;
    });

    try {
      // Wait one frame so UI updates without the delete icon
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _posterKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      await Gal.putImageBytes(pngBytes, album: "VyomTemplates");
      _showSnackBar("Poster saved to Gallery!");
    } catch (e) {
      _showSnackBar("Error saving poster: $e", isError: true);
    } finally {
      setState(() {
        _isSaving = false;
        _showDeleteIcon = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    unitTestController.dispose();
    percentageController.dispose();
    
    for (var controller in marksControllers.values) {
      controller.dispose();
    }
    for (var focusNode in marksFocusNodes.values) {
      focusNode.dispose();
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.templateName, style: const TextStyle(fontSize: 16)),
              Text(
                'Max: $totalMarksPerSubject marks per subject',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.black54),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFE3F2FD),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 3,
                      panEnabled: false,
                      child: RepaintBoundary(
                        key: _posterKey,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.9,
                            maxHeight: MediaQuery.of(context).size.height * 0.8,
                          ),
                          child: AspectRatio(
                            aspectRatio: 9 / 16,
                            child: _buildPosterContent(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Save Button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveToGallery,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, 
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_alt),
                      const SizedBox(width: 8),
                      Text(_isSaving ? 'Saving...' : 'Save to Gallery',
                           style: TextStyle(
                             color: _isSaving ? Colors.grey : Colors.white,
                           )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPosterContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Background - Using cached image provider with loading indicator
            Image(
              image: _backgroundImageProvider,
              fit: BoxFit.cover,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: frame != null
                      ? child
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade300,
                  child: const Center(
                    child: Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.grey,
                    ),
                  ),
                );
              },
            ),

            // Student Name
            Positioned(
              bottom: h * 0.31,
              left: w * 0.05,
              right: w * 0.55,
              child: GestureDetector(
                onTap: () => _editField('Name', nameController),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: SizedBox(
                    width: w * 0.39,
                    height: h * 0.05,
                    child: Center(
                      child: AutoSizeText(
                        nameController.text.isEmpty
                            ? 'Student Name'
                            : nameController.text,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        minFontSize: 10,
                        maxFontSize: 24,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 0),
                              blurRadius: 3,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Unit Test
            Positioned(
              top: h * 0.275,
              right: w * 0.1,
              child: GestureDetector(
                onTap: () => _editField('Unit Test', unitTestController),
                child: SizedBox( 
                  child: Center(    
                    child: Text(
                      unitTestController.text.isEmpty
                          ? 'Unit Test'
                          : unitTestController.text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Percentage
            Positioned(
              bottom: h * 0.29,
              right: w * 0.12,
              child: GestureDetector(
                onTap: () => _editField('Percentage', percentageController),
                child: Text(
                  percentageController.text.isEmpty 
                      ? 'Percent' 
                      : '${percentageController.text}%',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 3,
                        color: Colors.black87,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Student Photo with Zoom/Pan functionality
            Positioned(
              left: w * 0.04,
              bottom: h * 0.37,
              child: GestureDetector(
                onTap: _selectedImage == null
                    ? _pickImage
                    : () {
                        setState(() {
                          _showDeleteIcon = true;
                        });
                      },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: w * 0.41,
                      height: h * 0.30,
                      decoration: BoxDecoration(
                        color: const ui.Color.fromARGB(255, 240, 240, 240),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const ui.Color.fromARGB(255, 255, 255, 255)),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: _selectedImage == null
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo, size: 32, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text(
                                      'Tap to add photo',
                                      style: TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                  ],
                                ),
                              )
                            : GestureDetector(
                                onScaleStart: (details) {
                                  _lastFocalPoint = details.focalPoint;
                                },
                                onScaleUpdate: (details) {
                                  setState(() {
                                    _scale = (_scale * details.scale).clamp(0.5, 3.0);
                                    _offset += details.focalPoint - _lastFocalPoint;
                                    _lastFocalPoint = details.focalPoint;
                                  });
                                },
                                child: Transform(
                                  transform: Matrix4.identity()
                                    ..translate(_offset.dx, _offset.dy)
                                    ..scale(_scale),
                                  alignment: Alignment.center,
                                  child: Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                    width: w * 0.41,
                                    height: h * 0.30,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Center(
                                        child: Icon(Icons.broken_image, color: Colors.red, size: 40),
                                      );
                                    },
                                  ),
                                ),
                              ),
                      ),
                    ),

                    // Delete button (red cross)
                    if (_selectedImage != null && _showDeleteIcon)
                      Positioned(
                        top: -8,
                        right: -8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImage = null;
                              _showDeleteIcon = false;
                              _scale = 1.0;
                              _offset = Offset.zero;
                            });
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.close, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Marks Section
            Positioned(
              right: w * 0.02,
              top: h * 0.38,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: widget.subjects.map((subject) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: w * 0.20,
                          child: Text(
                            subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: w * 0.10,
                          height: 20,
                          child: TextField(
                            controller: marksControllers[subject],
                            focusNode: marksFocusNodes[subject],
                            keyboardType: TextInputType.number,
                            maxLength: 2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            decoration: const InputDecoration(
                              counterText: "",
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              hintText: '00',
                              hintStyle: TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                            onChanged: (value) {
                              if (value.isEmpty) {
                                _calculatePercentage();
                                return;
                              }
                              
                              int marks = int.tryParse(value) ?? 0;
                              
                              // Validate marks don't exceed maximum
                              if (marks > totalMarksPerSubject) {
                                marksControllers[subject]!.text = '$totalMarksPerSubject';
                                marksControllers[subject]!.selection = 
                                    TextSelection.fromPosition(
                                      TextPosition(
                                        offset: marksControllers[subject]!.text.length,
                                      ),
                                    );
                              }
                              
                              // Auto-advance when 2 digits are entered
                              if (value.length == 2) {
                                final keys = widget.subjects;
                                int currentIndex = keys.indexOf(subject);
                                if (currentIndex + 1 < keys.length) {
                                  FocusScope.of(context).requestFocus(
                                    marksFocusNodes[keys[currentIndex + 1]],
                                  );
                                } else {
                                  FocusScope.of(context).unfocus();
                                }
                              }
                              
                              _calculatePercentage();
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editField(String label, TextEditingController controller) async {
    final TextEditingController dialogController = TextEditingController(text: controller.text);

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Edit $label'),
        content: TextField(
          controller: dialogController,
          autofocus: true,
          keyboardType: label.contains('Test') || label.contains('Percent')
              ? TextInputType.number
              : TextInputType.text,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, dialogController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (result != null) {
      setState(() {
        controller.text = result;
      });
      _calculatePercentage();
    }
  }
}