import 'package:hive_flutter/hive_flutter.dart';
import 'Db/DbHelper.dart';

class NoteProvider {
  static const String _boxName = 'notes';

  Future<Box<Note>> _getBox() async {
    return await Hive.openBox<Note>(_boxName);
  }

  /// 添加笔记
  Future<void> addNote(Note note) async {
    final box = await _getBox();
    await box.put(note.id, note);
  }

  /// 更新笔记
  Future<void> updateNote(Note note) async {
    final box = await _getBox();
    note.updatedAt = DateTime.now();
    await box.put(note.id, note);
  }

  /// 删除笔记
  Future<void> deleteNote(String noteId) async {
    final box = await _getBox();
    await box.delete(noteId);
  }

  /// 根据 ID 获取笔记
  Future<Note?> getNote(String noteId) async {
    final box = await _getBox();
    return box.get(noteId);
  }

  /// 获取文章的所有笔记
  Future<List<Note>> getNotesByArticleId(String articleId) async {
    final box = await _getBox();
    return box.values
        .where((note) => note.articleId == articleId)
        .toList()
      ..sort((a, b) => a.startOffset.compareTo(b.startOffset));
  }

  /// 获取所有笔记
  Future<List<Note>> getAllNotes() async {
    final box = await _getBox();
    return box.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// 搜索笔记
  Future<List<Note>> searchNotes(String keyword) async {
    final box = await _getBox();
    final lowerKeyword = keyword.toLowerCase();
    return box.values
        .where((note) =>
            note.selectedText.toLowerCase().contains(lowerKeyword) ||
            note.noteContent.toLowerCase().contains(lowerKeyword) ||
            note.articleTitle.toLowerCase().contains(lowerKeyword))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// 获取笔记数量
  Future<int> getNoteCount() async {
    final box = await _getBox();
    return box.length;
  }

  /// 获取文章的笔记数量
  Future<int> getNoteCountByArticleId(String articleId) async {
    final box = await _getBox();
    return box.values.where((note) => note.articleId == articleId).length;
  }

  /// 清空所有笔记
  Future<void> clearAllNotes() async {
    final box = await _getBox();
    await box.clear();
  }
}

