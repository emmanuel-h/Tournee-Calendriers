package fr.mandarine.tourneecalendriers

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // « Réglages » of « Bloqués par Android » in Paramètres (#82): opens
    // Android's notification settings of the app, which
    // flutter_local_notifications cannot do.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "fr.mandarine.tourneecalendriers/settings",
        ).setMethodCallHandler { call, result ->
            if (call.method == "openNotificationSettings") {
                startActivity(
                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, packageName),
                )
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}
