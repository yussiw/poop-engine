package org.poopengine;

import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageInstaller;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.OutputStream;
import org.haxe.extension.Extension;

/**
 * Instala um APK baixado usando a PackageInstaller API (nao precisa de FileProvider).
 * Retorno: 0 = o sistema vai mostrar a tela de confirmacao, 1 = falta permitir "instalar apps desconhecidos", 2 = erro.
 */
public class ApkInstaller {
	public static int install(String path) {
		try {
			final Context ctx = Extension.mainContext;
			if (Build.VERSION.SDK_INT >= 26 && !ctx.getPackageManager().canRequestPackageInstalls()) {
				Intent i = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + ctx.getPackageName()));
				i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
				ctx.startActivity(i);
				return 1;
			}

			PackageInstaller installer = ctx.getPackageManager().getPackageInstaller();
			PackageInstaller.SessionParams params = new PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL);
			int id = installer.createSession(params);
			PackageInstaller.Session session = installer.openSession(id);

			InputStream in = new FileInputStream(path);
			OutputStream out = session.openWrite("poopengine", 0, -1);
			byte[] buf = new byte[65536];
			int n;
			while ((n = in.read(buf)) > 0)
				out.write(buf, 0, n);
			session.fsync(out);
			out.close();
			in.close();

			final String action = ctx.getPackageName() + ".INSTALL_RESULT";
			BroadcastReceiver receiver = new BroadcastReceiver() {
				@Override
				public void onReceive(Context c, Intent intent) {
					int status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, -1);
					if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
						Intent confirm = (Intent) intent.getParcelableExtra(Intent.EXTRA_INTENT);
						if (confirm != null) {
							confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
							c.startActivity(confirm);
						}
					} else {
						try {
							c.unregisterReceiver(this);
						} catch (Exception e) {}
					}
				}
			};
			IntentFilter filter = new IntentFilter(action);
			if (Build.VERSION.SDK_INT >= 33)
				ctx.registerReceiver(receiver, filter, 4); // RECEIVER_NOT_EXPORTED
			else
				ctx.registerReceiver(receiver, filter);

			int flags = PendingIntent.FLAG_UPDATE_CURRENT;
			if (Build.VERSION.SDK_INT >= 31)
				flags |= 33554432; // FLAG_MUTABLE (o sistema precisa preencher os extras)
			Intent resultIntent = new Intent(action).setPackage(ctx.getPackageName());
			PendingIntent pending = PendingIntent.getBroadcast(ctx, id, resultIntent, flags);
			session.commit(pending.getIntentSender());
			session.close();
			return 0;
		} catch (Throwable t) {
			android.util.Log.e("PoopEngine", "ApkInstaller falhou", t);
			return 2;
		}
	}
}
