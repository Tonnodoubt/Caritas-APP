import '../Pages/Settings/SettingsProvider.dart';
import 'package:umeng_common_sdk/umeng_common_sdk.dart';
import 'package:umeng_push_sdk/umeng_push_sdk.dart';
import 'package:get/get.dart';

import '../Resources/Config.dart';

class UmengUtil {
  static final bool _isMobile = GetPlatform.isAndroid || GetPlatform.isIOS;

  static init() {
    if (!_isMobile) return;
    
    try {
      // 检查配置是否有效（不是占位符）
      if (Config.umengAndroidKey == "android_key_placeholder" || 
          Config.umengiOSKey == "ios_key_placeholder") {
        print('Umeng 配置为占位符，跳过初始化');
        return;
      }
      
      UmengCommonSdk.initCommon(
          Config.umengAndroidKey, Config.umengiOSKey, Config.umengChannel);
      UmengCommonSdk.setPageCollectionModeAuto();
      UmengPushSdk.register(Config.umengiOSKey, Config.umengChannel);
      print('Umeng 初始化成功');
    } catch (e, stackTrace) {
      print('Umeng 初始化失败: $e');
      print('堆栈跟踪: $stackTrace');
      // 不抛出异常，允许应用继续运行
    }
  }

  static onEvent(String event, Map<String, dynamic> properties) {
    if (!_isMobile) return;
    UmengCommonSdk.onEvent(event, properties);
  }

  static onArticleEvent(String event, Map<String, dynamic> properties) {
    if (!_isMobile) return;
    if (!SettingsProvider().getShareData()) return;
    UmengCommonSdk.onEvent(event, properties);
  }
}
