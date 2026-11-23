package org.poopengine;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;

/**
 * Baixa o APK direto pro disco numa thread Java (nao depende do HTTPRequest do Lime).
 * O Haxe so faz polling: loaded() / total() / state().
 * state: 0 = baixando, 1 = terminou, 2 = erro (ver error()), 3 = cancelado
 */
public class ApkDownloader {
	static volatile int loaded = 0;
	static volatile int total = 0;
	static volatile int state = 0;
	static volatile String error = "";
	static volatile int generation = 0;

	public static int start(final String url, final String path) {
		final int gen = ++generation;
		loaded = 0;
		total = 0;
		state = 0;
		error = "";
		new Thread(new Runnable() {
			public void run() {
				HttpURLConnection c = null;
				try {
					String u = url;
					for (int hop = 0; hop < 6; hop++) { // segue redirects manualmente (https -> https do GitHub)
						c = (HttpURLConnection) new URL(u).openConnection();
						c.setInstanceFollowRedirects(false);
						c.setConnectTimeout(15000);
						c.setReadTimeout(30000);
						c.setRequestProperty("User-Agent", "PoopEngine");
						c.setRequestProperty("Accept", "application/octet-stream");
						int code = c.getResponseCode();
						if (code >= 300 && code < 400) {
							u = new URL(new URL(u), c.getHeaderField("Location")).toString();
							c.disconnect();
							continue;
						}
						if (code != 200)
							throw new Exception("http " + code);
						break;
					}
					total = c.getContentLength() > 0 ? c.getContentLength() : total;
					File part = new File(path + ".part");
					InputStream in = c.getInputStream();
					FileOutputStream out = new FileOutputStream(part);
					byte[] buf = new byte[65536];
					int n;
					while ((n = in.read(buf)) > 0) {
						if (gen != generation) {
							out.close();
							in.close();
							part.delete();
							state = 3;
							return;
						}
						out.write(buf, 0, n);
						loaded += n;
					}
					out.flush();
					out.close();
					in.close();
					File dest = new File(path);
					if (dest.exists())
						dest.delete();
					if (!part.renameTo(dest))
						throw new Exception("rename");
					if (gen == generation)
						state = 1;
				} catch (Throwable t) {
					android.util.Log.e("PoopEngine", "ApkDownloader falhou", t);
					if (gen == generation) {
						error = String.valueOf(t.getMessage() != null ? t.getMessage() : t.getClass().getSimpleName());
						state = 2;
					}
				} finally {
					if (c != null)
						c.disconnect();
				}
			}
		}).start();
		return 0;
	}

	public static void setTotal(int t) { if (total <= 0) total = t; }
	public static int loaded() { return loaded; }
	public static int total() { return total; }
	public static int state() { return state; }
	public static String error() { return error; }
	public static void cancel() { generation++; }
}
