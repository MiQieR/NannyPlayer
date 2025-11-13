import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:marquee/marquee.dart';
import 'dart:io';
import 'dart:math';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 锁定竖屏方向
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const NannyPlayerApp());
}

class NannyPlayerApp extends StatelessWidget {
  const NannyPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '音乐播放器',
      debugShowCheckedModeBanner: false, // 隐藏DEBUG标注
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // 增大默认字体大小，方便老年人阅读
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 20),
          bodyMedium: TextStyle(fontSize: 18),
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      home: const PlayerPage(),
    );
  }
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FocusNode _focusNode = FocusNode();
  final VolumeController _volumeController = VolumeController();

  List<String> _playlist = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isShuffleMode = false;
  double _currentVolume = 0.5;

  // 随机播放相关
  List<int> _shuffledIndices = []; // 打乱后的索引列表
  int _shuffledPosition = 0; // 当前在打乱列表中的位置

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPlayer();
    _loadPlaylist();
    _loadSettings();
    _initVolume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveProgress();
    _audioPlayer.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当App进入后台或退出时，自动暂停并保存进度
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseAndSave();
    }
  }

  void _initPlayer() {
    // 监听播放状态
    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
      });

      // 当歌曲播放完毕，自动播放下一曲
      if (state.processingState == ProcessingState.completed) {
        _playNext();
      }
    });

    // 监听播放进度
    _audioPlayer.positionStream.listen((position) {
      setState(() {
        _position = position;
      });
    });

    // 监听歌曲时长
    _audioPlayer.durationStream.listen((duration) {
      setState(() {
        _duration = duration ?? Duration.zero;
      });
    });
  }

  // 初始化音量控制器
  Future<void> _initVolume() async {
    try {
      double volume = await _volumeController.getVolume();
      setState(() {
        _currentVolume = volume;
      });
    } catch (e) {
      // 如果获取音量失败，使用默认值
      setState(() {
        _currentVolume = 0.5;
      });
    }
  }

  // 增加音量
  Future<void> _increaseVolume() async {
    try {
      double newVolume = (_currentVolume + 0.1).clamp(0.0, 1.0);
      _volumeController.setVolume(newVolume);
      setState(() {
        _currentVolume = newVolume;
      });

      // 显示音量提示
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('音量: ${(newVolume * 100).toInt()}%'),
            duration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      // 忽略错误
    }
  }

  // 减少音量
  Future<void> _decreaseVolume() async {
    try {
      double newVolume = (_currentVolume - 0.1).clamp(0.0, 1.0);
      _volumeController.setVolume(newVolume);
      setState(() {
        _currentVolume = newVolume;
      });

      // 显示音量提示
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('音量: ${(newVolume * 100).toInt()}%'),
            duration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      // 忽略错误
    }
  }

  // 处理硬件按键事件
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // 只处理按键按下事件，忽略按键释放
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // DPAD_CENTER (确定键) → 播放/暂停
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      _togglePlayPause();
      return KeyEventResult.handled;
    }

    // DPAD_LEFT → 上一曲
    if (key == LogicalKeyboardKey.arrowLeft) {
      _playPrevious();
      return KeyEventResult.handled;
    }

    // DPAD_RIGHT → 下一曲
    if (key == LogicalKeyboardKey.arrowRight) {
      _playNext();
      return KeyEventResult.handled;
    }

    // DPAD_UP → 音量增加
    if (key == LogicalKeyboardKey.arrowUp) {
      _increaseVolume();
      return KeyEventResult.handled;
    }

    // DPAD_DOWN → 音量减少
    if (key == LogicalKeyboardKey.arrowDown) {
      _decreaseVolume();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isShuffleMode = prefs.getBool('shuffleMode') ?? false;
    });

    // 如果是随机模式，加载洗牌列表
    if (_isShuffleMode && _playlist.isNotEmpty) {
      final savedShuffled = prefs.getStringList('shuffledIndices');
      if (savedShuffled != null && savedShuffled.isNotEmpty) {
        _shuffledIndices = savedShuffled.map((s) => int.parse(s)).toList();
        _shuffledPosition = prefs.getInt('shuffledPosition') ?? 0;
      } else {
        _generateShuffledList();
      }
    }
  }

  // 生成打乱的播放列表
  void _generateShuffledList() {
    if (_playlist.isEmpty) return;

    // 创建索引列表
    _shuffledIndices = List.generate(_playlist.length, (index) => index);

    // 使用Fisher-Yates洗牌算法
    final random = Random();
    for (int i = _shuffledIndices.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = _shuffledIndices[i];
      _shuffledIndices[i] = _shuffledIndices[j];
      _shuffledIndices[j] = temp;
    }

    // 重置播放位置
    _shuffledPosition = 0;

    // 更新当前索引为打乱列表的第一项
    if (_shuffledIndices.isNotEmpty) {
      _currentIndex = _shuffledIndices[_shuffledPosition];
    }
  }

  Future<void> _loadPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPlaylist = prefs.getStringList('playlist') ?? [];
    final savedIndex = prefs.getInt('currentIndex') ?? 0;
    final savedPosition = prefs.getInt('position') ?? 0;

    if (savedPlaylist.isNotEmpty) {
      setState(() {
        _playlist = savedPlaylist;
        _currentIndex = savedIndex;
      });

      // 加载并恢复到上次播放位置
      await _audioPlayer.setFilePath(_playlist[_currentIndex]);
      await _audioPlayer.seek(Duration(milliseconds: savedPosition));
    }
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('playlist', _playlist);
    await prefs.setInt('currentIndex', _currentIndex);
    await prefs.setInt('position', _position.inMilliseconds);

    // 保存洗牌列表和位置
    if (_isShuffleMode && _shuffledIndices.isNotEmpty) {
      await prefs.setStringList(
        'shuffledIndices',
        _shuffledIndices.map((i) => i.toString()).toList(),
      );
      await prefs.setInt('shuffledPosition', _shuffledPosition);
    }
  }

  Future<void> _pauseAndSave() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    }
    await _saveProgress();
  }

  void _togglePlayPause() async {
    if (_playlist.isEmpty) {
      // 如果还没有选择音乐，提示去设置页面
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先在设置中导入音乐文件'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
    }
  }

  void _playNext() async {
    if (_playlist.isEmpty) return;

    if (_isShuffleMode) {
      // 随机播放模式：按打乱的列表顺序播放
      if (_shuffledIndices.isEmpty) {
        _generateShuffledList();
      }

      _shuffledPosition++;

      // 如果播放完所有歌曲，重新洗牌
      if (_shuffledPosition >= _shuffledIndices.length) {
        _generateShuffledList();
        _shuffledPosition = 0;
      }

      setState(() {
        _currentIndex = _shuffledIndices[_shuffledPosition];
      });
    } else {
      // 顺序播放模式
      setState(() {
        _currentIndex = (_currentIndex + 1) % _playlist.length;
      });
    }

    await _audioPlayer.setFilePath(_playlist[_currentIndex]);
    await _audioPlayer.play();
    await _saveProgress();
  }

  void _playPrevious() async {
    if (_playlist.isEmpty) return;

    if (_isShuffleMode) {
      // 随机播放模式：回到打乱列表的上一首
      if (_shuffledIndices.isEmpty) {
        _generateShuffledList();
      }

      _shuffledPosition--;

      // 如果已经是第一首，跳到最后一首
      if (_shuffledPosition < 0) {
        _shuffledPosition = _shuffledIndices.length - 1;
      }

      setState(() {
        _currentIndex = _shuffledIndices[_shuffledPosition];
      });
    } else {
      // 顺序播放模式
      setState(() {
        _currentIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
      });
    }

    await _audioPlayer.setFilePath(_playlist[_currentIndex]);
    await _audioPlayer.play();
    await _saveProgress();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  String _getCurrentSongName() {
    if (_playlist.isEmpty) return '未选择音乐';
    final path = _playlist[_currentIndex];
    final fileName = path.split(Platform.pathSeparator).last;
    // 去掉文件扩展名
    return fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
  }

  void _navigateToSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          currentPlaylist: _playlist,
          isShuffleMode: _isShuffleMode,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      final oldShuffleMode = _isShuffleMode;

      // 重新加载播放列表和设置
      await _loadPlaylist();
      await _loadSettings();

      // 如果播放列表改变了，重新加载第一首歌
      if (result['playlistChanged'] == true && _playlist.isNotEmpty) {
        setState(() {
          _currentIndex = 0;
          _shuffledPosition = 0;
        });

        // 如果是随机模式，生成洗牌列表
        if (_isShuffleMode) {
          _generateShuffledList();
        }

        await _audioPlayer.setFilePath(_playlist[_currentIndex]);
      }

      // 如果随机模式改变了
      if (oldShuffleMode != _isShuffleMode) {
        if (_isShuffleMode) {
          // 开启随机模式：生成洗牌列表
          _generateShuffledList();

          // 找到当前歌曲在洗牌列表中的位置
          for (int i = 0; i < _shuffledIndices.length; i++) {
            if (_shuffledIndices[i] == _currentIndex) {
              _shuffledPosition = i;
              break;
            }
          }
        } else {
          // 关闭随机模式：清空洗牌列表
          setState(() {
            _shuffledIndices.clear();
            _shuffledPosition = 0;
          });
        }
        await _saveProgress();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 顶部：歌曲名称
                Column(
                  children: [
                    // 使用固定高度的Container显示滚动歌曲名
                    SizedBox(
                      height: 24, // 单行文本高度
                      child: _getCurrentSongName().length > 15
                          ? Marquee(
                              text: _getCurrentSongName(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              scrollAxis: Axis.horizontal,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              blankSpace: 30.0,
                              velocity: 30.0,
                              pauseAfterRound: const Duration(seconds: 1),
                              startPadding: 10.0,
                              accelerationDuration: const Duration(seconds: 1),
                              accelerationCurve: Curves.linear,
                              decelerationDuration: const Duration(milliseconds: 500),
                              decelerationCurve: Curves.easeOut,
                            )
                          : Center(
                              child: Text(
                                _getCurrentSongName(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    if (_isShuffleMode)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          '随机播放',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                  ],
                ),

                // 中间：播放/暂停按钮（适配480x320）
                GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 90,
                      color: Colors.white,
                    ),
                  ),
                ),

                // 下方：上一曲/下一曲按钮（适配480x320）
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 上一曲按钮
                    IconButton(
                      onPressed: _playPrevious,
                      icon: const Icon(Icons.skip_previous),
                      iconSize: 60,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 40),
                    // 下一曲按钮
                    IconButton(
                      onPressed: _playNext,
                      icon: const Icon(Icons.skip_next),
                      iconSize: 60,
                      color: Colors.blue,
                    ),
                  ],
                ),

                // 底部：播放进度条和设置按钮
                Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 5,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 20,
                        ),
                      ),
                      child: Slider(
                        value: _position.inMilliseconds.toDouble(),
                        max: _duration.inMilliseconds.toDouble() > 0
                            ? _duration.inMilliseconds.toDouble()
                            : 1.0,
                        onChanged: (value) async {
                          await _audioPlayer.seek(
                            Duration(milliseconds: value.toInt()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 设置按钮
                    ElevatedButton.icon(
                      onPressed: _navigateToSettings,
                      icon: const Icon(Icons.settings, size: 20),
                      label: const Text(
                        '设置',
                        style: TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  final List<String> currentPlaylist;
  final bool isShuffleMode;

  const SettingsPage({
    super.key,
    required this.currentPlaylist,
    required this.isShuffleMode,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _shuffleMode;
  String? _selectedFolder;
  int _audioFileCount = 0;

  @override
  void initState() {
    super.initState();
    _shuffleMode = widget.isShuffleMode;
    _loadSelectedFolder();
    _audioFileCount = widget.currentPlaylist.length;
  }

  Future<void> _loadSelectedFolder() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedFolder = prefs.getString('selectedFolder');
    });
  }

  Future<void> _pickMusicFolder() async {
    try {
      // 直接选择多个音频文件而不是文件夹
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final List<String> audioFiles = result.paths
            .whereType<String>()
            .toList();

        if (audioFiles.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('未选择音频文件'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        // 按文件名排序
        audioFiles.sort((a, b) {
          final nameA = a.split(Platform.pathSeparator).last.toLowerCase();
          final nameB = b.split(Platform.pathSeparator).last.toLowerCase();
          return nameA.compareTo(nameB);
        });

        // 获取文件夹路径（取第一个文件的父目录）
        final firstFilePath = audioFiles.first;
        final folderPath = firstFilePath.substring(
          0,
          firstFilePath.lastIndexOf(Platform.pathSeparator),
        );

        // 保存到本地存储
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('selectedFolder', folderPath);
        await prefs.setStringList('playlist', audioFiles);
        await prefs.setInt('currentIndex', 0);
        await prefs.setInt('position', 0);

        setState(() {
          _selectedFolder = folderPath;
          _audioFileCount = audioFiles.length;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已导入 ${audioFiles.length} 首歌曲'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('选择文件失败: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleShuffleMode(bool value) async {
    setState(() {
      _shuffleMode = value;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shuffleMode', value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '设置',
          style: TextStyle(fontSize: 20),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 可滚动内容区域
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 导入音乐文件
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '音乐文件',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_selectedFolder != null) ...[
                              Text(
                                '文件位置:',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedFolder!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '共 $_audioFileCount 首歌曲',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            ElevatedButton.icon(
                              onPressed: _pickMusicFolder,
                              icon: const Icon(Icons.library_music, size: 20),
                              label: Text(
                                _selectedFolder == null ? '选择音乐文件' : '重新选择',
                                style: const TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '提示：可同时选择多个音频文件',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 随机播放开关
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '随机播放',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '开启后将随机播放歌曲',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Transform.scale(
                              scale: 1.2,
                              child: Switch(
                                value: _shuffleMode,
                                onChanged: _toggleShuffleMode,
                                activeTrackColor: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 关于链接
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AboutPage()),
                  );
                },
                child: Text(
                  '关于',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ),

            // 固定在底部的返回按钮
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'playlistChanged': _selectedFolder != null,
                  });
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black87,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text(
                  '返回播放器',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '关于',
          style: TextStyle(fontSize: 20),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App图标
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.music_note,
                    size: 60,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 24),
                // App名称
                const Text(
                  '外婆音乐',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nanny Player',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                // 版本号
                Text(
                  'v1.0.0 (2)',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                // 分隔线
                Divider(color: Colors.grey[300]),
                const SizedBox(height: 24),
                // 作者
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      '作者: @MiQieR',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // GitHub链接
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.code, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'https://github.com/MiQieR/NannyPlayer',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 开源协议
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.gavel, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'MIT License',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // 描述
                Text(
                  '专为老年人设计的音乐播放器',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
