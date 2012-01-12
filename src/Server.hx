package ;

import haxe.remoting.Context;
import haxe.remoting.NodeJsHtmlConnection;
import haxe.remoting.appmanager.AppManager;
import haxe.remoting.appmanager.Properties;

import js.Node;

using Lambda;

class Server
{
	public static function main () :Void
	{
		// org.transition9.engine.debug.Log.setup();
		// org.transition9.util.Log.setLevel(AppManager, org.transition9.util.Log.DEBUG);
		
		//The context holds all the different api/services.
		var context = new Context();
		var appService = new AppManager();
		context.addObject(AppManager.REMOTING_ID, appService);
		//Add the context to the html connection handler
		var serviceHandler = new NodeJsHtmlConnection(context);
		
		//TODO: get the port from the config file
		var port = Properties.appmanager_port_internal;
		
		trace("Built on " + org.transition9.util.Macros.getDate());
		trace("listening on port " + port);
		Node.http.createServer(function (req :NodeHttpServerReq, res :NodeHttpServerResp) {
			org.transition9.util.Log.debug(req.url);
			if (Reflect.field(req.headers, "x-haxe-remoting") == "1") {
				serviceHandler.handleRequest(req, res);
			} else {
				AppManager.handleNonRemotingRequest(req, res);
			}
		}).listen(port, '127.0.0.1');
		
		AppManager.updateNginx(function (err) {trace("Updated Nginx " + err);});
	}
}
