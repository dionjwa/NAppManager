#! /usr/bin/env sh
haxe -lib nodejs -D debug -lib hydrax -cp src -js build/server.js -main TestServer
haxe -cmd "neko build/Appclient.n apps.transition9.local testapp build 80" buildclient.hxml
