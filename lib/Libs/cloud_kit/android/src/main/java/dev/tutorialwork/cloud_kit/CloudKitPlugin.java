package dev.tutorialwork.cloud_kit;

import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * CloudKitPlugin
 * * CloudKit 仅支持 iOS。这是一个安卓端的空实现，用于通过编译。
 */
public class CloudKitPlugin implements FlutterPlugin, MethodCallHandler {
    private MethodChannel channel;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        // 注册通道，名字通常是 "cloud_kit" 或者包名，这里保持通用名字
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "cloud_kit");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        // 因为安卓不支持 iCloud，所有方法调用都返回 "未实现"
        result.notImplemented();
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }
}