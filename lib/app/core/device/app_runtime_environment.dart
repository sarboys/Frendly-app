import 'package:flutter/services.dart';

const appRuntimeEnvironmentChannel = MethodChannel('app.runtime.environment');

class AppRuntimeEnvironment {
  const AppRuntimeEnvironment({this.channel = appRuntimeEnvironmentChannel});

  final MethodChannel channel;

  Future<bool> isIosAppOnMac() async {
    try {
      return await channel.invokeMethod<bool>('isIosAppOnMac') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
