package haxe.remoting.appmanager;

#if (nodejs && server)

import js.node.redis.Redis;

import org.transition9.async.AsyncLambda;
import org.transition9.util.Comparators;
import org.transition9.util.Predicates;
import org.transition9.util.Rand;
import org.transition9.util.StringUtil;
import haxe.io.Bytes;
import haxe.Template;
import haxe.Resource;
import js.Node;
import haxe.remoting.appmanager.AppService;
import org.transition9.ds.maps.MapBuilder;
import org.transition9.ds.Map;
import org.transition9.ds.MultiMap;
import org.transition9.ds.multimaps.ArrayMultiMap;
import org.transition9.ds.Sets;
import org.transition9.ds.Set;
import Type;
using Lambda;
using StringTools;
using org.transition9.util.StringUtil;
using org.transition9.util.ObjectUtil;
using org.transition9.ds.multimaps.MultiMapUtil;
using js.node.redis.RedisObjectUtil;
#end

class AppManager
	#if (nodejs && server)
	implements AppService
	#end
{
	public static inline var REMOTING_ID = "appmanager";
	
	#if (nodejs && server)
	/** The file used as a marker to indicate the active (served) app for a given port/location */
	static inline var ACTIVE_TOKEN = "ACTIVE";
	static inline var APP_CONFIG_FILE = "app.config";
	static inline var UPSTART_APP_PREFIX = "appmanagerApp_";
	
	static inline var REDIS_PREFIX = "appm";
	static inline var SEP = ":";
	/** Track the tokens used by the client */
	static inline var QUERY_TOKEN_PREFIX = REDIS_PREFIX + ":q:";
	// static inline var ACTIVE_APPS = REDIS_PREFIX + ":active:";
	static inline var CONFIG_PREFIX = REDIS_PREFIX + ":cf:";
	static inline var CONFIG_LIST = REDIS_PREFIX + ":cf";
	/** Track internal ports to avoid collisions */
	static var START_PORT = 8000;
	/** Where apps are stored */
	static var _appDir :String;
	
	static var redis :RedisClient = Redis.newClient();
	
	static var APP_MANAGER_PAGE = '<html>
		<head>
		<title>Appmanager</title>
		</head>
		<body bgcolor="white" text="black">
		<center><h1>Node.js AppManager</h1></center>
		<dev>::apps::</div>
		</body>
		</html>';
	
	static public function handleNonRemotingRequest (req :NodeHttpServerReq, res :NodeHttpServerResp) :Void
	{
		if (req.url.indexOf("?") == -1) {
			showApps(req, res);
		} else {
			var query = Node.queryString.parse(req.url.split("?")[1]);
			var token = Reflect.field(query, "token");
			
			isQueryToken(token, function (isToken :Bool) :Void {
				if (isToken) {
					showApps(req, res);
				} else {
					addQueryToken(token, function (added :Bool) :Void {
						switch (Reflect.field(query, "command")) {
							case "delete":
								var appId = Reflect.field(query, "appid");
								loadConfig(redisKey(appId), function (config :AppConfig) :Void {
									deleteApp(appId, function () :Void {
										org.transition9.util.Log.debug("finished deleting app");
										showApps(req, res);
									});
								});
							case "shutdown":
								var appId = Reflect.field(query, "appid");
								loadConfig(redisKey(appId), function (config :AppConfig) :Void {
									if (config != null) {
										shutdownApp(config, function (deleted :Bool) :Void {
											showApps(req, res);
										});
									} else {
										org.transition9.util.Log.error("no config on " + redisKey(appId)); 
										showApps(req, res);
									}
								});
							case "setactiveapp":
								var appId = Reflect.field(query, "appid");
								loadConfig(redisKey(appId), function (config :AppConfig) :Void {
									if (config != null) {
										setActiveApp(config, function (_) :Void {
											showApps(req, res);
										});
									} else {
										res.writeHead(200, {});
										res.end("No config for  " + appId);
									}
								});
							default : 
								res.writeHead(200, {});
								res.end("Unrecognized command " + Reflect.field(query, "command"));
						}
					});
				}
			});
		}
	}
	
	inline static function redisKey (appFolder :String) :String
	{
		return CONFIG_PREFIX + appFolder;
	}
	
	static function showApps (req :NodeHttpServerReq, res :NodeHttpServerResp) :Void
	{
		getAllConfigs(function (configs :Array<AppConfig>) :Void {
			var t = new haxe.Template(APP_MANAGER_PAGE);
			var appString = '<table border="0">';
			
			var apps :MultiMap<String, Null<AppConfig>> = ArrayMultiMap.create(ValueType.TClass(String)).partition(configs, 
				function (config :AppConfig) :String {
					return config.appFolder.split("__")[0];
				});
			var token = Rand.nextId(5);
			for (app in apps.keys()) {
				var configs = apps.get(app).array(); 
				configs.sort(function (c1 :AppConfig, c2 :AppConfig) :Int {
					return Comparators.compareStrings(c2.appFolder, c1.appFolder);
				});
				
				appString += '<tr><td>' + app + '</td><td></td><td></td><td></td></tr>';
				for (config in configs) {
					var appId = config.appFolder;
					appString += '<tr><td></td>';
					if (config.isActive) {
						appString += '<td><a href="http://'  + Properties.server + "/" + getSubDomainFromAppFolderName(appId) + '">' + appId + '</a></td>';
						appString += '<td><a href="/?token=' + token + '&command=shutdown&appid=' + appId + '">shutdown</a></td>';
						appString += '<td></td>';
					} else {
						appString += '<td>' + appId + '</td>';
						appString += '<td><a href="/?token=' + token + '&command=delete&appid=' + appId + '">delete</a></td>';
						appString += '<td><a href="/?token=' + token + '&command=setactiveapp&appid=' + appId + '">set active app</a></td>';
					}
					appString += '</tr>';
				}
			}
			appString += "</table>";	    
			
			res.writeHead(200, {});
			res.end(t.execute({apps:appString}));
		});
	}
	
	public function new () :Void
	{
		org.transition9.util.Rand.getStream().setSeed(Std.int(Date.now().getTime() / 1000));
		_appDir = Properties.apps_dir;
		org.transition9.util.Log.debug('appsDir=' + _appDir);
		
		#if debug
		if (Node.path.existsSync(_appDir)) {
			trace("App folders=\n    " + getAppFolders().join("\n    "));
		} else {
			org.transition9.util.Log.error(_appDir + " doesn't exist.");
		}
		#end
		org.transition9.util.Log.debug("getAllConfigs");
		// deleteAll();
		getAllConfigs(function (cfgs :Array<AppConfig>) :Void {
			updateNginx(function (_) :Void {trace("Nginx updated");});
		});
	}
	
	static function deleteAll () :Void
	{
		getAllConfigs(function (configs :Array<AppConfig>) :Void {
			for (config in configs) {
				deleteApp(config.appFolder, function () :Void {});
			}
		});
		redis.del(CONFIG_LIST, function (e :Err, exists :Int) :Void {});
		
		getRunningApps(function (runningAppFolders :Array<String>) :Void {
			org.transition9.util.Log.debug("finished getRunningApps\n" + runningAppFolders.join("\n"));
			for (appFolder in runningAppFolders) {
				stopUpstart(appFolder, function () :Void {trace("shutdown " + appFolder);});
			}
		});
		for (appFolder in getAppFolders()) {
			deleteApp(appFolder, function () :Void {});
		}
	}
	
	static function saveConfig (config :AppConfig, cb :String->Void) :Void
	{
		org.transition9.util.Assert.isNotNull(config, " config is null");
		org.transition9.util.Assert.isNotNull(config.key, " config.key is null");
		redis.saveObject(config, function () :Void {
			redis.sadd(CONFIG_LIST, config.key, function (error :Err, done :Int) :Void {
				if (error != null) {
					cb(error);
					return;
				}
				cb(null);
			});
		});
	}
	
	static function loadConfig (key :String, cb :AppConfig->Void) :Void
	{
		redis.getObject(key, AppConfig, function (c :AppConfig) :Void {
			cb(c);
		});
	}
	
	static function deleteConfig (config :AppConfig, cb :Void->Void) :Void
	{
		redis.deleteObject(config, function () :Void {
			redis.exists(CONFIG_LIST, function (e :Err, exists :Int) :Void {
				redis.srem(CONFIG_LIST, config.key, function (e :Err, removed :Int) :Void {
					cb();
				});
			});
		});
	}
	
	static function getAllConfigs (cb :Array<AppConfig>->Void) :Void
	{
		redis.exists(CONFIG_LIST, function (e :Err, exists :Int) :Void {
			org.transition9.util.Assert.isNull(e, Std.string(e));
			if (exists == 1) {
				redis.smembers(CONFIG_LIST, function (e :Err, configsKeys :Array<Dynamic>) :Void {
					org.transition9.util.Assert.isNull(e, Std.string(e));
					var configs = new Array<AppConfig>();
					redis.scard(CONFIG_LIST, function (e :Err, size :Int) :Void {
						org.transition9.util.Assert.isNull(e, Std.string(e));
						for (configKey in configsKeys) {
							loadConfig(configKey, function (config :AppConfig) :Void {
								org.transition9.util.Log.debug("Loaded config " + config);
								configs.push(config);
								if (configs.length == size) {
									cb(configs.filter(Predicates.notNull).array());
								}
							});
						}
					});
				});
			} else {
				cb([]);
			}
		});
	}
	
	static function getNextFreePort (cb :Int->Void) :Void
	{
		getAllConfigs(function (configs :Array<AppConfig>) :Void {
			var usedPorts :Set<Int> = Sets.newSetOf(ValueType.TInt);
			for (config in configs) {
				if (config != null) {
					usedPorts.add(config.internalPort);
				}
			}
			var port = START_PORT;
			while (usedPorts.exists(port)) {
				port++;
			}
			cb(port);
		});
	}
	
	public function deployApp (data :Bytes, conf :ClientAppConfig, cb :String->Void) :Void
	{
		var self = this;
		org.transition9.util.Assert.isNotNull(conf, "Bad: conf :ClientAppConfig is null");
		org.transition9.util.Log.debug("deployApp " + StringUtil.stringify(conf));
		var config :AppConfig = cast conf;
		org.transition9.util.Log.debug('config=' + config);
		
		config.subdomain = config.subdomain.trim();
		config.subdomain = config.subdomain.startsWith("/") ? config.subdomain.substr(1) : config.subdomain;
		
		if (config.subdomain.isBlank()) {
			var msg = "subDomain cannot be / or null or blank";
			org.transition9.util.Log.error(msg);
			cb(msg);
			return;
		}
		
		if (data == null || data.length == 0) {
			var msg = "data null or 0 length";
			org.transition9.util.Log.error(msg);
			cb(msg);
			return;
		}
		
		var apppath = Node.path.join("/tmp",  config.subdomain);
		var tempZipPath = Node.path.join("/tmp",  config.subdomain + ".zip");
		//Create the folder
		Node.childProcess.exec("mkdir -p " + apppath, [], function (error :Dynamic, stdout:Dynamic, stderr:Dynamic) :Void {
			
			org.transition9.util.Log.debug("  writing zip file=" + tempZipPath); 
			Node.fs.writeFileSync(tempZipPath, data.getData(), NodeC.BINARY);
			
			Node.path.exists(tempZipPath, function (zipExists :Bool) :Void {
				if (zipExists) {
					org.transition9.util.Log.debug("    exists " + tempZipPath);
					//Unzip
					org.transition9.util.Log.debug("    unzipping " + tempZipPath);
					org.transition9.util.Log.debug("    spawn: unzip -o " + " -d " + apppath + " " + tempZipPath);
					var command = "unzip " + tempZipPath + " -d " +  apppath;
					Node.childProcess.exec(command, [], 
					function (error :Dynamic, stdout:Dynamic, stderr:Dynamic) :Void {
						org.transition9.util.Log.debug("        done unzipping ");
						org.transition9.util.Log.debug('               error=' + error);
						org.transition9.util.Log.debug(               'stdout=' + stdout);
						org.transition9.util.Log.debug('               stderr=' + stderr);
						
						org.transition9.util.Log.debug(apppath + " contents:\n  " + Node.fs.readdirSync(apppath).join("\n  "));
						
						if (error != null) {
							cb(error);
							return;
						}
						
						self.deployAppFromLocalDir(tempZipPath, conf, cb);
						
					});
				} else {
					org.transition9.util.Log.error("Missing zip file after writing");
					cb("Missing zip file after writing");
				}
			});
		});
	}
	
	public function deployAppFromLocalDir (localDir :String, conf :ClientAppConfig, cb :String->Void) :Void
	{
		var self = this;
		org.transition9.util.Assert.isNotNull(conf, "Bad: conf :ClientAppConfig is null");
		org.transition9.util.Log.info("deployAppFromLocalDir " + localDir );
		var config :AppConfig = AppConfig.from(conf);
		org.transition9.util.Log.debug('config=' + config);
		
		config.subdomain = config.subdomain.trim();
		config.subdomain = config.subdomain.startsWith("/") ? config.subdomain.substr(1) : config.subdomain;
		
		if (config.subdomain.isBlank()) {
			var msg = "subDomain cannot be / or null or blank";
			org.transition9.util.Log.error(msg);
			cb(msg);
			return;
		}
		
		org.transition9.util.Assert.isTrue(config.port >= 80, "port must be >= 80");
		
		getNextFreePort(function (port :Int) :Void {
			config.internalPort = port;
			org.transition9.util.Log.info("Next free port=" + port);
			var md5 = "";
			var date = Date.now();
			
			config.appFolder = createAppFolderName(config.subdomain, config.port, md5, date);
			config.url = config.subdomain + "." + Properties.server + (config.port == 80 ? "" : ":" + config.port);
			config.internalAddress = "127.0.0.1:" + config.internalPort;
			config.root = Node.path.join(_appDir, config.appFolder);
			
			config.key = redisKey(config.appFolder);
			
			var apppath = Node.path.join(_appDir, config.appFolder);
			
			org.transition9.util.Log.debug('config=' + config);
				
			// org.transition9.util.Log.info("exists? " + apppath);
			Node.path.exists(apppath, function (exists :Bool) :Void {
				org.transition9.util.Log.debug('  exists=' + exists);
				if (exists) {
					org.transition9.util.Log.info("  removing " + apppath);
					Node.fs.rmdirSync(apppath);
				}
				org.transition9.util.Log.info("  creating " + apppath + "...");
				Node.fs.mkdirSync(apppath, 33261);//755
				
				org.transition9.util.Log.debug(' deploying ' + JSON.stringify(config));
				
				Node.path.exists(localDir, function (exists :Bool) :Void {
					if (exists) {
						org.transition9.util.Log.debug("    exists " + localDir);
						
						localDir = localDir.trim();
						if (localDir.charAt(localDir.length - 1) == "/") {
							localDir = localDir.substr(0, localDir.length - 1);
						}
						org.transition9.util.Log.debug(localDir + " contents:\n  " + Node.fs.readdirSync(localDir).join("\n  "));
						org.transition9.util.Log.debug("     cp -r " + localDir + "/* " + apppath + "/");
						
						var command = "cp -r " + localDir + "/* " + apppath + "/";
						org.transition9.util.Log.info(command);
						Node.childProcess.exec(command, [], 
							function (error :Dynamic, stdout:Dynamic, stderr:Dynamic) :Void {
								org.transition9.util.Log.info("        done " + command);
								org.transition9.util.Log.debug('               error=' + error);
								org.transition9.util.Log.debug(               'stdout=' + stdout);
								org.transition9.util.Log.debug('               stderr=' + stderr);
								
								if (error != null) {
									cb(error);
									return;
								}
								
								org.transition9.util.Log.debug(apppath + " contents:\n  " + Node.fs.readdirSync(apppath).join("\n  "));
								
								org.transition9.util.Log.debug("                    setActiveApp, passing own callback");
								
								config.isActive = false;
								saveConfig(config, function (err :String) :Void {
									if (err != null) {
										deleteApp(config.appFolder, function () :Void {
											cb(err);
										});
										return;
									}
									setActiveApp(config, function (error :String) :Void {
										
										if (error != null) {
											deleteApp(config.appFolder, function () :Void {
												cb("\nsetActiveApp failed: \n" + error);
											});
											return;
										}
										
										org.transition9.util.Log.debug("!!!!!!calling original callback");
										cb("Success!!!!");
									});
								});
							});
					} else {
						org.transition9.util.Log.error("Missing folder=" + localDir);
						cb("\nMissing folder=" + localDir);
					}
				});
			});
		});
	}
	
	static function setActiveApp (config :AppConfig, cb :String->Void) :Void
	{
		org.transition9.util.Log.info("setActiveApp");
		//Stop current app at same domain/port, if running
		shutdownMaskingApp(config, function (e :Dynamic) :Void {
			trace("    finished shutdownMaskingApp");
			if (e != null) {
				cb("\nshutdownMaskingApp failed: \n" + e);
				return;
			}
			
			startAppUpstart(config, function (error :Dynamic) :Void {
				org.transition9.util.Log.info("    finished startAppUpstart");
				if (error != null) {
					cb("\nstartAppUpstart failed: \n" + error);
					return;
				}
				org.transition9.util.Log.debug("                            startApp");
				org.transition9.util.Log.debug("                            calling updateNginx from setActiveApp");
				config.isActive = true;
				saveConfig(config, function (error :Dynamic) :Void {
					org.transition9.util.Log.info("   finished saveConfig (active app config)");
					if (error != null) {
						cb("\nsaveConfig failed: \n" + error);
						return;
					}
					updateNginx(cb);
				});
			});
		});
	}
	
	/** Returns if app found and when shutdown, false if not found, or error */
	static function shutdownMaskingApp (config :AppConfig, cb :Dynamic->Void) :Void
	{
		org.transition9.util.Log.info("shutdownMaskingApp ");
		getAllConfigs(function (configs :Array<AppConfig>) :Void {
			if (configs.length == 0) {
				trace("    !!!!! configs.length == 0, cb");
				cb(null);
			} else {
				
				var check = function (otherconfig :AppConfig, doneChecking :Void->Void) :Void {
					if (otherconfig.isActive && config.appFolder != otherconfig.appFolder && config.subdomain == otherconfig.subdomain && config.port == otherconfig.port) {
						shutdownApp(otherconfig, function (isShutdown :Bool) :Void {
							trace("    !!!!! shutdown config, cb");
							doneChecking();
						});
					} else {
						doneChecking();
					}
				}
				
				var finished = function (err) :Void {
					cb(err);
				}
				
				AsyncLambda.iter(configs, check, finished);
			}
		});
	}
	
	static function getAppFolders () :Array<String>
	{
		var appIds = Node.fs.readdirSync(_appDir);
		appIds.remove("cache");
		return appIds;
	}
	
	static function deleteApp (appFolder :String, cb :Void->Void) :Void
	{
		org.transition9.util.Log.warn("deleteApp " + appFolder);
		stopUpstart(appFolder, function () :Void {
			org.transition9.util.Log.info("rm -rf  " + Node.path.join(_appDir, appFolder));
			Node.childProcess.exec("rm -rf  " + Node.path.join(_appDir, appFolder), [], 
				function (error :Dynamic, stdout:Dynamic, stderr:Dynamic) :Void {
					org.transition9.util.Log.debug("   error=" + error);
					org.transition9.util.Log.debug("   stdout=" + stdout);
					org.transition9.util.Log.debug("   stderr=" + stderr);
					if (error != null) {
						org.transition9.util.Log.error("Error on deleting  down app " + appFolder + "\n" + error);
					}
					loadConfig(redisKey(appFolder), function (config :AppConfig) :Void {
						if (config != null) {
							deleteConfig(config, cb);
						} else {
							cb();
						}
					});
				});
			});
	}
	
	/**
	  * Shutdown app via upstart, and delete upstart config
	  */
	static function shutdownApp (config :AppConfig, cb :Bool->Void) :Void
	{
		org.transition9.util.Log.info("shutdownApp");
		stopUpstart(config.appFolder, function () :Void {
			trace("    finished stopUpstart");
			config.isActive = false;
			saveConfig(config, function (error :Dynamic) :Void {
				trace("   finished saved config=" + config);
				cb(true);
			});
		});
	}
	
	static function stopUpstart (appFolder :String, cb :Void->Void) :Void
	{
		org.transition9.util.Log.info("stopUpstart");
		var upstartAppId = UPSTART_APP_PREFIX + appFolder;
		var upstartPath = "/etc/init/" + upstartAppId + ".conf";
		var command = "/sbin/initctl stop " + upstartAppId;
		org.transition9.util.Log.info(command);
		Node.childProcess.exec(command, [], 
			function (error :Dynamic, stdout:Dynamic, stderr:Dynamic) :Void {
				org.transition9.util.Log.info("    finished command");
				org.transition9.util.Log.debug('               error=' + error);
				org.transition9.util.Log.debug(               'stdout=' + stdout);
				org.transition9.util.Log.debug('               stderr=' + stderr);
				
				if (error != null) {
					org.transition9.util.Log.error("Error on shutting down app " + error);
				} 
				org.transition9.util.Log.debug("stdout=" + stdout);
				org.transition9.util.Log.debug("stderr=" + stderr);
				
				//Now remove the script
				Node.path.exists(upstartPath, function (exists :Bool) :Void {
					if (exists) {
						org.transition9.util.Log.debug("deleting " + upstartPath);
						Node.fs.unlinkSync(upstartPath);
					}
					cb();
				});
			});
	}
	
	static function startAppUpstart (config :AppConfig, cb :Dynamic->Void) :Void
	{
		org.transition9.util.Log.debug("startAppUpstart " + config);
		var sourceDir = config.root;
		var scriptPath = Node.path.join(config.root, config.scriptName);
		Node.path.exists(scriptPath, function (exists :Bool) :Void {
			if (exists) {
				var upstartPath = "/etc/init/" + UPSTART_APP_PREFIX + config.appFolder + ".conf";
				org.transition9.util.Log.debug("writing to " + upstartPath);
				if (config.internalPort == null || config.internalPort < START_PORT) {
					cb("\nstartAppUpstart failed, config.internalPort=" + config.internalPort + "\n config=" +config);
					return;
				}
				Node.fs.writeFileSync(upstartPath, 
					new Template(Resource.getString("app.conf.tmpl")).execute({
						author :"author",
						appdir :config.root,
						script :"exec sudo -u www-data /usr/local/bin/node " + scriptPath + " " + config.internalPort + " 2>&1 >> /var/log/" + UPSTART_APP_PREFIX + config.appFolder + ".node.log"
					}));
					
				var command = "/sbin/initctl start " + UPSTART_APP_PREFIX + config.appFolder;
				org.transition9.util.Log.info(command);
				Node.childProcess.exec(command, [], 
					function (error :Dynamic, stdout:Dynamic, stderr:Dynamic) :Void {
						org.transition9.util.Log.info("   finished " + command);
						org.transition9.util.Log.debug('               error=' + error);
						org.transition9.util.Log.debug(               'stdout=' + stdout);
						org.transition9.util.Log.debug('               stderr=' + stderr);
						
						if (error != null) {
							cb("\n" + command + " failed: \n" + error);
							return;
						}
						cb(null);
				});
			} else {
				org.transition9.util.Log.error("Script for node doesn't exist=" + scriptPath);
				cb("\nScript for node doesn't exist=" + scriptPath);
			}
		});
	}
	
	/**
	  * Get active apps, and rewrite the nginx.conf file, finally calling nginx reload or start.
	  */
	public static function updateNginx (cb :Dynamic->Void) :Void
	{
		#if disable_nginx
		cb(null);
		return;
		#end
		
		org.transition9.util.Log.info("updateNginx");
		createNginxConfFromActiveApps(function (nginxConf :String) :Void {
			org.transition9.util.Log.debug("writing " + Node.path.join(Properties.appmanager_home, "etc/nginx/nginx.conf"));
			Node.fs.writeFileSync(Node.path.join(Properties.appmanager_home, "etc/nginx/nginx.conf"), nginxConf);
			//Write the init.d script
			var subs = Properties.toDynamicObject();
			Node.fs.writeFileSync("/etc/init.d/nginx", new Template(Resource.getString("init.d-nginx.tmpl")).execute(subs));
			Node.fs.chmodSync("/etc/init.d/nginx", 484);//Octal: 744
				var command = "/etc/init.d/nginx status";
				org.transition9.util.Log.info(command);
				Node.childProcess.exec(command, [],  
					function (error :Dynamic, stdout:Dynamic, stderr:Dynamic) :Void {
						org.transition9.util.Log.info("    finished "+ command);
						org.transition9.util.Log.debug('               error=' + error);
						org.transition9.util.Log.debug(               'stdout=' + stdout);
						org.transition9.util.Log.debug('               stderr=' + stderr);
						
						if (error != null) {
							cb("\n/etc/init.d/nginx status failed: \n" + error);
							return;
						}
						
						var initdCommand = "reload";
						if (Std.string(stdout).indexOf("NOT") > -1) {
							initdCommand = "start";
						}
						var command = "/etc/init.d/nginx " + initdCommand; 
						org.transition9.util.Log.info(command);
						Node.childProcess.exec(command, [], 
							function (error :Dynamic, stdout:Dynamic, stderr:Dynamic) :Void {
								org.transition9.util.Log.info("    finished " + command);
								org.transition9.util.Log.debug('               error=' + error);
								org.transition9.util.Log.debug(               'stdout=' + stdout);
								org.transition9.util.Log.debug('               stderr=' + stderr);
								cb(null);
							});
					});
		});
	}
	
	static function createNginxConfFromActiveApps (cb :String->Void) :Void
	{
		var sb = new StringBuf();
		org.transition9.util.Assert.isNotNull(haxe.Resource.getString("nginx.conf.server.tmpl"), "Missing resource nginx.conf.server.tmpl");
		org.transition9.util.Assert.isNotNull(haxe.Resource.getString("nginx.conf.server.location.tmpl"), "Missing resource nginx.conf.server.location.tmpl");
		var appTemplate = new haxe.Template(haxe.Resource.getString("nginx.conf.server.tmpl"));
		var locationTemplate = new haxe.Template(haxe.Resource.getString("nginx.conf.server.location.tmpl"));
		var subs = Properties.toDynamicObject();
		getActiveAppsFromDB(function (configs :Array<AppConfig>) :Void {
			trace("getActiveAppsFromDB=" + (configs != null ? Std.string(configs) : "null"));	
			var serverDefinitions = "";
			var locationDefinitions = "";
			if (configs != null) {
				for (config in configs) {
					if (config == null) {
						org.transition9.util.Log.debug("WTF, config null");  
						continue;
					}
					for (field in Reflect.fields(subs)) {
						Reflect.setField(config, field, Reflect.field(subs, field));
					}
					serverDefinitions += "\n\n" + appTemplate.execute(config);
					locationDefinitions += "\n\n" + locationTemplate.execute(config);
				}
			}
			
			//Add all the individual app server definitions into the main nginx.conf
			var servers = sb.toString();
			Reflect.setField(subs, "server_definitions", serverDefinitions);
			Reflect.setField(subs, "location_definitions", locationDefinitions);
			Reflect.setField(subs, "appmanager_port_internal", Std.parseInt(Reflect.field(subs, "appmanager_port_internal")));
			
			var serverTemplate = new haxe.Template(haxe.Resource.getString("nginx.conf.tmpl"));
			trace("done createNginxConfFromActiveApps");
			cb(serverTemplate.execute(subs));
			trace("done2 createNginxConfFromActiveApps");
		});
	}
	
	/** Make sure folders marked with an ACTIVE token are actually running */
	static function checkActiveApps (finished :Void->Void, ?forceNginxUpdate :Bool = false) :Void
	{
		org.transition9.util.Log.info("checkActiveApps");
		var isNginxRestartRequired = forceNginxUpdate;
		
		//This is called when the async loop is finished
		var finishedCheckingActiveApps = function (err) :Void {
			if (isNginxRestartRequired) {
				org.transition9.util.Log.info("At least one app triggered nginx restart");
				updateNginx(function (done :Bool) :Void {
					org.transition9.util.Log.info("   finished updateNginx success=" + done);
					finished();
				});
			} else {
				org.transition9.util.Log.debug("Finished checking apps, no nginx restart required");
				finished();
			}
		}
		
		getRunningApps(function (runningAppFolders :Array<String>) :Void {
			org.transition9.util.Log.info("    finished getRunningApps\n" + runningAppFolders.join("\n"));
			getActiveAppsFromDB(function (configs :Array<AppConfig>) :Void {
				org.transition9.util.Log.info("    finished getActiveAppsFromDB\n" + configs.join("\n"));
				var checkConfig = function (config :AppConfig, onFinished :Void->Void) :Void {
					var isRunning = runningAppFolders.has(config.appFolder);
					if (!isRunning) {
						isNginxRestartRequired = true;
						org.transition9.util.Log.error(config.appFolder + " is marked as ACTIVE, but is not running, restarting...");
						getNextFreePort(function (port :Int) :Void {
							//Write config file
							config.url = Properties.server + ":" + config.port + "/" + config.subdomain;
							config.internalPort = port;
							saveConfig(config, function (error :Dynamic) :Void {
								startAppUpstart(config, function (error :Dynamic) :Void {
									if (error != null) {
										org.transition9.util.Log.error(error);
									}
									org.transition9.util.Log.debug(config.appFolder + " started");
									onFinished();
								});
							});
						});
					} else {
						onFinished();
					}
				}
		
				AsyncLambda.iter(configs, checkConfig, finishedCheckingActiveApps);
			});
		});
	}
	
	static function isAppRunning (config :AppConfig, cb :Bool->Void) :Void
	{
		var out :String = "";
		var command = "/sbin/initctl list";
		org.transition9.util.Log.info(command);
		Node.childProcess.exec(command, [],
			function (error :Dynamic, stdout:Dynamic, stderr:Dynamic) :Void {
				org.transition9.util.Log.info("    finished " + command);
				org.transition9.util.Log.debug('               error=' + error);
				org.transition9.util.Log.debug(               'stdout=' + stdout);
				org.transition9.util.Log.debug('               stderr=' + stderr);
				
				for (appstatus in Std.string(stdout).split("\n")) {
					var app = appstatus.split(" ")[0];
					var status = appstatus.split(" ")[1];
					
					if (app.startsWith(UPSTART_APP_PREFIX)) {
						org.transition9.util.Log.debug('appstatus=' + appstatus);
						if (app.indexOf(config.appFolder) > -1) {
							if (status.indexOf("running") > -1) {
								cb(true);
								return;
							}
						}
					}
				}
				cb(false);
			});
	}
	
	static function getActiveAppsFromDB (cb :Array<AppConfig>->Void) :Void
	{
		getAllConfigs(function (allConfigs :Array<AppConfig>) :Void {
			cb(allConfigs == null ? [] : allConfigs.filter(Predicates.createPropertyEquals("isActive", true)).array());
		});
	}
	
	static function getRunningApps (cb :Array<String>->Void) :Void
	{
		org.transition9.util.Log.debug("getRunningApps");
		var running = [];
		
		Node.childProcess.exec("/sbin/initctl reload-configuration", [], function (error :Dynamic, stdout:Dynamic, stderr:Dynamic) :Void {
			Node.childProcess.exec("/sbin/initctl list", [], function (error :Dynamic, stdout:Dynamic, stderr:Dynamic) :Void {
				for (appstatus in Std.string(stdout).split("\n")) {
					var app = appstatus.split(" ")[0];
					var status = appstatus.split(" ")[1];
					if (app.startsWith(UPSTART_APP_PREFIX) && status.indexOf("running") > -1) {
						running.push(app.replace(UPSTART_APP_PREFIX, "").replace(".conf", ""));
					}
				}
				org.transition9.util.Log.debug("found running apps=" + running);
				cb(running);
			});
		});
			
	}
	
	static function createAppFolderName(subdomain :String, port :Int, md5 :String, date :Date) :String
	{
		subdomain = subdomain.startsWith("/") ? subdomain.substr(1) : subdomain;
		subdomain = subdomain == "" ? subdomain.substr(1) : subdomain;
		// return port + "__" + subdomain + "__" + md5 + "__" + date.toString();
		// return subdomain + "__" + port + "__" + md5 + "__" + date.toString().replace(" ", "_").replace(":", "-");
		return subdomain + "__" + port  + "__" + date.toString().replace(" ", "_").replace(":", "-");
	}
	
	static function getSubDomainFromAppFolderName(name :String) :String
	{
		return name.split("__")[0];
	}
	
	static function getPortFromAppFolderName(name :String) :Int
	{
		return Std.parseInt(name.split("__")[1]);
	}
	
	static function getUpstartConfName (config :AppConfig) :String
	{
		return UPSTART_APP_PREFIX + config.appFolder;
	}
	
	/**
	  * Clients send a random query token, we store it so we don't repeat commands.
	  */
	static function isQueryToken (token :String, cb :Bool->Void) :Void
	{
		redis.exists(QUERY_TOKEN_PREFIX + token, function (err :Err, exists :Int) :Void {
			cb(exists == 1);
		});
	}
	
	/** Add query token that expires in 24 hours, so we don't repeat query commands */
	static function addQueryToken (token :String, cb :Bool->Void) :Void
	{
		redis.set(QUERY_TOKEN_PREFIX + token, "1", function (err :Err, success :Bool) :Void {
			redis.expire(QUERY_TOKEN_PREFIX + token, 60*60*24, function (err :Err, done :Int) :Void {
				cb(done == 1);
			});
		});
	}
	
	#end
}
