import 'package:flutter/material.dart';
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
import 'package:flutter/services.dart';

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
    
    return GestureDetector(
      onLongPress: () {
        // 长按提示用户选择文本
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('请选择文本后，使用右上角的笔记按钮添加笔记'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: SelectionArea(
        child: MMarkdown(fullContent),
      ),
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
