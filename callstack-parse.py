#!/usr/bin/python

import argparse
import re
import datetime
import sets
import os
import json
import subprocess

#atos -o ~/Library/Developer/Xcode/iOS\ DeviceSupport/9.2\ \(13C75\)/Symbols/System/Library/Frameworks/AVFoundation.framework/AVFoundation -l 0x189070000 0x1890aa09c 0x1890b0254 0x18915a3dc

class BinaryImages:
    initre = re.compile(r"([0-9/: ]*)  Starting performance tracker on iOS ([a-zA-Z0-9.() ]*)\n")
    beginre = re.compile(r"([0-9/: ]*)  <BinaryImages>\n")
    imagere = re.compile(r"([0-9/: ]*)  ([a-zA-Z0-9_./ +-]*)\|(0x[a-z0-9]*)\n")
    endre = re.compile(r"([0-9/: ]*)  </BinaryImages>\n")

    def __init__(self, logstring):
        self.osversion = None
        self.images = None
        self.finished = False

        ii = BinaryImages.initre.findall(logstring)
        if ii:
            self.osversion = ii[0][1]

    def parse(self, logstring):
        if self.finished:
            return False

        if self.images == None:
            bi = BinaryImages.beginre.findall(logstring)
            if bi:
                self.images = []
            return bi != None

        ii = BinaryImages.imagere.findall(logstring)
        if ii and ii[0][1] and ii[0][2]:
            self.images.append((ii[0][1], ii[0][2]))
            return True

        ei = BinaryImages.endre.findall(logstring)
        if ei:
            self.finished = True
            return True

        print "Error parsing binary image %s" % logstring

class DropStack:
    fullre = re.compile(r"([0-9/: ]*)  Drop frame stack \(slide (0x[a-z0-9]*)\): (([a-zA-Z._]*:0x[a-z0-9]*\|)*)\n")
    stackre = re.compile(r"(([a-zA-Z._]*):(0x[a-z0-9]*)\|)")

    def __init__(self, logstring):
        self.timestamp = None
        self.stack = None

        fsi = DropStack.fullre.findall(logstring)
        if fsi:
            si = DropStack.stackre.findall(fsi[0][2])
            if si:
                self.timestamp = datetime.datetime.strptime(fsi[0][0], "%Y/%m/%d %H:%M:%S:%f")
                self.stack = [(item[1], item[2]) for item in si]

def symbolicate(binaryimages, stacks, dsym):
    addressesDict = {}

    for imageId, imageTuple in enumerate(binaryimages.images):
        path = imageTuple[0]
        loadaddress = imageTuple[1]
        head, image = os.path.split(imageTuple[0])

        addresses = sets.Set()
        for stack in stacks:
            for (module, address) in stack.stack:
                if module == image:
                    addresses.add(address)

        if len(addresses) == 0:
            continue

        mapping = {}

        p = None
        if imageId == 0:
            p = subprocess.Popen("atos -o %s -l %s" % (dsym, loadaddress), shell=True, stdout=subprocess.PIPE, stdin=subprocess.PIPE)
        else:
            fullpath = "~/Library/Developer/Xcode/iOS DeviceSupport/%s/Symbols%s" % (binaryimages.osversion, path)
            p = subprocess.Popen("atos -arch arm64 -o \"%s\" -l %s" % (fullpath, loadaddress), shell=True, stdout=subprocess.PIPE, stdin=subprocess.PIPE)

        if p:
            for idx, val in enumerate(addresses):
                p.stdin.write("%s\n" % val)
            result = p.communicate()[0]
            p.stdin.close()

            lines = result.split('\n')

            if len(lines) >= len(addresses):
                for idx, val in enumerate(addresses):
                    if val != lines[idx]:
                        mapping[val] = lines[idx]

        for stack in stacks:
            updatedStack = [(module, address) if (module != image or not mapping.has_key(address)) else (module, mapping[address]) for (module, address) in stack.stack]
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
            <link title="timeline-styles" rel="stylesheet" href="https://cdn.knightlab.com/libs/timeline3/latest/css/timeline.css">
            <script src="https://cdn.knightlab.com/libs/timeline3/latest/js/timeline.js"></script>
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

    currentBinaryImages = None
    stacksDict = {}

    with open(args.log) as f:
        for line in f:
            binaryImages = BinaryImages(line)
            if binaryImages.osversion:
                currentBinaryImages = binaryImages
                stacksDict[currentBinaryImages] = []
                continue

            if currentBinaryImages:
                if currentBinaryImages.parse(line):
                    continue
            else:
                continue

            stack = DropStack(line)
            if stack.stack:
                stacksDict[currentBinaryImages].append(stack)
                continue

    stacks = []

    for binaryimages in stacksDict:
        symbolicate(binaryimages, stacksDict[binaryimages], args.dsym)
        stacks += stacksDict[binaryimages]

    if args.timeline :
        head, tail = os.path.split(args.log)
        serializeTimeline(stacks, args.timeline, "%s serialization" % tail)

if __name__ == "__main__":
    main()
