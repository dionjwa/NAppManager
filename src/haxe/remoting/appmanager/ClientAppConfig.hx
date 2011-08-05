package haxe.remoting.appmanager;

class ClientAppConfig
{
	public function new () :Void {}
	
	public var subdomain :String;
	public var port :Int;
	public var scriptName :String;
	/** These will be added to the nginx server definition */
	public var domains :String;
}
