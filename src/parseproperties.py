#! /usr/bin/env python
"""
Reads properties files.  Does not require sections
"""

import ConfigParser

#For allowing section-less config files (i.e. properties)
default = 'asection'
class FakeSecHead(object):
	def __init__(self, fp):
		self.fp = fp
		self.sechead = '[' +  default + ']\n'
	def readline(self):
		if self.sechead:
			try: return self.sechead
			finally: self.sechead = None
		else: return self.fp.readline()
		
def readProperties(filename, props = None):
	#Load config options
	cp = ConfigParser.SafeConfigParser()
	cp.readfp(FakeSecHead(open(filename)))
	#Process and add extra config options
	if props == None:
		props = {}
	for name, value in cp.items(default):
		props[name] = value
	return props
	
if __name__ == '__main__':
    # do something
    print "Import to other scripts, do readProperties('somefile')"
