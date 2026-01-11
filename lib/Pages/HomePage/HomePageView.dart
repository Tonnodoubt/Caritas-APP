import 'package:flutter/material.dart' hide SearchBar;
import 'package:flutter_search_bar/flutter_search_bar.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../Components/SnackBar.dart';
import '../../generated/l10n.dart';
import 'HomeCategoryProvider.dart';
import '../../Components/ArticleList.dart';
import '../../Components/Drawer.dart';
import '../../Models/Db/DbHelper.dart';
import '../../Models/HomeCategoryModel.dart';
import '../../Utils/InitUtil.dart';
import '../Settings/SettingsProvider.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  SearchBar? searchBar;
  HomeCategoryProvider? hp;
  List<HomeCategory> data = [];
  List<Article> searchArticleList = [];
  bool hideRead = false;

  AppBar buildAppBar(BuildContext context) {
    return AppBar(
        bottom: data.isEmpty 
          ? null 
          : TabBar(
              tabs: [
                for (var category in data) Tab(text: category.title),
              ],
              isScrollable: true,
            ),
        title: Text(widget.title),
        actions: [
          IconButton(
              onPressed: () {
                try {
                  setState(() {
                    hideRead = !hideRead;
                    SettingsProvider().setHideRead(hideRead);
                  });
                  if (hideRead) {
                    MSnackBar.showSnackBar(S.of(context).read_hide_toast, "");
                    // Toast.showToast(S.of(context).read_hide_toast, context);
                  } else {
                    MSnackBar.showSnackBar(S.of(context).read_show_toast, "");
                    // Toast.showToast(S.of(context).read_show_toast, context);
                  }
                } catch (e) {
                  print('切换 hideRead 失败: $e');
                }
              },
              icon: hideRead
                  ? const Icon(Icons.visibility_off)
                  : const Icon(Icons.visibility)),
          searchBar?.getSearchAction(context) ?? const SizedBox.shrink()
        ]);
  }

  searchChanged(String value) {
    setState(() {
      searchArticleList = hp?.getArticleSearchList(value) ?? [];
    });
  }

  @override
  void initState() {
    super.initState();
    
    // 初始化默认值
    data = [];
    searchArticleList = [];
    hideRead = false;
    
    // 延迟初始化，等待数据库准备好
    _initializeData();
    
    /// This is needed for index StatefulWidget
    Future.delayed(Duration.zero, () {
      try {
        InitUtil.initAfterStart(context);
      } catch (e) {
        print('initAfterStart 失败: $e');
      }
    });
  }
  
  void _initializeData() async {
    // 等待数据库初始化完成
    int retryCount = 0;
    const maxRetries = 20; // 最多重试 20 次（10秒）
    bool lastWasEmpty = false;
    
    while (retryCount < maxRetries) {
      try {
        if (Hive.isBoxOpen('categories') && Hive.isBoxOpen('articles')) {
          // 检查数据库是否有数据
          var cBox = Hive.box('categories');
          var aBox = Hive.box('articles');
          
          // 如果数据库为空，等待一下再重试（可能还在初始化中）
          if (cBox.isEmpty || aBox.isEmpty) {
            // 如果连续两次都是空的，说明初始化可能已经完成，停止重试
            if (lastWasEmpty && retryCount > 5) {
              print('数据库持续为空，可能初始化已完成，停止重试');
              break;
            }
            lastWasEmpty = true;
            print('数据库为空，等待初始化... (重试 ${retryCount + 1}/$maxRetries)');
            await Future.delayed(const Duration(milliseconds: 500));
            retryCount++;
            continue;
          }
          
          lastWasEmpty = false;
          hp = HomeCategoryProvider();
          final loadedData = hp?.getCategorieList() ?? [];
          
          print('加载数据成功，分类数: ${loadedData.length}');
          
          // 无论数据是否为空，都要初始化 UI
          if (mounted) {
            setState(() {
              data = loadedData;
              if (data.isNotEmpty) {
                searchArticleList = data.first.articles;
              } else {
                searchArticleList = [];
              }
              
              // 初始化搜索栏（必须初始化，否则会一直显示加载中）
              searchBar = SearchBar(
                  inBar: true,
                  setState: setState,
                  onSubmitted: print,
                  buildDefaultAppBar: buildAppBar,
                  closeOnSubmit: false,
                  onChanged: searchChanged,
                  hintText: "在文集中搜索...");
              
              try {
                hideRead = SettingsProvider().getHideRead();
              } catch (e) {
                hideRead = false;
              }
            });
          }
          return; // 成功加载，退出函数
        }
      } catch (e, stackTrace) {
        print('加载数据时出错: $e');
        print('堆栈跟踪: $stackTrace');
      }
      
      // 等待 500ms 后重试
      await Future.delayed(const Duration(milliseconds: 500));
      retryCount++;
    }
    
    // 如果重试后还是失败，使用空数据并初始化 UI
    print('数据加载完成，使用当前数据（可能为空）');
    if (mounted) {
      setState(() {
        hp = HomeCategoryProvider();
        // 最后尝试加载一次数据
        data = hp?.getCategorieList() ?? [];
        if (data.isNotEmpty) {
          searchArticleList = data.first.articles;
        } else {
          searchArticleList = [];
        }
        // 必须初始化 searchBar，否则会一直显示加载中
        searchBar = SearchBar(
            inBar: true,
            setState: setState,
            onSubmitted: print,
            buildDefaultAppBar: buildAppBar,
            closeOnSubmit: false,
            onChanged: searchChanged,
            hintText: "在文集中搜索...");
        try {
          hideRead = SettingsProvider().getHideRead();
        } catch (e) {
          hideRead = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // HomeCategoryProvider hp = HomeCategoryProvider();
    // var categoryList = hp.getCategorieList();
    // List<HomeCategory> dataList = hp.getHomeCategory();

    // 如果 searchBar 还没初始化，显示加载中
    if (searchBar == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        drawer: const MDrawer(),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return ValueListenableBuilder<bool>(
        valueListenable: searchBar!.isSearching,
        builder: (BuildContext context, bool value, Widget? child) {
          // 如果数据为空，显示空状态而不是一直加载
          if (data.isEmpty) {
            return Scaffold(
              appBar: searchBar!.build(context),
              drawer: const MDrawer(),
              body: const Center(
                child: Text('暂无数据'),
              ),
            );
          }
          
          return DefaultTabController(
              length: data.length,
              child: Scaffold(
                appBar: searchBar?.build(context) ?? AppBar(title: Text(widget.title)),
                drawer: const MDrawer(),
                body: value

                    /// 搜索场景下展示样式
                    ? ArticleList(searchArticleList, useListView: true)

                    /// 非搜索下展示样式
                    : TabBarView(
                        children: [
                          for (var category in data)
                            ArticleList(
                              category.articles,
                              hideRead: hideRead,
                              useListView: true,
                              notifyState: () => setState(() => {}),
                            )
                          // Tab(text: item.title),
                        ],
                      ),
              ));
        });

    // return FutureBuilder<List<HomeCategory>>(
    //     future: hp.getCategorieList(),
    //     builder:
    //         (BuildContext context, AsyncSnapshot<List<HomeCategory>> snapshot) {
    //       return snapshot.hasData
    //           ? DefaultTabController(
    //               length: snapshot.data!.length,
    //               child: Scaffold(
    //                 appBar: AppBar(
    //                   bottom: TabBar(tabs: [
    //                     for (var category in snapshot.data!)
    //                       Tab(text: category.title),
    //                   ]),
    //                   title: Text(widget.title),
    //                 ),
    //                 drawer: const MDrawer(),
    //                 body: TabBarView(
    //                   children: [
    //                     for (var category in snapshot.data!)
    //                       SingleChildScrollView(
    //                         child: ArticleList(category.articles),
    //                       )
    //                     // Tab(text: item.title),
    //                   ],
    //                 ),
    //                 // Center(
    //                 //   child: Column(
    //                 //     mainAxisAlignment: MainAxisAlignment.center,
    //                 //     children: <Widget>[],
    //                 //   ),
    //                 // ),
    //               ))
    //           : Container();
    //     });
  }
}
