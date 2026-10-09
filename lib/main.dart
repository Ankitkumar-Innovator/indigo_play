import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'playlist.dart'; // Model: Song { String title; String artist; String audioPath; String coverPath; }

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IndigoPlayApp());
}

class IndigoPlayApp extends StatelessWidget {
  const IndigoPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IndigoPlay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFF090912),
        primaryColor: Colors.indigoAccent,
        colorScheme: const ColorScheme.light(
          primary: Color.fromARGB(255, 69, 168, 168),
          surface: Color(0xFF131326),
        ),
      ),
      home: const MusicPlayerScreen(),
    );
  }
}

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  late final AudioPlayer _audioPlayer;
  StreamSubscription<ProcessingState>? _processingStateSubscription;

  int _currentIndex = 0;
  bool _isLoading = false;
  bool _isShuffle = false;
  LoopMode _loopMode = LoopMode.off;

  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    _audioPlayer.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace stackTrace) {
        _showErrorSnackBar("Playback error occurred.");
      },
    );

    _processingStateSubscription =
        _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _handleSongCompletion();
      }
    });

    await _loadSong(_currentIndex, autoPlay: false);
  }

  void _handleSongCompletion() {
    if (_loopMode == LoopMode.one) {
      _loadSong(_currentIndex, autoPlay: true);
    } else {
      _playNext();
    }
  }

  Future<void> _loadSong(int index, {bool autoPlay = true}) async {
    if (playlist.isEmpty || index < 0 || index >= playlist.length) return;

    setState(() {
      _currentIndex = index;
      _isLoading = true;
    });

    try {
      await _audioPlayer.setAsset(playlist[index].audioPath);
      if (autoPlay) {
        await _audioPlayer.play();
      }
    } catch (e) {
      debugPrint("Error loading track: $e");
      _showErrorSnackBar("Failed to load audio track.");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _playNext() {
    if (playlist.isEmpty) return;

    int nextIndex;
    if (_isShuffle && playlist.length > 1) {
      do {
        nextIndex = _random.nextInt(playlist.length);
      } while (nextIndex == _currentIndex);
    } else {
      nextIndex = (_currentIndex + 1) % playlist.length;
      if (nextIndex == 0 && _loopMode == LoopMode.off) {
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.pause();
        return;
      }
    }

    _selectSong(nextIndex);
  }

  void _playPrevious() {
    if (playlist.isEmpty) return;

    int prevIndex;
    if (_isShuffle && playlist.length > 1) {
      do {
        prevIndex = _random.nextInt(playlist.length);
      } while (prevIndex == _currentIndex);
    } else {
      prevIndex = (_currentIndex - 1 + playlist.length) % playlist.length;
    }

    _selectSong(prevIndex);
  }

  void _toggleShuffle() {
    setState(() {
      _isShuffle = !_isShuffle;
    });
  }

  void _toggleLoopMode() {
    setState(() {
      if (_loopMode == LoopMode.off) {
        _loopMode = LoopMode.all;
      } else if (_loopMode == LoopMode.all) {
        _loopMode = LoopMode.one;
      } else {
        _loopMode = LoopMode.off;
      }
    });
  }

  void _selectSong(int index) {
    if (index >= 0 && index < playlist.length) {
      _loadSong(index);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openNowPlayingScreen(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: NowPlayingScreen(
              audioPlayer: _audioPlayer,
              currentIndex: _currentIndex,
              isShuffle: _isShuffle,
              loopMode: _loopMode,
              onPlayNext: _playNext,
              onPlayPrevious: _playPrevious,
              onToggleShuffle: _toggleShuffle,
              onToggleLoopMode: _toggleLoopMode,
              onSelectSong: _selectSong,
              formatDuration: _formatDuration,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _processingStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    if (playlist.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text("No songs available in playlist."),
        ),
      );
    }

    final currentSong = playlist[_currentIndex];

    return RgbAmbientFrame(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            "IndigoPlay",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: 2.0,
              color: Colors.cyanAccent,
              shadows: [
                Shadow(color: Colors.cyanAccent, blurRadius: 12),
              ],
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Column(
          children: [
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _openNowPlayingScreen(context),
              child: Hero(
                tag: 'now_playing_art_${_currentIndex}_${currentSong.audioPath}',
                child: FuturisticRgbBorder(
                  child: SizedBox(
                    height: 160,
                    width: 160,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Image.asset(
                          currentSong.coverPath,
                          key: ValueKey<String>(currentSong.coverPath),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFF18182E),
                              child: const Icon(
                                Icons.music_note_rounded,
                                size: 70,
                                color: Colors.cyanAccent,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                currentSong.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                currentSong.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: AudioProgressBar(
                audioPlayer: _audioPlayer,
                formatDuration: _formatDuration,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.shuffle_rounded,
                    color: _isShuffle ? Colors.cyanAccent : Colors.white38,
                    size: 22,
                  ),
                  onPressed: _toggleShuffle,
                ),
                const SizedBox(width: 8),
                IconButton(
                  iconSize: 34,
                  color: Colors.white70,
                  icon: const Icon(Icons.skip_previous_rounded),
                  onPressed: _playPrevious,
                ),
                const SizedBox(width: 12),
                GlowingPlayButton(
                  audioPlayer: _audioPlayer,
                  isLoading: _isLoading,
                  size: 52,
                  iconSize: 28,
                ),
                const SizedBox(width: 12),
                IconButton(
                  iconSize: 34,
                  color: Colors.white70,
                  icon: const Icon(Icons.skip_next_rounded),
                  onPressed: _playNext,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _loopMode == LoopMode.one
                        ? Icons.repeat_one_rounded
                        : Icons.repeat_rounded,
                    color: _loopMode != LoopMode.off
                        ? Colors.cyanAccent
                        : Colors.white38,
                    size: 22,
                  ),
                  onPressed: _toggleLoopMode,
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Divider(color: Colors.white10, height: 1),
            ),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: playlist.length,
                itemBuilder: (context, index) {
                  final song = playlist[index];
                  final isSelected = index == _currentIndex;

                  return Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF1A1A33)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(
                              color: Colors.cyanAccent.withValues(alpha: 0.6),
                              width: 1)
                          : Border.all(color: Colors.transparent),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 0),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          song.coverPath,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 42,
                            height: 42,
                            color: Colors.grey.shade900,
                            child: const Icon(Icons.music_note,
                                color: Colors.cyanAccent),
                          ),
                        ),
                      ),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? Colors.cyanAccent : Colors.white,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 12),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.graphic_eq_rounded,
                              color: Colors.cyanAccent)
                          : const Icon(Icons.play_arrow_rounded,
                              color: Colors.white24),
                      onTap: () {
                        _selectSong(index);
                        _openNowPlayingScreen(context);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NowPlayingScreen extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final int currentIndex;
  final bool isShuffle;
  final LoopMode loopMode;
  final VoidCallback onPlayNext;
  final VoidCallback onPlayPrevious;
  final VoidCallback onToggleShuffle;
  final VoidCallback onToggleLoopMode;
  final ValueChanged<int> onSelectSong;
  final String Function(Duration) formatDuration;

  const NowPlayingScreen({
    super.key,
    required this.audioPlayer,
    required this.currentIndex,
    required this.isShuffle,
    required this.loopMode,
    required this.onPlayNext,
    required this.onPlayPrevious,
    required this.onToggleShuffle,
    required this.onToggleLoopMode,
    required this.onSelectSong,
    required this.formatDuration,
  });

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  late PageController _pageController;
  bool _isPageAnimating = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.currentIndex,
      viewportFraction: 0.82,
    );
  }

  @override
  void didUpdateWidget(covariant NowPlayingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex &&
        _pageController.hasClients) {
      final targetPage = widget.currentIndex;
      if (_pageController.page?.round() != targetPage) {
        _isPageAnimating = true;
        _pageController
            .animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
        )
            .then((_) {
          if (mounted) {
            _isPageAnimating = false;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeSong = playlist[widget.currentIndex];

    return RgbAmbientFrame(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                size: 34, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "NOW PLAYING",
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double coverSize =
                  (constraints.maxHeight * 0.42).clamp(180.0, 320.0);

              return Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    height: coverSize + 20,
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: playlist.length,
                      onPageChanged: (index) {
                        if (!_isPageAnimating && index != widget.currentIndex) {
                          widget.onSelectSong(index);
                        }
                      },
                      itemBuilder: (context, index) {
                        final song = playlist[index];
                        return AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            double value = 0.0;
                            if (_pageController.position.haveDimensions) {
                              value = index - (_pageController.page ?? 0.0);
                            } else {
                              value = (index - widget.currentIndex).toDouble();
                            }

                            final double scale =
                                (1 - (value.abs() * 0.22)).clamp(0.78, 1.0);
                            final double opacity =
                                (1 - (value.abs() * 0.55)).clamp(0.3, 1.0);

                            return Transform.scale(
                              scale: scale,
                              child: Opacity(
                                opacity: opacity,
                                child: Center(
                                  child: Hero(
                                    tag: 'now_playing_art_${index}_${song.audioPath}',
                                    child: FuturisticRgbBorder(
                                      borderWidth: 4,
                                      child: SizedBox(
                                        height: coverSize,
                                        width: coverSize,
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(24),
                                          child: Image.asset(
                                            song.coverPath,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              color: const Color(0xFF14142B),
                                              child: const Icon(
                                                Icons.music_note,
                                                size: 80,
                                                color: Colors.cyanAccent,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          activeSong.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeSong.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: AudioProgressBar(
                      audioPlayer: widget.audioPlayer,
                      formatDuration: widget.formatDuration,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.shuffle_rounded,
                            color: widget.isShuffle
                                ? Colors.cyanAccent
                                : Colors.white38,
                            size: 26,
                          ),
                          onPressed: widget.onToggleShuffle,
                        ),
                        IconButton(
                          iconSize: 40,
                          color: Colors.white,
                          icon: const Icon(Icons.skip_previous_rounded),
                          onPressed: widget.onPlayPrevious,
                        ),
                        GlowingPlayButton(
                          audioPlayer: widget.audioPlayer,
                          size: 64,
                          iconSize: 34,
                        ),
                        IconButton(
                          iconSize: 40,
                          color: Colors.white,
                          icon: const Icon(Icons.skip_next_rounded),
                          onPressed: widget.onPlayNext,
                        ),
                        IconButton(
                          icon: Icon(
                            widget.loopMode == LoopMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                            color: widget.loopMode != LoopMode.off
                                ? Colors.cyanAccent
                                : Colors.white38,
                            size: 26,
                          ),
                          onPressed: widget.onToggleLoopMode,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class AudioProgressBar extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final String Function(Duration) formatDuration;

  const AudioProgressBar({
    super.key,
    required this.audioPlayer,
    required this.formatDuration,
  });

  @override
  State<AudioProgressBar> createState() => _AudioProgressBarState();
}

class _AudioProgressBarState extends State<AudioProgressBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.audioPlayer.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = widget.audioPlayer.duration ?? Duration.zero;
        final maxMilliseconds = duration.inMilliseconds > 0
            ? duration.inMilliseconds.toDouble()
            : 1.0;
        final currentMilliseconds =
            (_dragValue ?? position.inMilliseconds.toDouble())
                .clamp(0.0, maxMilliseconds);

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                activeTrackColor: Colors.cyanAccent,
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.cyanAccent,
                overlayColor: Colors.cyanAccent.withValues(alpha: 0.2),
              ),
              child: Slider(
                min: 0.0,
                max: maxMilliseconds,
                value: currentMilliseconds,
                onChanged: (val) {
                  setState(() {
                    _dragValue = val;
                  });
                },
                onChangeEnd: (val) {
                  widget.audioPlayer.seek(Duration(milliseconds: val.toInt()));
                  setState(() {
                    _dragValue = null;
                  });
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.formatDuration(
                      Duration(milliseconds: currentMilliseconds.toInt())),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  widget.formatDuration(duration),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class GlowingPlayButton extends StatelessWidget {
  final AudioPlayer audioPlayer;
  final bool isLoading;
  final double size;
  final double iconSize;

  const GlowingPlayButton({
    super.key,
    required this.audioPlayer,
    this.isLoading = false,
    this.size = 64,
    this.iconSize = 36,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(color: Colors.cyanAccent),
      );
    }

    return StreamBuilder<PlayerState>(
      stream: audioPlayer.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final playing = playerState?.playing ?? false;
        final processingState = playerState?.processingState;

        if (processingState == ProcessingState.loading ||
            processingState == ProcessingState.buffering) {
          return SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(color: Colors.cyanAccent),
          );
        }

        final IconData icon = (!playing)
            ? Icons.play_arrow_rounded
            : (processingState != ProcessingState.completed)
                ? Icons.pause_rounded
                : Icons.replay_rounded;

        return GestureDetector(
          onTap: () async {
            try {
              if (!playing) {
                await audioPlayer.play();
              } else if (processingState != ProcessingState.completed) {
                await audioPlayer.pause();
              } else {
                await audioPlayer.seek(Duration.zero);
                await audioPlayer.play();
              }
            } catch (e) {
              debugPrint("Playback toggle error: $e");
            }
          },
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Colors.cyanAccent, Colors.indigoAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withValues(alpha: 0.5),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                icon,
                size: iconSize,
                color: const Color(0xFF090912),
              ),
            ),
          ),
        );
      },
    );
  }
}

class FuturisticRgbBorder extends StatefulWidget {
  final Widget child;
  final double borderWidth;

  const FuturisticRgbBorder({
    super.key,
    required this.child,
    this.borderWidth = 3.0,
  });

  @override
  State<FuturisticRgbBorder> createState() => _FuturisticRgbBorderState();
}

class _FuturisticRgbBorderState extends State<FuturisticRgbBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.all(widget.borderWidth),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: SweepGradient(
              transform: GradientRotation(_controller.value * 2 * math.pi),
              colors: const [
                Colors.cyanAccent,
                Colors.indigoAccent,
                Colors.purpleAccent,
                Colors.cyanAccent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}

class RgbAmbientFrame extends StatelessWidget {
  final Widget child;

  const RgbAmbientFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.8, -0.8),
          radius: 1.4,
          colors: [
            Color(0xFF131333),
            Color(0xFF090912),
          ],
        ),
      ),
      child: child,
    );
  }
}