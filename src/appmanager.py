#! /usr/bin/env python
"""
Given a directory where each folder contains a web app,
manages integration with nginx.
More advanced app installation to follow.
"""

import os, sys, shutil, string
import platform
from string import Template
from parseproperties import *

def createTemplateInstance(tmplFileName, targetFileName, subs):
	read_data = None
	with open(tmplFileName, 'r') as f:
		read_data = f.read()
	f.close()
	s = Template(read_data)
	with open(targetFileName, 'w') as target:
		target.write(s.substitute(subs))
	target.close()
	
# def install(props):
	
	# #Prerequsites
	# nginxtar = "nginx-" + props["nginx_version"] + ".tar.gz"
	# print nginxtar
	# os.system("apt-get --assume-yes install libpcre3 libpcre3-dev libpcrecpp0 libssl-dev zlib1g-dev redis-server")
	# os.chdir(subs["basedir"])
	# if os.path.exists("lib/" + nginxtar):
	# 	print nginxtar + " found, copying to /tmp"
	# 	os.system("cp lib/" + nginxtar + " /tmp/")
	# else:
	# 	if not os.path.exists("/tmp/" + nginxtar):
	# 		os.system('wget --directory-prefix=/tmp "http://nginx.org/download/' + nginxtar +'"')
	
	# #Download and build
	# os.chdir("/tmp")
	# os.system("tar xzvf " + nginxtar)
	# os.chdir("nginx-" + props["nginx_version"])
	# os.system("./configure --prefix=" + props["nginx_install_prefix"] + " --with-http_ssl_module") 
	# os.system("make")
	# os.system("make install")
	
	# Update init.d script
	# fromFile = os.path.join(basedir, "etc", "nginx", "init.d-ubuntu", "nginx.tmpl")
	# toFile = "/etc/init.d/nginx"
	# print fromFile + "=>" + toFile + ", subs=" + str(subs)
	# createTemplateInstance(fromFile, toFile, props)
	# os.system("cp " + fromFile + " " + toFile)
	
	#Redis
	#TODO: fix this
	# os.system("/home/dion/storage/projects/tools/appmanager/lib/redis/install.sh")


#Read config file
basedir = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
if not os.path.exists(os.path.join(basedir, "config.properties")):
	print "Config file not found at=" + os.path.join(basedir, "config.properties")
	sys.exit(0)
#Use subs instead of configParser
subs = readProperties(os.path.join(basedir, "config.properties"))
subs["basedir"] = basedir


#Get the app folders
apps = []
apps_dir = subs["apps_dir"]
serverDefs = []
for appdir in os.listdir(apps_dir):
	if os.path.isdir(os.path.join(apps_dir, appdir)):
		apps.append(os.path.join(apps_dir, appdir))
		nginxServerDir = os.path.join(apps_dir, appdir, subs["app_nginx_server_def_dir"])
		serverDefs.append(nginxServerDir);
		
defstext = "include " + string.join(serverDefs, "/*;\n\tinclude ") + "/*;"

subs["server_definitions"] = defstext 


if len(sys.argv) <= 1:
	print "Commands: stop, start"
	sys.exit(0)
command = sys.argv[1]
print "command=" + command
if command == "stop":
	print "Stop apps ", apps
	for app in apps:
		if os.path.exists(os.path.join(app, "app",  "shutdown.sh")):
			print "Shutting down", app
			os.system(os.path.join(app, "app", "shutdown.sh"))
elif command == "start":
	print "Start configuration"
	print defstext
	print "Writing templated nginx.conf.tmpl to nginx.conf"
	createTemplateInstance(os.path.join(basedir, "etc", "nginx", "nginx.conf.tmpl"), os.path.join(basedir, "etc", "nginx", "nginx.conf"), subs)

	for app in apps:
		if os.path.exists(os.path.join(app, "app", "startup.sh")):
			print "Starting up", app
			os.system(os.path.join(app, "app", "startup.sh"))
	print "Reloading nginx"
	if os.system('/etc/init.d/nginx status | grep "found"'):
		print "Starting nginx"
		os.system("/etc/init.d/nginx start")
	else:
		print "Quietly reloading nginx"
		os.system("/etc/init.d/nginx quietupgrade")
# elif command == "install":
# 	install(subs)
else:
	print "Unknown command:", command

