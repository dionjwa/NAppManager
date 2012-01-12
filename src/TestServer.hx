package ;

import js.Node;

class TestServer
{
	public static function main () :Void
	{
		//This can be a pain to configure on multiple platforms and execution environments, so 
		//we'll just add it here.
		// var paths :Array<Dynamic> = untyped __js__("require.paths");
		// paths.push("/usr/local/lib/node_modules");
	
		//TODO: get the port from the config file
		var port :Int = Std.parseInt(js.Node.process.argv[2]);
		
		trace("listening on port " + port);
		Node.http.createServer(function (req :NodeHttpServerReq, res :NodeHttpServerResp) {
			trace(req.url);
			res.writeHead(200, {});
			res.end("Hello, I'm the TestServer on port " + port + ", built on " + org.transition9.util.PBMacros.getDate());
		}).listen(port, '127.0.0.1');
	}
}
