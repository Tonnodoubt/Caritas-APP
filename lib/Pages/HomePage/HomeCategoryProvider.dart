import 'package:hive_flutter/hive_flutter.dart';

import '../../Models/HomeCategoryModel.dart';
import '../../Models/Db/DbHelper.dart';

class HomeCategoryProvider {
  // Future<List<HomeCategory>> getCategorieList() async {
  List<HomeCategory> getCategorieList() {
    try {
      // 检查 box 是否存在
      if (!Hive.isBoxOpen('categories') || !Hive.isBoxOpen('articles')) {
        print('Hive boxes 尚未打开，返回空列表');
        return [];
      }
      
      Box cbox = Hive.box('categories');
      var values = cbox.values;
      // print(values);
      List<HomeCategory> result = [];
      Box aBox = Hive.box("articles");
      // print(aBox.values);
      for (Category category in values) {
        result.add(HomeCategory(
            category.title,
            aBox.values
                .where((article) => article.tags.contains(category.title))
                .toList()
                .cast()));
      }
      // print(result);
      return result;
    } catch (e, stackTrace) {
      print('getCategorieList 失败: $e');
      print('堆栈跟踪: $stackTrace');
      return []; // 返回空列表而不是崩溃
    }
  }

  List<Article> getArticleSearchList(String value) {
    try {
      // 检查 box 是否存在
      if (!Hive.isBoxOpen('articles')) {
        print('articles box 尚未打开，返回空列表');
        return [];
      }
      
      Box aBox = Hive.box("articles");
      List<Article> result = aBox.values
          .where((article) => (article.title.contains(value) ||
              article.content.contains(value)))
          .toList()
          .cast();
      return result;
    } catch (e, stackTrace) {
      print('getArticleSearchList 失败: $e');
      print('堆栈跟踪: $stackTrace');
      return []; // 返回空列表而不是崩溃
    }
  }
}
