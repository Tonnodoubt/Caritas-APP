import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../Models/Db/DbHelper.dart';
import '../generated/l10n.dart';

class NoteDialog extends StatefulWidget {
  final Note? note;
  final String selectedText;
  final String articleId;
  final String articleTitle;

  const NoteDialog({
    Key? key,
    this.note,
    required this.selectedText,
    required this.articleId,
    required this.articleTitle,
  }) : super(key: key);

  @override
  State<NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<NoteDialog> {
  late TextEditingController _noteController;
  late String _selectedColor;
  final List<String> _colors = [
    '#FFFF00', // 黄色
    '#FF6B6B', // 红色
    '#4ECDC4', // 青色
    '#95E1D3', // 浅绿色
    '#F38181', // 粉红色
    '#AA96DA', // 紫色
    '#FCBAD3', // 浅粉色
  ];

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(
      text: widget.note?.noteContent ?? '',
    );
    _selectedColor = widget.note?.color ?? '#FFFF00';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.note == null
          ? S.of(context).add_note
          : S.of(context).edit_note),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 选中的文本
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).selected_text,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.selectedText,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 笔记内容输入
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: S.of(context).note_content,
                hintText: S.of(context).note_content_hint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 5,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            // 颜色选择
            Text(
              S.of(context).highlight_color,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _colors.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _hexToColor(color),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.black, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.of(context).cancel),
        ),
        if (widget.note != null)
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(true); // true 表示删除
            },
            child: Text(
              S.of(context).delete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop({
              'noteContent': _noteController.text,
              'color': _selectedColor,
            });
          },
          child: Text(widget.note == null
              ? S.of(context).add
              : S.of(context).save),
        ),
      ],
    );
  }
}

