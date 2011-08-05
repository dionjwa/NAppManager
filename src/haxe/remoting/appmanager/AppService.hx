package haxe.remoting.appmanager;

import haxe.io.Bytes;

interface AppService
{
	function deployApp (appData :Bytes, config :ClientAppConfig, cb :String->Void) :Void;
	function deployAppFromLocalDir (localDir :String, config :ClientAppConfig, cb :String->Void) :Void;
}
