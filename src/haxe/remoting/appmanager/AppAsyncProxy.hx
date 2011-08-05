package haxe.remoting.appmanager;

import haxe.remoting.BiAsyncProxy;
import haxe.io.Bytes;
import haxe.remoting.appmanager.AppService;

class AppAsyncProxy extends BiAsyncProxy, 
	implements AppService
{
	public function new (c :haxe.remoting.AsyncConnection)
	{
		super(c.resolve(AppManager.REMOTING_ID));
	}
}
