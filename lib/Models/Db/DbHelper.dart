import 'package:hive/hive.dart';

// assuming that your file is called filename.dart. This will give an error at
// first, but it's needed for drift to know about the generated code
part 'DbHelper.g.dart';

// @DataClassName('Category')
// class Categories extends Table {
//   IntColumn get id => integer().autoIncrement()();
//   TextColumn get title => text()();
//   TextColumn get contents => text()();
// }

@HiveType(typeId: 0)
class Category extends HiveObject {
  @HiveField(0)
  String title;

  Category({required this.title});
}

@HiveType(typeId: 1)
class Article extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String question;

  @HiveField(3)
  String content;

  @HiveField(4)
  String zhihuLink = '';

  @HiveField(5)
  String author;

  @HiveField(6)
  List<String> tags = [];

  @HiveField(7)
  List<String> links = [];

  @HiveField(8)
  List<String> categories = [];

  @HiveField(9)
  String lastUpdate;

  Article(
      {required this.id,
      required this.title,
      required this.question,
      required this.content,
      this.zhihuLink = '',
      required this.author,
      this.tags = const [],
      this.links = const [],
      this.categories = const [],
      required this.lastUpdate});

  Article.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        title = json['title'],
        question = json['question'],
        content = json['content'],
        // zhihuLink = json['zhihulink'] ?? '',
        zhihuLink = json['zhihuLink'] ?? '',
        author = json['author'],
        tags = List<String>.from(json['tags']),
        links = List<String>.from(json['links']),
        categories = List<String>.from(json['categories'] ?? const []),
        // lastUpdate = json['lastupdate'] ?? '';
        lastUpdate = json['lastUpdate'] ?? '';
}

@HiveType(typeId: 2)
class Note extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String articleId;

  @HiveField(2)
  String articleTitle;

  @HiveField(3)
  String selectedText;

  @HiveField(4)
  String noteContent;

  @HiveField(5)
  int startOffset;

  @HiveField(6)
  int endOffset;

  @HiveField(7)
  String color;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  DateTime updatedAt;

  Note({
    required this.id,
    required this.articleId,
    required this.articleTitle,
    required this.selectedText,
    required this.noteContent,
    required this.startOffset,
    required this.endOffset,
    this.color = '#FFFF00',
    required this.createdAt,
    required this.updatedAt,
  });

  Note.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        articleId = json['articleId'],
        articleTitle = json['articleTitle'],
        selectedText = json['selectedText'],
        noteContent = json['noteContent'],
        startOffset = json['startOffset'],
        endOffset = json['endOffset'],
        color = json['color'] ?? '#FFFF00',
        createdAt = DateTime.parse(json['createdAt']),
        updatedAt = DateTime.parse(json['updatedAt']);

  Map<String, dynamic> toJson() => {
        'id': id,
        'articleId': articleId,
        'articleTitle': articleTitle,
        'selectedText': selectedText,
        'noteContent': noteContent,
        'startOffset': startOffset,
        'endOffset': endOffset,
        'color': color,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}