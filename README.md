[ubuntuamazon]: https://help.ubuntu.com/community/EC2StartersGuide
[nodejs]: http://nodejs.org/
[nginx]: http://nginx.net/
[haxe]: http://haxe.org/
[npm]: http://npmjs.org/
[ant]: http://ant.apache.org/

# NAppManager (Node.js Application Manager)

NAppManager is an application deployment system for [Node.js][nodejs] based server apps. It simplifies the process of deploying and updating live applications and games.  

- Node.js apps sit behind an [Nginx][nginx] reverse proxy server.
- When updating an app or game, NAppManager will serve the new version to new clients, but keep the old version for currently connected clients (thanks to Nginx).
- Communication with the NAppManager is through standard HTTP requests.
- A simple web interface is provided for shutting down, reverting, and deleting apps.
- You can have a single server serving as many apps as you want, NAppManager makes sure only one version is running at once.

It's only tested with [Ubuntu Server running as Amazon EC2 instances][ubuntuamazon], but will likely run on any linux box with minor modifications.  It requires HaXe and Python to build and deploy the application manager, but the deployed server apps themselves only need to be Node.js scripts. 

### Please note:

NAppManager is in early alpha.  It's good enough to begin using, but there is currently no security mechanisms for the web interface.  Admin authentication will be added in the near future.  

### Installation/Setup

## Local machine

You need the following on your local machine:

- [Haxe](http://haxe.org/download)
- Hydrax via **haxelib**: `haxelib install hydrax`
- [Ant][ant]
- rsync (for now.  Soon you will be able to upload via HTTP). 
- Python

## The server

I'll assume you have an Ubuntu server that you can ssh into.  Probably the quickest way is to get a free Amazon Web Services account, and [create an Ubuntu instance][ubuntuamazon].  Then, follow these steps:

- Download this repo to your local machine (not the server).  We'll call this folder the **NAppManager** folder.
- Create a copy of **etc/build.properties.example** and rename to **etc/build.properties** in your local NAppManager folder.  Replace the values of these keys with the appropriate values to allow access to your server:

	`user=ubuntu`
	
	`server=ec2-35-131-259-125.compute-1.amazonaws.com`
	
	`pkey=/Users/<your login>/.ec2/<your ec2 key>.pem`

- Go to the NAppManager folder in a terminal or dos promt, and run ant (the default task is to sync to the server):

	`ant`
	
- Point your browser at your server (e.g. localhost if you have a virtual machine locally, or something like `ec2-35-131-259-125.compute-1.amazonaws.com` for an amazon instance.  If everything worked, you will see "Node.js AppManager".
- Now launch a test app:
	
	`ant testapp`
	
- Refresh your browser pointing to your server, and you should see the app.
- You can launch many test apps. 

### Using it in an existing project

Import NAppManager **build.xml** into your own project ant build file, and import your own **build.properties** or equivalent.  Then call the ant task:

	`ant uploadapp`
	
And your app is rsync'ed, and registered with the NAppManager.  

### Other notes

Remember, you will only be able to ssh into the box through the port defined in **ssh_port** in `build.properties`.  Allowing you to define a non-standard ssh port is extra security precaution.




