package haxe.remoting.appmanager;

import js.Node;

class AppUtil
{
	public static function initdStatus (app :String, onStatus :String->Void) :Void
	{
	    Node.exec("/etc/init.d/" + app + " status", 
			function (error :Dynamic, stdout:Dynamic, stderr:Dynamic) :Void {
				org.transition9.util.Log.debug("        done copying ");
				org.transition9.util.Log.debug('               error=' + error);
				org.transition9.util.Log.debug(               'stdout=' + stdout);
				org.transition9.util.Log.debug('               stderr=' + stderr);
				onStatus(stdout);
			});
	}
	
}
