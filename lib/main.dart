import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'generated/l10n.dart';

import './Pages/HomePage/HomePageView.dart';
import './Pages/Settings/SettingsProvider.dart';
import './Resources/Constant.dart';
import './Utils/InitUtil.dart';
import './Utils/ThemeUtil.dart';

void main() async {
  // 初始化 Flutter 绑定，必须在 runApp 之前调用
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // 关键初始化必须在启动前完成（Hive、GetStorage）
    await InitUtil.initBeforeStart();
  } catch (e, stackTrace) {
    // 打印错误信息以便调试（只在 debug 模式）
    assert(() {
      print('初始化失败: $e');
      print('堆栈跟踪: $stackTrace');
      return true;
    }());
    // 即使初始化失败，也尝试启动应用
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget{
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // 安全获取主题，防止闪退
    ThemeData? lightTheme;
    ThemeData? darkTheme;
    ThemeMode themeMode = ThemeMode.system;
    
    try {
      final themeMap = ThemeUtil.getNowTheme();
      lightTheme = themeMap['light'] as ThemeData?;
      darkTheme = themeMap['dark'] as ThemeData?;
    } catch (e) {
      print('获取主题失败: $e，使用默认主题');
      lightTheme = ThemeData.light();
      darkTheme = ThemeData.dark();
    }
    
    try {
      int modeIndex = SettingsProvider().getThemeMode();
      if (modeIndex >= 0 && modeIndex < Constant.themeModeList.length) {
        themeMode = Constant.themeModeList[modeIndex];
      }
    } catch (e) {
      print('获取主题模式失败: $e，使用系统默认');
      themeMode = ThemeMode.system;
    }
    
    return GetMaterialApp(
      title: 'Caritas',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      locale: const Locale('zh', ''),
      localeListResolutionCallback: (locales, supportedLocales) {
        print('当前系统语言环境$locales');
        return;
      },
      theme: lightTheme ?? ThemeData.light(),
      darkTheme: darkTheme ?? ThemeData.dark(),
      themeMode: themeMode,
      home: const MyHomePage(title: 'Caritas'),
    );
  }
}
