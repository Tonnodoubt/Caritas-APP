import 'dart:async';
import 'dart:convert';
import 'package:caritas/Pages/Settings/SettingsProvider.dart';
import 'package:caritas/Utils/SettingsUtil.dart';
import 'package:flutter/services.dart';

import 'package:get_storage/get_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_kit/cloud_kit.dart';

import '../Components/SnackBar.dart';
import '../Models/Db/DbHelper.dart';
import '../Utils/DataSyncUtil.dart';
import '../Utils/PrivacyUtil.dart';
import '../Utils/UmengUtil.dart';
import 'UpdateUtil.dart';

class InitUtil {
  static bool _isInitialized = false;
  static bool _isInitializing = false;
  
  static initBeforeStart() async {
    // 防止重复初始化
    if (_isInitialized || _isInitializing) {
      return;
    }
    _isInitializing = true;
    
    try {
      // 关键初始化：GetStorage（必须快速完成）
      await GetStorage.init();
    } catch (e) {
      // 继续执行，GetStorage 失败不应该阻止应用启动
    }

    try {
      // 关键初始化：Hive Adapters（必须）
      Hive.registerAdapter(ArticleAdapter());
      Hive.registerAdapter(CategoryAdapter());
      Hive.registerAdapter(NoteAdapter());
    } catch (e) {
      _isInitializing = false;
      rethrow; // Adapter 注册失败是严重错误，需要抛出
    }

    try {
      // 关键初始化：Hive（必须）
      await Hive.initFlutter();
    } catch (e) {
      _isInitializing = false;
      rethrow; // Hive 初始化失败是严重错误，需要抛出
    }

    // 关键初始化：打开数据库 Box（必须在启动前完成，否则主页无法加载数据）
    try {
      await Hive.openBox('categories');
      await Hive.openBox('articles');
    } catch (e) {
      // Box 打开失败不应该阻止应用启动
    }

    // 数据库初始化（可以异步，但需要尽快完成）
    try {
      await initBox();
    } catch (e) {
      // 数据库初始化失败不应该阻止应用启动
    }

    // 非关键初始化：Umeng（可以延迟）
    scheduleMicrotask(() {
      try {
        UmengUtil.init();
      } catch (e) {
        // Umeng 初始化失败不应该阻止应用启动
      }
    });
    
    _isInitialized = true;
    _isInitializing = false;
  }

  static initAfterStart(context) async {
    await PrivacyUtil().checkPrivacy(context, false);
    await UpdateUtil().checkUpdate(context, false);
    await UpdateUtil().checkDbUpdate(context, false);
  }

  static initBox() async {
    try {
      bool exists = await Hive.boxExists('articles');
      var cBox = await Hive.openBox('categories');
      var aBox = await Hive.openBox('articles');
      
      // 检查数据库是否为空
      bool isEmpty = cBox.isEmpty || aBox.isEmpty;
      
      if (exists && !isEmpty) {
        print('数据库已存在且不为空，跳过初始化');
        return;
      }

      // 如果数据库为空，清空并重新加载
      if (isEmpty) {
        print('数据库为空，开始加载初始数据...');
        await cBox.clear();
        await aBox.clear();
      } else {
        print('首次安装，开始加载初始数据...');
      }

      print('加载初始数据文件...');
      final String response = await rootBundle.loadString('res/data.json');
      final totalData = await json.decode(response);

      print('导入分类数据...');
      for (Map data in totalData['categories']) {
        Category category = Category(title: data['title']);
        cBox.add(category);
      }
      
      print('导入文章数据...');
      for (Map data in totalData['articles']) {
        Article article = Article.fromJson(data.cast());
        aBox.add(article);
      }
      
      if (totalData["version"] != null) {
        SettingsProvider().setDbVersion(totalData["version"]);
      }
      print('数据库初始化完成，分类数: ${cBox.length}, 文章数: ${aBox.length}');
    } catch (e, stackTrace) {
      print('initBox 失败: $e');
      print('堆栈跟踪: $stackTrace');
      // 不抛出异常，允许应用继续运行
    }
  }

  static iCloudSync(bool localFirst) async {
    try {
      const _key_histories = "histories";
      const _key_favorites = "favorites";

      CloudKit cloudKit = CloudKit('iCloud.top.idealclover.caritas');

      String? cloudHistoryStr = await cloudKit.get(_key_histories);
      // print('cloud history');
      // print(cloudHistoryStr);

      String? cloudFavoriteStr = await cloudKit.get(_key_favorites);
      // print('cloud favorite');
      // print(cloudFavoriteStr);

      Map cloud = {"histories": [], "favorites": []};

      if (cloudHistoryStr != null) {
        cloud["histories"] = List<String>.from(json.decode(cloudHistoryStr));
      }

      if (cloudFavoriteStr != null) {
        cloud["favorites"] = List<String>.from(json.decode(cloudFavoriteStr));
      }

      Map combineRst = await DataSyncUtil.importFromJson(cloud, localFirst);

      bool rst_1 = await cloudKit.save(
          _key_histories, json.encode(combineRst['histories']));
      print(rst_1);
      bool rst_2 = await cloudKit.save(
          _key_favorites, json.encode(combineRst['favorites']));
      print(rst_2);
      if (rst_1 && rst_2) {
        MSnackBar.showSnackBar('同步 iCloud 成功', "");
        print('History sync to icloud');
      }
    } catch (e) {
      print(e);
      MSnackBar.showSnackBar('同步遇到错误', "");
    }
  }
}
