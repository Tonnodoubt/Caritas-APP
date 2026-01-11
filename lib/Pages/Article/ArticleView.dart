import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../generated/l10n.dart';

// import 'package:audioplayers/audioplayers.dart';
import 'package:just_audio/just_audio.dart';
import 'ArticlePresenter.dart';
import '../Settings/SettingsProvider.dart';
import '../../Components/ArticleList.dart';
import '../../Components/SnackBar.dart';
import '../../Components/Markdown.dart';
import '../../Components/NoteDialog.dart';
import '../../Models/Db/DbHelper.dart';
import '../../Models/NoteProvider.dart';
import '../../Utils/UmengUtil.dart';
import '../../Utils/URLUtil.dart';
import 'dart:math';
import 'dart:async';

class ArticleView extends StatefulWidget {
  final Article article;
  final Function? getPre;
  final Function? getNext;

  const ArticleView(this.article, {this.getPre, this.getNext, Key? key})
      : super(key: key);

  @override
  State<ArticleView> createState() => _ArticleViewState();
}

class _ArticleViewState extends State<ArticleView> {
  /// 解释下为什么要有 actualArticle:
  /// 这个是随机文章场景引入的 因为随机文章会打乱原来列表中的上下文顺序
  /// 所以需要有一个实际的文章，表示当前列表里的文章
  /// 这样即使表层的文章展示成了其他文章，上下文的锚点也能定位到
  late Article article;
  late Article actualArticle;

  late bool isFavorite;
  bool isPlaying = false;
  final player = AudioPlayer();
  
  final NoteProvider _noteProvider = NoteProvider();
  List<Note> _notes = [];
  String? _selectedText;
  int? _selectedStartOffset;
  int? _selectedEndOffset;

  @override
  void initState() {
    actualArticle = article = widget.article;
    _loadNotes();
    super.initState();
  }

  Future<void> _loadNotes() async {
    final notes = await _noteProvider.getNotesByArticleId(article.id);
    setState(() {
      _notes = notes;
    });
  }

  Future<void> _handleTextSelection(String selectedText, int startOffset, int endOffset) async {
    setState(() {
      _selectedText = selectedText;
      _selectedStartOffset = startOffset;
      _selectedEndOffset = endOffset;
    });
    
    // 检查是否已有笔记覆盖这个位置
    Note? existingNote;
    for (var note in _notes) {
      if (note.startOffset <= startOffset && note.endOffset >= endOffset) {
        existingNote = note;
        break;
      }
    }

    final result = await showDialog(
      context: context,
      builder: (context) => NoteDialog(
        note: existingNote,
        selectedText: selectedText,
        articleId: article.id,
        articleTitle: article.title,
      ),
    );

    if (result == null) return;

    if (result == true && existingNote != null) {
      // 删除笔记
      await _noteProvider.deleteNote(existingNote.id);
      MSnackBar.showSnackBar(S.of(context).note_deleted_toast, "");
      await _loadNotes();
      return;
    }

    if (result is Map) {
      final noteContent = result['noteContent'] as String;
      final color = result['color'] as String;

      if (existingNote != null) {
        // 更新笔记
        existingNote.noteContent = noteContent;
        existingNote.color = color;
        await _noteProvider.updateNote(existingNote);
        MSnackBar.showSnackBar(S.of(context).note_updated_toast, "");
      } else {
        // 创建新笔记
        final note = Note(
          id: DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(1000).toString(),
          articleId: article.id,
          articleTitle: article.title,
          selectedText: selectedText,
          noteContent: noteContent,
          startOffset: startOffset,
          endOffset: endOffset,
          color: color,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _noteProvider.addNote(note);
        MSnackBar.showSnackBar(S.of(context).note_added_toast, "");
      }
      await _loadNotes();
    }
  }

  @override
  void dispose() {
    player.stop();
    super.dispose();
  }

  /// 打开上一篇/下一篇通过直接刷新当前页面的形式，而不是新建页面
  /// 原因是担心顺序浏览的时候同时开启的页面过多，不好进行回退
  Widget getArticleWidget(String title, Article? targetArticle) {
    if (targetArticle == null) return Container();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.all(5.0)),
        ListTile(title: Text(title)),
        const Divider(height: 1),
        ListTile(
            title: Text(targetArticle.title),
            subtitle:
                Text(targetArticle.question, overflow: TextOverflow.ellipsis),
            onTap: (() async {
              setState(() => {actualArticle = article = targetArticle});
              // ArticlePresenter ap = ArticlePresenter();
              // ap.setAsRead(targetArticle);
              ScrollController? sc = PrimaryScrollController.of(context);
              if (sc == null) return;
              sc.animateTo(0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.ease);
              await player.stop();
              setState(() {
                isPlaying = false;
              });
            })),
        const Divider(height: 1),
        const Padding(padding: EdgeInsets.all(5.0)),
      ],
    );
  }

  /// 打开随机文章通过直接刷新当前页面的形式，而不是新建页面
  /// 原因是担心顺序浏览的时候同时开启的页面过多，不好进行回退
  /// 单独写成函数的原因是特殊逻辑比较多
  Widget getRandomArticleWidget(List<Article> articles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.all(5.0)),
        ListTile(title: Text(S.of(context).random_article)),
        const Divider(height: 1),

        /// TODO: 懒了 先这么实现着吧 反正也没两行代码
        /// 注意：对于随机文章，只变更 article，不变更 actualArticle
        ListTile(
            title: Text(articles[0].title),
            subtitle:
                Text(articles[0].question, overflow: TextOverflow.ellipsis),
            onTap: (() async {
              setState(() => {article = articles[0]});
              // ArticlePresenter ap = ArticlePresenter();
              // ap.setAsRead(targetArticle);
              ScrollController? sc = PrimaryScrollController.of(context);
              if (sc == null) return;
              sc.animateTo(0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.ease);
              await player.stop();
              setState(() {
                isPlaying = false;
              });
            })),
        const Divider(height: 1),
        ListTile(
            title: Text(articles[1].title),
            subtitle:
                Text(articles[1].question, overflow: TextOverflow.ellipsis),
            onTap: (() async {
              setState(() => {article = articles[1]});
              // ArticlePresenter ap = ArticlePresenter();
              // ap.setAsRead(targetArticle);
              ScrollController? sc = PrimaryScrollController.of(context);
              if (sc == null) return;
              sc.animateTo(0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.ease);
              await player.stop();
              setState(() {
                isPlaying = false;
              });
            })),
        const Divider(height: 1),
        ListTile(
            title: Text("随机文章"),
            subtitle: Text("不打开不知道是什么的随机文章", overflow: TextOverflow.ellipsis),
            onTap: (() async {
              setState(() => {article = articles[2]});
              // ArticlePresenter ap = ArticlePresenter();
              // ap.setAsRead(targetArticle);
              ScrollController? sc = PrimaryScrollController.of(context);
              if (sc == null) return;
              sc.animateTo(0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.ease);
              await player.stop();
              setState(() {
                isPlaying = false;
              });
            })),
        const Divider(height: 1),
        const Padding(padding: EdgeInsets.all(5.0)),
      ],
    );
  }

  Article? getPreArticle() {
    if (widget.getPre == null || widget.getPre!(actualArticle) == null) {
      return null;
    }
    return widget.getPre!(actualArticle);
  }

  Article? getNextArticle() {
    if (widget.getNext == null || widget.getNext!(actualArticle) == null) {
      return null;
    }
    return widget.getNext!(actualArticle);
  }

  @override
  Widget build(BuildContext context) {
    List<String> favList = SettingsProvider().getFavorites();
    isFavorite = favList.contains(article.id);
    ArticlePresenter ap = ArticlePresenter();
    ap.setAsRead(article);
    UmengUtil.onEvent("open_article", {"aid": article.id});

    return Scaffold(
        appBar: AppBar(
          title: Text(article.title),
          actions: [
            isPlaying
                ? IconButton(
                    icon: const Icon(Icons.stop_circle_outlined),
                    onPressed: () async {
                      await player.stop();
                      setState(() {
                        isPlaying = false;
                      });
                    })
                : IconButton(
                    icon: const Icon(Icons.headphones),
                    onPressed: () async {
                      const baseUrl =
                          "https://cdn.idealclover.cn/Projects/caritas/audio/";
                      String audioUrl = Uri.encodeFull(
                          "$baseUrl${article.tags.last}/${article.title}.mp3");
                      // print(audioUrl);
                      try {
                        await player.setUrl(audioUrl);
                        player.play();
                        setState(() {
                          isPlaying = true;
                        });
                        UmengUtil.onEvent("play_audio",
                            {"aid": article.id, "type": "manual"});
                      } catch (e) {
                        setState(() {
                          isPlaying = false;
                        });
                        MSnackBar.showSnackBar('无网络或无当前文章声音资源 TvT', "");
                      }

                      player.playerStateStream.listen((playerState) async {
                        if (playerState.processingState ==
                            ProcessingState.completed) {
                          Article? targetArticle = getNextArticle();
                          if (targetArticle == null) {
                            return;
                          }
                          setState(() => {
                                article = targetArticle,
                                actualArticle = targetArticle
                              });
                          // ArticlePresenter ap = ArticlePresenter();
                          // ap.setAsRead(targetArticle);
                          ScrollController? sc =
                              PrimaryScrollController.of(context);
                          if (sc == null) return;
                          sc.animateTo(0,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.ease);
                          audioUrl = Uri.encodeFull(
                              "$baseUrl${article.tags.last}/${targetArticle.title}.mp3");
                          try {
                            await player.setUrl(audioUrl);
                            player.play();
                            UmengUtil.onEvent("play_audio",
                                {"aid": article.id, "type": "auto"});
                          } catch (e) {
                            setState(() {
                              isPlaying = false;
                            });
                            MSnackBar.showSnackBar('无网络或无当前文章声音资源 TvT', "");
                          }
                        }
                      });
                    },
                  ),
            IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  semanticLabel: S.of(context).fav_button,
                  color: isFavorite ? Colors.red : Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    isFavorite = !isFavorite;
                    SettingsProvider().setFavorites(article.id);
                    if (isFavorite) {
                      MSnackBar.showSnackBar(S.of(context).fav_add_toast, "");
                      // Toast.showToast(S.of(context).fav_add_toast, context);
                    } else {
                      MSnackBar.showSnackBar(S.of(context).fav_del_toast, "");
                      // Toast.showToast(S.of(context).fav_del_toast, context);
                    }
                  });
                }),
            article.zhihuLink != ''
                ? IconButton(
                    icon: Icon(
                      Icons.explore,
                      semanticLabel: S.of(context).open_in_browser_button,
                    ),
                    onPressed: () async {
                      await URLUtil.openUrl(article.zhihuLink, context);
                    })
                : Container(),
            IconButton(
              icon: Icon(
                Icons.note_add,
                semanticLabel: S.of(context).add_note,
              ),
              onPressed: () async {
                // 显示输入对话框让用户输入要标注的文本
                final textController = TextEditingController();
                final result = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(S.of(context).add_note),
                    content: TextField(
                      controller: textController,
                      decoration: InputDecoration(
                        labelText: '请输入要标注的文本',
                        hintText: '可以从文章中复制文本后粘贴到这里',
                      ),
                      maxLines: 3,
                      autofocus: true,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(S.of(context).cancel),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (textController.text.isNotEmpty) {
                            Navigator.of(context).pop(textController.text);
                          }
                        },
                        child: Text(S.of(context).ok),
                      ),
                    ],
                  ),
                );

                if (result != null && result.isNotEmpty) {
                  final fullContent = '# ${article.title}\n    作者: ${article.author} 最近更新: ${article.lastUpdate}\n\n${article.question == "" ? "" : ">${article.question}\n\n"}${article.content}';
                  final startOffset = fullContent.indexOf(result);
                  final endOffset = startOffset != -1 ? startOffset + result.length : result.length;
                  _handleTextSelection(result, startOffset != -1 ? startOffset : 0, endOffset);
                }
              },
            ),
          ],
        ),
        body: Scrollbar(
            child: SingleChildScrollView(
          primary: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildMarkdownWithNotes()),
              // '# ${article.title}\n${article.zhihuLink == "" ? article.question : "[${article.question}](${article.zhihuLink})"}\n\n> 最后更新: ${article.lastUpdate}\n\n${article.content}')),
              // child: MMarkdown(article.content)),
              getArticleWidget(S.of(context).pre_article, getPreArticle()),
              getArticleWidget(S.of(context).next_article, getNextArticle()),
              FutureBuilder<List<Article>>(
                  future: ap.getArticleList(article),
                  builder: (BuildContext context,
                      AsyncSnapshot<List<Article>> snapshot) {
                    return snapshot.hasData && snapshot.data!.isNotEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(padding: EdgeInsets.all(5.0)),
                              ListTile(
                                  title: Text(S.of(context).related_article)),
                              const Divider(height: 1),
                              ArticleList(snapshot.data!),
                              const Padding(padding: EdgeInsets.all(5.0)),
                            ],
                          )
                        : Container();
                  }),
              FutureBuilder<List<Article>>(
                  future: ap.getRandomArticleList(3),
                  builder: (BuildContext context,
                      AsyncSnapshot<List<Article>> snapshot) {
                    return snapshot.hasData && snapshot.data!.isNotEmpty
                        ? getRandomArticleWidget(snapshot.data!)
                        : Container();
                  }),
              const Padding(padding: EdgeInsets.all(5.0)),
              // 笔记列表
              if (_notes.isNotEmpty) _buildNotesSection(),
            ],
          ),
        )));
  }

  Widget _buildMarkdownWithNotes() {
    final fullContent = '# ${article.title}\n    作者: ${article.author} 最近更新: ${article.lastUpdate}\n\n${article.question == "" ? "" : ">${article.question}\n\n"}${article.content}';
    
    return _SelectableMarkdownWithNotes(
      content: fullContent,
      onTextSelected: (selectedText, startOffset, endOffset) {
        _handleTextSelection(selectedText, startOffset, endOffset);
      },
      child: MMarkdown(fullContent),
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.all(5.0)),
        ListTile(
          title: Text('${S.of(context).notes_title} (${_notes.length})'),
          leading: const Icon(Icons.note),
        ),
        const Divider(height: 1),
        ..._notes.map((note) => _buildNoteItem(note)),
        const Padding(padding: EdgeInsets.all(5.0)),
      ],
    );
  }

  Widget _buildNoteItem(Note note) {
    Color _hexToColor(String hex) {
      final hexCode = hex.replaceAll('#', '');
      return Color(int.parse('FF$hexCode', radix: 16));
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 4,
          height: double.infinity,
          color: _hexToColor(note.color),
        ),
        title: Text(
          note.selectedText,
          style: TextStyle(
            backgroundColor: _hexToColor(note.color).withOpacity(0.2),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: note.noteContent.isNotEmpty
            ? Text(
                note.noteContent,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () async {
            final result = await showDialog(
              context: context,
              builder: (context) => NoteDialog(
                note: note,
                selectedText: note.selectedText,
                articleId: article.id,
                articleTitle: article.title,
              ),
            );

            if (result == true) {
              // 删除
              await _noteProvider.deleteNote(note.id);
              MSnackBar.showSnackBar(S.of(context).note_deleted_toast, "");
              await _loadNotes();
            } else if (result is Map) {
              // 更新
              note.noteContent = result['noteContent'] as String;
              note.color = result['color'] as String;
              await _noteProvider.updateNote(note);
              MSnackBar.showSnackBar(S.of(context).note_updated_toast, "");
              await _loadNotes();
            }
          },
        ),
        onTap: () async {
          // 显示完整笔记
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(S.of(context).notes_title),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      note.selectedText,
                      style: TextStyle(
                        backgroundColor: _hexToColor(note.color).withOpacity(0.2),
                        fontSize: 16,
                      ),
                    ),
                    if (note.noteContent.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        note.noteContent,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(S.of(context).ok),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 可选择的 Markdown Widget，支持自动检测文本选择并弹出笔记对话框
class _SelectableMarkdownWithNotes extends StatefulWidget {
  final String content;
  final Function(String selectedText, int startOffset, int endOffset) onTextSelected;
  final Widget child;

  const _SelectableMarkdownWithNotes({
    Key? key,
    required this.content,
    required this.onTextSelected,
    required this.child,
  }) : super(key: key);

  @override
  State<_SelectableMarkdownWithNotes> createState() => _SelectableMarkdownWithNotesState();
}

class _SelectableMarkdownWithNotesState extends State<_SelectableMarkdownWithNotes> {
  String? _selectedText;
  int? _startOffset;
  int? _endOffset;
  Timer? _selectionCheckTimer;
  bool _showAddNoteButton = false;
  String? _lastClipboardText;
  DateTime? _lastCheckTime;

  @override
  void initState() {
    super.initState();
    // 延迟启动定时器，避免影响页面加载
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        // 降低检查频率，减少性能影响
        _selectionCheckTimer = Timer.periodic(const Duration(milliseconds: 2000), (timer) {
          _checkTextSelection();
        });
      }
    });
  }

  @override
  void dispose() {
    _selectionCheckTimer?.cancel();
    super.dispose();
  }

  void _checkTextSelection() async {
    if (!mounted) return;
    
    // 限制检查频率，避免性能问题
    final now = DateTime.now();
    if (_lastCheckTime != null && now.difference(_lastCheckTime!) < const Duration(milliseconds: 1000)) {
      return;
    }
    _lastCheckTime = now;
    
    try {
      // 尝试从剪贴板获取最近选择的文本（使用超时避免阻塞）
      final clipboard = await Clipboard.getData(Clipboard.kTextPlain).timeout(
        const Duration(milliseconds: 100),
        onTimeout: () => const ClipboardData(text: ''),
      );
      final clipboardText = clipboard?.text?.trim();
      
      // 如果剪贴板为空或与上次相同，隐藏按钮
      if (clipboardText == null || clipboardText.isEmpty) {
        if (_showAddNoteButton) {
          setState(() {
            _showAddNoteButton = false;
            _selectedText = null;
            _startOffset = null;
            _endOffset = null;
            _lastClipboardText = null;
          });
        }
        return;
      }

      // 如果剪贴板内容没有变化，不处理
      if (clipboardText == _lastClipboardText) {
        return;
      }
      
      _lastClipboardText = clipboardText;

      // 只处理较短的文本（避免处理用户复制的大段文本）
      if (clipboardText.length > 500 || clipboardText.length < 2) {
        return;
      }

      // 使用 compute 在后台线程中搜索，避免阻塞 UI
      // 但为了简化，先使用简单的检查
      // 如果内容太长，限制搜索范围
      final content = widget.content;
      final maxSearchLength = content.length > 10000 ? 10000 : content.length;
      final searchContent = content.substring(0, maxSearchLength);
      
      final startOffset = searchContent.indexOf(clipboardText);
      if (startOffset != -1) {
        final endOffset = startOffset + clipboardText.length;
        
        // 显示添加笔记按钮
        if (mounted) {
          setState(() {
            _selectedText = clipboardText;
            _startOffset = startOffset;
            _endOffset = endOffset;
            _showAddNoteButton = true;
          });
        }
        
        // 延迟一下，然后自动弹出笔记对话框
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted && _showAddNoteButton && _selectedText == clipboardText) {
            // 再次确认剪贴板内容仍然匹配
            Clipboard.getData(Clipboard.kTextPlain).timeout(
              const Duration(milliseconds: 100),
              onTimeout: () => const ClipboardData(text: ''),
            ).then((currentClipboard) {
              final currentText = currentClipboard?.text?.trim();
              if (currentText == clipboardText && mounted && _showAddNoteButton) {
                _handleAddNote();
              }
            });
          }
        });
      }
    } catch (e) {
      // 忽略错误，继续运行
    }
  }

  void _handleAddNote() {
    if (_selectedText != null && _startOffset != null && _endOffset != null) {
      widget.onTextSelected(_selectedText!, _startOffset!, _endOffset!);
      // 隐藏按钮并清空剪贴板
      if (mounted) {
        setState(() {
          _showAddNoteButton = false;
          _selectedText = null;
          _startOffset = null;
          _endOffset = null;
          _lastClipboardText = null;
        });
      }
      // 清空剪贴板，避免重复触发
      Clipboard.setData(const ClipboardData(text: '')).catchError((e) {
        // 忽略清空剪贴板的错误
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SelectionArea(
          child: widget.child,
        ),
        // 显示添加笔记的浮动按钮
        if (_showAddNoteButton)
          Positioned(
            bottom: 20,
            right: 20,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(28),
              child: InkWell(
                onTap: _handleAddNote,
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.note_add, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        S.of(context).add_note,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
