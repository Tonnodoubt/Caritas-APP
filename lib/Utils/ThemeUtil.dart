import 'package:flutter/material.dart';

import '../Pages/Settings/SettingsProvider.dart';
import '../Resources/Themes.dart';

class ThemeUtil {
  static getNowTheme() {
    try {
      int themeIndex = SettingsProvider().getThemeIndex();
      if (themeIndex == -1) {
        /// 自定义主题
        String themeCustomeColor = SettingsProvider().getThemeCustomColor();
        if (themeCustomeColor.isNotEmpty) {
          return _getColorSuite(getColorFromHex(themeCustomeColor));
        } else {
          // 自定义颜色为空，使用默认颜色
          return _getColorSuite(Themes.colorList[0]);
        }
      } else {
        // 检查索引是否有效
        if (themeIndex >= 0 && themeIndex < Themes.colorList.length) {
          return _getColorSuite(Themes.colorList[themeIndex]);
        } else {
          print('主题索引 $themeIndex 超出范围，使用默认主题');
          return _getColorSuite(Themes.colorList[0]);
        }
      }
    } catch (e, stackTrace) {
      print('获取主题失败: $e');
      print('堆栈跟踪: $stackTrace');
      // 返回默认主题
      return _getColorSuite(Themes.colorList[0]);
    }
  }

  static _getColorSuite(Color color) {
    ThemeData tdLight =
        ThemeData(colorSchemeSeed: color, brightness: Brightness.light);
    ThemeData tdDark =
        ThemeData(colorSchemeSeed: color, brightness: Brightness.dark);
    // Color primaryThemeColor = tdLight.primaryColor;
    // ThemeData tdDarkFinal = tdDark.copyWith(
    //   appBarTheme: AppBarTheme(
    //     color: primaryThemeColor,
    //   ),
    //   textButtonTheme: TextButtonThemeData(
    //     style: TextButton.styleFrom(
    //       primary: Colors.white,
    //       backgroundColor: primaryThemeColor,
    //     ),
    //   ),
    // );
    return {
      "light": tdLight,
      "dark": tdDark,
    };
  }

  static Color getColorFromHex(String hexColor) {
    try {
      hexColor = hexColor.toUpperCase().replaceAll("#", "");
      if (hexColor.length == 6) {
        hexColor = "FF$hexColor";
      }
      return Color(int.parse(hexColor, radix: 16));
    } catch (e) {
      print('解析颜色失败: $hexColor, 错误: $e');
      // 返回默认颜色
      return Themes.colorList[0];
    }
  }
}
