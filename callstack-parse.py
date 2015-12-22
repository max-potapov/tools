#!/usr/bin/python

import argparse
import re
import datetime
import sets
import os
import json
import subprocess

class DropStack:
	fullre = re.compile(r"([0-9/: ]*)  Drop frame stack \(slide (0x[a-z0-9]*)\): (([a-zA-Z._]*:0x[a-z0-9]*\|)*)\n")
	stackre = re.compile(r"(([a-zA-Z._]*):(0x[a-z0-9]*)\|)")

	def __init__(self, logstring):
		self.timestamp = None
		self.loadaddress = None
		self.stack = None

		fsi = DropStack.fullre.findall(logstring)
		if fsi:
			si = DropStack.stackre.findall(fsi[0][2])
			if si:
				self.timestamp = datetime.datetime.strptime(fsi[0][0], "%Y/%m/%d %H:%M:%S:%f")
				self.loadaddress = fsi[0][1]
				self.stack = [(item[1], item[2]) for item in si]

def symbolicate(stacks, dsym):
	addressesDict = {}

	for stack in stacks:
		addresses = addressesDict.get(stack.loadaddress, sets.Set())
		for (module, address) in stack.stack:
			addresses.add(address)
		addressesDict[stack.loadaddress] = addresses

	for loadaddress in addressesDict:
		result = subprocess.Popen("atos -o %s -l %s %s" % (dsym, loadaddress, " ".join(addressesDict[loadaddress])), shell=True, stdout=subprocess.PIPE).stdout.read()
		lines = result.split('\n')

		mapping = {}
		for idx, val in enumerate(addressesDict[loadaddress]):
			if val != lines[idx]:
				mapping[val] = lines[idx]

		addressesDict[loadaddress] = mapping

	for stack in stacks:
		mapping = addressesDict.get(stack.loadaddress, {})
		updatedStack = [(module, address) if (not mapping.has_key(address)) else (module, mapping[address]) for (module, address) in stack.stack]
		stack.stack = updatedStack

def serializeTimeline(stacks, dest, title):
	timeline = { "title" : {
					 "text" : { "headline" : title },
					 "media": {
						"url": "",
          				"caption": "",
          				"credit": "" } } }
	events = []
	for stack in stacks:
		table = "<table class=stacktrace>"
		for (module, call) in stack.stack:
			table += "<tr><td>" + module + "</td><td>" + call + "</td></tr>"
		table += "/<table>"

		events.append({
			"start_date" : {
			 	"year" : stack.timestamp.year,
			 	"month" : stack.timestamp.month,
			 	"day" : stack.timestamp.day,
			 	"hour" : stack.timestamp.hour,
			 	"minute" : stack.timestamp.minute,
			 	"second" : stack.timestamp.second,
				"millisecond" : stack.timestamp.microsecond / 1000 },
			"media" : {
				"url" : "",
				"caption" : "",
				"credit": "" },
			"text" : {
				"headline" : stack.timestamp.strftime("%H:%M:%S.%f"),
				"text" : table
			}})
	timeline["events"] = events

	html_str = """
	<html lang="en">
		<head>
			<title>%s</title>
			<style>
			table.stacktrace td {
				font-family: monospace;
				font-size: 8pt;
			}
			</style>
		</head>
		<body>
			<link title="timeline-styles" rel="stylesheet" href="http://cdn.knightlab.com/libs/timeline3/latest/css/timeline.css">
			<script src="http://cdn.knightlab.com/libs/timeline3/latest/js/timeline.js"></script>
			<div id='timeline-embed' style="width: 100%%; height: 100%%"></div>
			<script type="text/javascript">
				window.timeline = new TL.Timeline('timeline-embed', JSON.parse('%s'));
			</script>
		</body>
	</html>
	""" % (title, json.dumps(timeline))

	result = open(dest,"w")
	result.write(html_str)
	result.close()

def main():
	parser = argparse.ArgumentParser(description='Parse logs and build dropped frame stacks statistics.')
	parser.add_argument('--dsym', dest='dsym', required=True, help='a path to .DSYM file')
	parser.add_argument('--log', dest='log', required=True, help='a path to the log file that contains dropped stacks info')
	parser.add_argument('--timeline', dest='timeline', required=False, help='a path to destination timeline serialization')

	args = parser.parse_args()

	stacks = []

	with open(args.log) as f:
		for line in f:
			stack = DropStack(line)
			if stack.stack:
				stacks.append(stack)

	symbolicate(stacks, args.dsym)

	if args.timeline :
		head, tail = os.path.split(args.log)
		serializeTimeline(stacks, args.timeline, "%s serialization" % tail)

if __name__ == "__main__":
    main()