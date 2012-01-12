package haxe.remoting.appmanager;

#if nodejs
import js.Node;
#elseif neko

#end
import haxe.io.Bytes;

import haxe.remoting.HttpAsyncConnection;
import haxe.remoting.appmanager.AppService;

using StringTools;

class AppClient
{
	static var APP_ZIP_FILE = "app.zip";
	
	public static function main () :Void
	{
		var args = 
		#if nodejs
		Node.process.argv.slice(2);
		#elseif neko
		neko.Sys.args();
		#end
		
		trace('args=' + args);
		var buildServer = args[0];
		var subdomain = args[1];
		var buildFolder = args[2];
		var scriptName = args[3];
		var user = args[4];
		var pkey = args[5];
		
		var port = args[6] == null ? 80 : Std.parseInt(args[6]);
		var domains = args.slice(7);
		domains = domains == null ? [] : domains;
		
		trace('user=' + user);
		trace('pkey=' + pkey);
		trace('buildServer=' + buildServer);
		trace('subdomain=' + subdomain);
		trace('buildFolder=' + buildFolder);
		trace('scriptName=' + scriptName);
		trace('port=' + port);
		trace('domains=' + domains);
		
		
		if (subdomain == null || buildFolder == null) {
			trace("Usage: neko Appclient.n <build server> <subdomain> <build folder> <scriptName> <user> <pkey> [port] [domains...]");
			trace("   e.g. neko Appclient.n myGame /home/me/build 81");
			return;
		}
		
		var portString = port == 80 ? "" : ":" + port;
		var appConfig = new ClientAppConfig();
		appConfig.subdomain = subdomain;
		appConfig.port = port;
		appConfig.scriptName = scriptName;
		appConfig.domains = domains.join(" ");
		
		// deployZipPackage("http://apps." + buildServer, buildFolder, appConfig);
		// deployRsyncFolder(buildServer, "http://apps." + buildServer, buildFolder, appConfig);
		deployRsyncFolder(buildServer, "http://" + buildServer, buildFolder, user, pkey, appConfig);
	}
	
	static function deployRsyncFolder (buildServer :String, appserverURL :String, localBuildFolder :String, user :String, pkey :String, appConfig :ClientAppConfig) :Void
	{
		trace('appserverURL=' + appserverURL);
		var portString = appConfig.port == 80 ? "" : ":" + appConfig.port;
		trace('Deploying to=' + appConfig.subdomain + "." + buildServer + portString);
		
		//Rsync the folder
		var serverAppFolder = "/tmp/" + appConfig.subdomain + portString;
		
		var send = function () :Void {
			// //Send the app package to the server
			trace('appserverURL=' + appserverURL);
			var conn = HttpAsyncConnection.urlConnect(appserverURL);
			conn.setErrorHandler( function(err) {trace(err);});
			var appService = new AppAsyncProxy(conn);
			appService.deployAppFromLocalDir(serverAppFolder, appConfig, function (?_) :Void {
				trace("done " + _);
			});
		}
		
		
		// trace("Connecting to " + appserverURL);
		// var http = Node.require('http');
		// var google = http.createClient(80, appserverURL);
		// var r = {};
		// Reflect.setField(r, "host", appserverURL);
		// var request = google.request('GET', '/', r);
		// request.end();
		// request.on('response', function (response) {
		//   trace('STATUS: ' + response.statusCode);
		//   trace('HEADERS: ' + org.transition9.util.StringUtil.stringify(response.headers));
		//   response.setEncoding('utf8');
		//   response.on('data', function (chunk) {
		// 	trace('BODY: ' + chunk);
		//   });
		// });
		

		
		#if nodejs
			Node.exec("rsync -av -e 'ssh -l " + user + " -i " + pkey + "' --delete --exclude=.git --exclude=.svn --exclude=.hg --exclude=.DS_Store " + localBuildFolder + "/ " + buildServer + ":" + serverAppFolder, 
				function (error :Dynamic, stdout:Dynamic, stderr:Dynamic) :Void {
					org.transition9.util.Log.debug("        done copying ");
					org.transition9.util.Log.debug('               error=' + error);
					org.transition9.util.Log.debug(               'stdout=' + stdout);
					org.transition9.util.Log.debug('               stderr=' + stderr);
					send();
				});
								
		#elseif neko
		
			// trace("rsync -av -e 'ssh -l " + user + " -i " + pkey + "' --delete --exclude=.git --exclude=.svn --exclude=.hg --exclude=.DS_Store " + localBuildFolder + "/ " + buildServer + ":" + serverAppFolder);
			var command = "rsync -av -e 'ssh -l " + user + " -i " + pkey + "' --delete --exclude=.git --exclude=.svn --exclude=.hg --exclude=.DS_Store " + localBuildFolder + "/ " + buildServer + ":" + serverAppFolder;
			trace(command);
			// var p = new neko.io.Process("rsync", ["-av", "-e", "'ssh -l " + user + " -i " + pkey + "'", "--delete", "--exclude=.git", "--exclude=.svn", "--exclude=.hg", "--exclude=.DS_Store", localBuildFolder + "/", buildServer + ":" + serverAppFolder]);
			// var p = new neko.io.Process("rsync", ["-av", "-e", "'ssh -l " + user + " -i " + pkey + "'", "--delete", "--exclude=.git", "--exclude=.svn", "--exclude=.hg", "--exclude=.DS_Store", localBuildFolder + "/", buildServer + ":" + serverAppFolder]);
			
			neko.Sys.command(command);
			
			// read everything from stderr
			// var error = p.stderr.readAll().toString();
			
			// trace("stderr:\n" + error);
			
			// read everything from stdout
			// var stdout = p.stdout.readAll().toString();
			
			// trace("stdout:\n" + stdout);
			
			// p.close(); // close the process I/O
			send();
		#end
	}
	
	// static function deployZipPackage (buildServer :String, appserverURL :String, localBuildFolder :String, appConfig :ClientAppConfig) :Void
	// {
	// 	trace('appserverURL=' + appserverURL);
	// 	var portString = appConfig.port == 80 ? "" : ":" + appConfig.port;
	// 	trace('Deploying to=' + appConfig.subdomain + "." + buildServer + portString);
		
	// 	//Zip the build folder
	// 	var files :Array<{ fileTime : Date, fileName : String, data : Bytes}> = [];
	// 	trace("Creating zip...");
	// 	for (f in NekoUtil.getFiles(localBuildFolder)) {
	// 		var time = FileSystem.stat(f).mtime;
	// 		var data = File.getBytes(f);
	// 		trace("    " + f);
	// 		files.push({fileTime:time, fileName:f.replace(localBuildFolder + "/", ""), data:data});
	// 	}
		
	// 	trace("writing zip file...");
	// 	var output = File.write(APP_ZIP_FILE, true);
	// 	Writer.writeZip(output, files, 5);
	// 	output.close();
		
	// 	trace('FileSystem.stat(APP_ZIP_FILE).size=' + FileSystem.stat(APP_ZIP_FILE).size);
		
	// 	//Send the app package to the server
	// 	var conn = HttpAsyncConnection.urlConnect(appserverURL);
	// 	conn.setErrorHandler( function(err) {trace(err);});
	// 	var appService = new AppAsyncProxy(conn);
	// 	var bytes = File.getBytes(APP_ZIP_FILE);
	// 	trace("Bytes up=" + bytes.length);
	// 	trace("Uploading " + (bytes.length / 1000000) + " mb...");
	// 	// var appConfig :ClientAppConfig = {subdomain:appSubDomain, port:appPort, scriptName:'server.js'};
	// 	appService.deployApp(bytes, appConfig, function (?_) :Void {
	// 		trace("done " + _);
	// 	});
		
	// 	//Delete the zip file
	// 	FileSystem.deleteFile(APP_ZIP_FILE);
	// }
}
