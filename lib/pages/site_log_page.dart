import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../utils/site_time_helper.dart';

class SiteLogPage extends StatefulWidget {
  const SiteLogPage({super.key});

  @override
  State<SiteLogPage> createState() => _SiteLogPageState();
}

class _SiteLogPageState extends State<SiteLogPage> {
  final DatabaseService _db = DatabaseService();
  final _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  late stt.SpeechToText _speech;
  bool _isSpeechAvailable = false;
  bool _isListening = false;
  String _lastRecognizedWords = '';
  
  final List<String> _imagePaths = [];
  String _weather = '晴天';
  bool _isSaving = false;
  bool _isSpeechSupported = true;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    if (kIsWeb) {
      setState(() {
        _isSpeechSupported = false;
      });
      return;
    }
    
    _speech = stt.SpeechToText();
    try {
      _isSpeechAvailable = await _speech.initialize(
        onError: (error) {
          debugPrint('Speech recognition error: $error');
          if (mounted) {
            setState(() => _isListening = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('语音识别错误: ${error.errorMsg}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() => _isListening = false);
            }
          }
        },
      );
      setState(() {
        _isSpeechSupported = true;
      });
    } catch (e) {
      debugPrint('Speech init error: $e');
      setState(() {
        _isSpeechSupported = false;
      });
    }
  }

  void _startListening() async {
    if (!_isSpeechAvailable || !_isSpeechSupported) {
      _showNotSupportedMessage('语音识别');
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    setState(() => _isListening = true);
    _lastRecognizedWords = '';

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _lastRecognizedWords = result.recognizedWords;
          if (result.recognizedWords.isNotEmpty) {
            final currentText = _contentController.text;
            if (currentText.isEmpty) {
              _contentController.text = result.recognizedWords;
            } else {
              _contentController.text = '$currentText\n${result.recognizedWords}';
            }
          }
        });
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: true,
      listenMode: stt.ListenMode.confirmation,
      localeId: 'zh_CN',
    );
  }

  void _showNotSupportedMessage(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature功能在当前平台暂不支持'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _takePhoto() async {
    if (kIsWeb) {
      _showNotSupportedMessage('相机拍照');
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _imagePaths.add(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('拍照失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (images.isNotEmpty) {
        setState(() {
          _imagePaths.addAll(images.map((img) => img.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('选择图片失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    final content = _contentController.text.trim();
    
    if (content.isEmpty && _imagePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入施工内容或添加照片'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final imagePathStr = _imagePaths.isEmpty ? '' : _imagePaths.join('|');
      
      await _db.insertSiteLog({
        'date': DateTime.now().toIso8601String().split('T').first,
        'weather': _weather,
        'content': content,
        'voice_note': _lastRecognizedWords,
        'image_paths': imagePathStr,
        'created_at': DateTime.now().toIso8601String(),
      });

      _contentController.clear();
      _lastRecognizedWords = '';
      _imagePaths.clear();
      setState(() {
        _weather = '晴天';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ 日志保存成功'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('施工日志'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _handleSave,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save, color: Colors.white),
            label: Text(
              _isSaving ? '保存中...' : '保存',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateTimeWeatherCard(context),
            const SizedBox(height: 20),
            _buildVoiceInputSection(context),
            const SizedBox(height: 20),
            _buildContentSection(context),
            const SizedBox(height: 20),
            _buildImageSection(context),
            const SizedBox(height: 20),
            _buildQuickTags(context),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeWeatherCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    SiteTimeHelper.formatDate(DateTime.now()),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    SiteTimeHelper.getWeekday(DateTime.now()),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _showWeatherPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getWeatherIcon(_weather),
                        color: Colors.amber,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _weather,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '点击切换',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getWeatherIcon(String weather) {
    switch (weather) {
      case '晴天':
        return Icons.wb_sunny;
      case '多云':
        return Icons.wb_cloudy;
      case '阴天':
        return Icons.cloud;
      case '小雨':
      case '大雨':
        return Icons.grain;
      default:
        return Icons.wb_sunny;
    }
  }

  void _showWeatherPicker() {
    final weathers = ['晴天', '多云', '阴天', '小雨', '大雨'];
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '选择天气',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: weathers.map((w) => ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getWeatherIcon(w), size: 18, color: AppTheme.primaryColor),
                    const SizedBox(width: 4),
                    Text(w),
                  ],
                ),
                selected: _weather == w,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _weather = w);
                    Navigator.pop(context);
                  }
                },
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceInputSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '语音输入',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                if (!_isSpeechSupported)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Web暂不支持',
                      style: TextStyle(fontSize: 10, color: Colors.orange),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTapDown: _isSpeechSupported ? (_) => _startListening() : null,
                onTapUp: _isSpeechSupported ? (_) {} : null,
                onTapCancel: _isSpeechSupported ? () {} : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _isListening ? 100 : 80,
                  height: _isListening ? 100 : 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isListening
                          ? [Colors.red, Colors.redAccent]
                          : [AppTheme.primaryColor, AppTheme.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? Colors.red : AppTheme.primaryColor)
                            .withOpacity(0.4),
                        blurRadius: _isListening ? 25 : 15,
                        spreadRadius: _isListening ? 8 : 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _isListening ? '正在录音，请说话...' : '点击麦克风开始语音输入',
                  key: ValueKey(_isListening),
                  style: TextStyle(
                    fontSize: 14,
                    color: _isListening ? Colors.red : Colors.grey[600],
                    fontWeight: _isListening ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
            if (_isListening) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _lastRecognizedWords.isEmpty
                            ? '等待识别...'
                            : _lastRecognizedWords,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontStyle: _lastRecognizedWords.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContentSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '施工内容',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: '请输入今日施工内容...\n\n例如：\n- 3号楼二层混凝土浇筑\n- 完成钢筋绑扎工作\n- 安全巡检无异常',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '现场照片 (${_imagePaths.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      color: AppTheme.primaryColor,
                      tooltip: '拍照',
                    ),
                    IconButton(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      color: AppTheme.primaryColor,
                      tooltip: '从相册选择',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_imagePaths.isEmpty)
              _buildAddImageButton(context)
            else
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._imagePaths.map((path) => _buildImageItem(path)),
                    _buildAddImageButton(context, isSmall: true),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageItem(String path) {
    return Container(
      width: 120,
      height: 120,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: kIsWeb
                ? Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    child: const Icon(Icons.image, size: 40, color: AppTheme.primaryColor),
                  )
                : Image.file(
                    File(path),
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      child: const Icon(Icons.image, size: 40, color: AppTheme.primaryColor),
                    ),
                  ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => setState(() => _imagePaths.remove(path)),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddImageButton(BuildContext context, {bool isSmall = false}) {
    return GestureDetector(
      onTap: () async {
        if (kIsWeb) {
          await _pickFromGallery();
        } else {
          _showImageSourceDialog();
        }
      },
      child: Container(
        width: isSmall ? 120 : double.infinity,
        height: isSmall ? 120 : 100,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate,
              size: isSmall ? 32 : 40,
              color: AppTheme.primaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              isSmall ? '添加更多' : '点击添加照片',
              style: TextStyle(
                fontSize: isSmall ? 12 : 14,
                color: AppTheme.primaryColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '选择图片来源',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceOption(
                  icon: Icons.camera_alt,
                  label: '拍照',
                  onTap: () {
                    Navigator.pop(context);
                    _takePhoto();
                  },
                ),
                _buildSourceOption(
                  icon: Icons.photo_library,
                  label: '相册',
                  onTap: () {
                    Navigator.pop(context);
                    _pickFromGallery();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppTheme.primaryColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTags(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '快速标签',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTag('混凝土浇筑', Icons.construction),
            _buildTag('钢筋绑扎', Icons.grid_on),
            _buildTag('模板安装', Icons.view_module),
            _buildTag('安全巡检', Icons.security),
            _buildTag('材料进场', Icons.local_shipping),
            _buildTag('质量检查', Icons.fact_check),
          ],
        ),
      ],
    );
  }

  Widget _buildTag(String label, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: AppTheme.primaryColor),
      label: Text(label),
      onPressed: () {
        final currentText = _contentController.text;
        if (currentText.isNotEmpty && !currentText.endsWith('\n')) {
          _contentController.text = '$currentText\n- $label';
        } else {
          _contentController.text = '$currentText- $label';
        }
      },
      backgroundColor: AppTheme.primaryColor.withOpacity(0.05),
      side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
    );
  }
}
