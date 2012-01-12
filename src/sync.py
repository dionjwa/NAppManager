#! /usr/bin/env python

"""
Syncs the AppManager to the remote server, and calls the setup.sh script remotely
"""
from parseproperties import *
import os, os.path, sys

#Load the common properties
projectDir = os.path.dirname(os.path.dirname(os.path.abspath( __file__ )))
print os.path.abspath( __file__ )
print "projectDir", projectDir
print sys.argv

propsFile = sys.argv[1] if len(sys.argv) > 1 else os.path.join(projectDir, "etc/config.properties")
print propsFile
props = readProperties(propsFile)
# props = readProperties(os.path.join(projectDir, "config.properties"))
publickey = ' -i ' + props['pkey'] if props.has_key('pkey') else ""
print "Server: " + props['server']
def sshcommand (command, trace=False):
	command = 'ssh -p ' + props['ssh_port'] + publickey + ' ' + props['user'] + '@' + props['server'] + ' "' + command + ' "'
	if trace:
		print command
	os.system(command)		

print 'haxe ' + os.path.join(projectDir, 'etc/buildserver.hxml')



os.system('haxe -resource ' + propsFile + '@config.properties ' + os.path.join(projectDir, 'etc/buildserver.hxml'))

# sshcommand('sudo stop appmanager')
#Create the install dir
sshcommand('sudo mkdir -p ' + props['appmanager_home'])
sshcommand('sudo chown  ' + props['user'] + ' ' +  props['appmanager_home'])


command = 'rsync -e "ssh -p ' + props['ssh_port'] + publickey + '" -azv --delete --exclude="build/test*" --exclude="#*" --exclude="*.pyc" --exclude="*.git" --exclude=".svn" --exclude=".DS_Store" ' + projectDir + '/ ' + props['user'] + '@' + props['server'] + ':' + props['appmanager_home']
print command
os.system(command)

#Install and/or update nginx, node.js, redis
sshcommand('cd ' + props['appmanager_home'] + ' ; ./src/setup.sh')

#Run the appmanager
# sshcommand('sudo start appmanager')
print "Start the appmanager on the server with:"
print "  sudo start appmanager"


