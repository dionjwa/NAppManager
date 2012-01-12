package haxe.remoting.appmanager;

import js.node.redis.SerializableRedis;

class AppConfig extends ClientAppConfig,
	implements SerializableRedis, implements Dynamic<Dynamic>
{
	public static function from (conf :ClientAppConfig) :AppConfig
	{
		var app = new AppConfig();
		app.domains = conf.domains;
		app.port = conf.port;
		app.scriptName = conf.scriptName;
		app.subdomain = conf.subdomain;
		return app;
	}
	
	public var key :String;
	public var isActive :Bool;
	public var appFolder :String;
	public var internalPort :Int;
	public var url :String;
	public var internalAddress :String;
	public var root :String;
	
	public function new () :Void 
	{
		super();
		isActive = false;
		internalPort = 0;
		port = 0;
	}

	public function toRedisHash () :Array<String> 
	{
		return [
			"appFolder", appFolder,
			"isActive", isActive ? "1" : "0", 
			"internalPort", Std.string(internalPort),
			"url", url, 
			"internalAddress", internalAddress, 
			"root", root, 
			"subdomain", subdomain, 
			"port", Std.string(port), 
			"scriptName", scriptName, 
			"domains", domains,
			"key", key,
		];
	}
	
	public function fromRedisHash (data :Dynamic<String>) :Void
	{
		isActive = Std.parseInt(data.isActive) == 1;
		appFolder = data.appFolder;
		internalPort = Std.parseInt(data.internalPort);
		url = data.url;
		internalAddress = data.internalAddress;
		root = data.root;
		
		//From clientAppConfig
		subdomain = data.subdomain;
		port = Std.parseInt(data.port);
		scriptName = data.scriptName;
		domains = data.domains;
		key = data.key;
	}
	
	public function toString () :String
	{
	    return org.transition9.util.StringUtil.objectToString(this, [
			"appFolder",
			"isActive",
			"internalPort",
			"url",
			"internalAddress",
			"root", 
			"subdomain",  
			"port",
			"scriptName",
			"domains",
			"key",
		]);
	}
}
