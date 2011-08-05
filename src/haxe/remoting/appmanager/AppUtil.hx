package haxe.remoting.appmanager;

import js.Node;

class AppUtil
{
	public static function initdStatus (app :String, onStatus :String->Void) :Void
	{
	    Node.exec("/etc/init.d/" + app + " status", 
			function (error :Dynamic, stdout:Dynamic, stderr:Dynamic) :Void {
				com.pblabs.util.Log.debug("        done copying ");
				com.pblabs.util.Log.debug('               error=' + error);
				com.pblabs.util.Log.debug(               'stdout=' + stdout);
				com.pblabs.util.Log.debug('               stderr=' + stderr);
				onStatus(stdout);
			});
	}
	
}
