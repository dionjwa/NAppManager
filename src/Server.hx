package ;

import haxe.remoting.Context;
import haxe.remoting.NodeJSHTMLConnection;
import haxe.remoting.appmanager.AppManager;
import haxe.remoting.appmanager.Properties;

import js.Node;

using Lambda;

class Server
{
	public static function main () :Void
	{
		com.pblabs.engine.debug.Log.setup();
		com.pblabs.util.Log.setLevel(AppManager, com.pblabs.util.Log.DEBUG);
		
		//The context holds all the different api/services.
		var context = new Context();
		var appService = new AppManager();
		context.addObject(AppManager.REMOTING_ID, appService);
		//Add the context to the html connection handler
		var serviceHandler = new NodeJSHTMLConnection(context);
		
		//TODO: get the port from the config file
		var port :Int = Std.parseInt(Properties.appmanager_port_internal);
		
		trace("Built on " + com.pblabs.util.PBMacros.getDate());
		trace("listening on port " + port);
		Node.http.createServer(function (req :NodeHttpServerReq, res :NodeHttpServerResp) {
			com.pblabs.util.Log.debug(req.url);
			if (Reflect.field(req.headers, "x-haxe-remoting") == "1") {
				serviceHandler.handleRequest(req, res);
			} else {
				AppManager.handleNonRemotingRequest(req, res);
			}
		}).listen(port, '127.0.0.1');
	}
}
