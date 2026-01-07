import 'package:flutter/material.dart';
import '../../generated/l10n.dart';
import '../../Models/Db/DbHelper.dart';
import '../../Models/NoteProvider.dart';
import '../../Components/SnackBar.dart';
import '../../Components/NoteDialog.dart';
import '../Article/ArticleView.dart';
import '../Article/ArticlePresenter.dart';

class NotesView extends StatefulWidget {
  const NotesView({Key? key}) : super(key: key);

  @override
  State<NotesView> createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesView> {
  final NoteProvider _noteProvider = NoteProvider();
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _searchController.addListener(_filterNotes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });
    final notes = await _noteProvider.getAllNotes();
    setState(() {
      _notes = notes;
      _filteredNotes = notes;
      _isLoading = false;
    });
  }

  void _filterNotes() {
    final keyword = _searchController.text.toLowerCase();
    if (keyword.isEmpty) {
      setState(() {
        _filteredNotes = _notes;
      });
    } else {
      setState(() {
        _filteredNotes = _notes
            .where((note) =>
                note.selectedText.toLowerCase().contains(keyword) ||
                note.noteContent.toLowerCase().contains(keyword) ||
                note.articleTitle.toLowerCase().contains(keyword))
            .toList();
      });
    }
  }

  Color _hexToColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  Future<void> _editNote(Note note) async {
    final result = await showDialog(
      context: context,
      builder: (context) => NoteDialog(
        note: note,
        selectedText: note.selectedText,
        articleId: note.articleId,
        articleTitle: note.articleTitle,
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
  }

  Future<void> _openArticle(Note note) async {
    final articlePresenter = ArticlePresenter();
    final article = await articlePresenter.getArticleById(note.articleId);
    if (article != null) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ArticleView(article),
        ),
      );
      await _loadNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).note_list_title),
        actions: [
          if (_notes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(S.of(context).delete),
                    content: Text('确定要删除所有笔记吗？此操作不可恢复。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(S.of(context).cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: Text(S.of(context).delete),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _noteProvider.clearAllNotes();
                  MSnackBar.showSnackBar('所有笔记已删除', "");
                  await _loadNotes();
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: S.of(context).notes_search_hint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          // 笔记列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredNotes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.note_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              S.of(context).notes_empty,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredNotes.length,
                        itemBuilder: (context, index) {
                          final note = _filteredNotes[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: Container(
                                width: 4,
                                height: double.infinity,
                                color: _hexToColor(note.color),
                              ),
                              title: Text(
                                note.selectedText,
                                style: TextStyle(
                                  backgroundColor:
                                      _hexToColor(note.color).withOpacity(0.2),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (note.noteContent.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        note.noteContent,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    S.of(context).note_from_article(note.articleTitle),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.open_in_new, size: 20),
                                        const SizedBox(width: 8),
                                        Text(S.of(context).open_in_browser_button),
                                      ],
                                    ),
                                    onTap: () => _openArticle(note),
                                  ),
                                  PopupMenuItem(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.edit, size: 20),
                                        const SizedBox(width: 8),
                                        Text(S.of(context).edit_note),
                                      ],
                                    ),
                                    onTap: () => _editNote(note),
                                  ),
                                  PopupMenuItem(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.delete, size: 20, color: Colors.red),
                                        const SizedBox(width: 8),
                                        Text(
                                          S.of(context).delete,
                                          style: const TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                    onTap: () async {
                                      await _noteProvider.deleteNote(note.id);
                                      MSnackBar.showSnackBar(
                                          S.of(context).note_deleted_toast, "");
                                      await _loadNotes();
                                    },
                                  ),
                                ],
                              ),
                              onTap: () => _editNote(note),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

