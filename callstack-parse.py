#!/usr/bin/python

import argparse
import re
import datetime
import sets
import os
import json
import subprocess


class BinaryImages:
    init_re = re.compile(r"([0-9/: ]*)  Starting performance tracker on iOS ([a-zA-Z0-9.() ]*)\n")
    begin_re = re.compile(r"([0-9/: ]*)  <BinaryImages>\n")
    image_re = re.compile(r"([0-9/: ]*)  ([a-zA-Z0-9_./ +-]*)\|(0x[a-z0-9]*)\n")
    end_re = re.compile(r"([0-9/: ]*)  </BinaryImages>\n")

    def __init__(self, log_string):
        self.osVersion = None
        self.images = None
        self.finished = False

        ii = BinaryImages.init_re.findall(log_string)
        if ii:
            self.osVersion = ii[0][1]

    def parse(self, log_string):
        if self.finished:
            return False

        if self.images is None:
            bi = BinaryImages.begin_re.findall(log_string)
            if bi:
                self.images = []
            return bi is not None

        ii = BinaryImages.image_re.findall(log_string)
        if ii and ii[0][1] and ii[0][2]:
            self.images.append((ii[0][1], ii[0][2]))
            return True

        ei = BinaryImages.end_re.findall(log_string)
        if ei:
            self.finished = True
            return True

        print "Error parsing binary image %s" % log_string


class DropStack:
    full_re = re.compile(r"([0-9/: ]*)  Drop frame stack \(slide (0x[a-z0-9]*)\): (([a-zA-Z._]*:0x[a-z0-9]*\|)*)\n")
    stack_re = re.compile(r"(([a-zA-Z._]*):(0x[a-z0-9]*)\|)")

    def __init__(self, log_string):
        self.timestamp = None
        self.stack = None

        fsi = DropStack.full_re.findall(log_string)
        if fsi:
            si = DropStack.stack_re.findall(fsi[0][2])
            if si:
                self.timestamp = datetime.datetime.strptime(fsi[0][0], "%Y/%m/%d %H:%M:%S:%f")
                self.stack = [(item[1], item[2]) for item in si]


def symbolicate(binary_images, stacks, dsym):
    for imageId, imageTuple in enumerate(binary_images.images):
        path = imageTuple[0]
        load_address = imageTuple[1]
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
            p = subprocess.Popen("atos -o %s -l %s" % (dsym, load_address), shell=True, stdout=subprocess.PIPE, stdin=subprocess.PIPE)
        else:
            full_path = "~/Library/Developer/Xcode/iOS DeviceSupport/%s/Symbols%s" % (binary_images.osVersion, path)
            p = subprocess.Popen("atos -arch arm64 -o \"%s\" -l %s" % (full_path, load_address), shell=True, stdout=subprocess.PIPE, stdin=subprocess.PIPE)

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
            updated_stack = [(module, address) if (module != image or address not in mapping) else (module, mapping[address]) for (module, address) in stack.stack]
            stack.stack = updated_stack


def serialize_timeline(stacks, dest, title):
    timeline = {"title": {
                     "text": {"headline": title},
                     "media": {
                        "url": "",
                        "caption": "",
                        "credit": ""}}}
    events = []
    for stack in stacks:
        table = "<table class=stacktrace>"
        for (module, call) in stack.stack:
            table += "<tr><td>" + module + "</td><td>" + call + "</td></tr>"
        table += "/<table>"

        events.append({
            "start_date": {
                "year": stack.timestamp.year,
                "month": stack.timestamp.month,
                "day": stack.timestamp.day,
                "hour": stack.timestamp.hour,
                "minute": stack.timestamp.minute,
                "second": stack.timestamp.second,
                "millisecond": stack.timestamp.microsecond / 1000},
            "media": {
                "url": "",
                "caption": "",
                "credit": ""},
            "text": {
                "headline": stack.timestamp.strftime("%H:%M:%S.%f"),
                "text": table
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

    result = open(dest, "w")
    result.write(html_str)
    result.close()


def main():
    parser = argparse.ArgumentParser(description='Parse logs and build dropped frame stacks statistics.')
    parser.add_argument('--dsym', dest='dsym', required=True, help='a path to .DSYM file')
    parser.add_argument('--log', dest='log', required=True, help='a path to the log file that contains dropped stacks info')
    parser.add_argument('--timeline', dest='timeline', required=False, help='a path to destination timeline serialization')

    args = parser.parse_args()

    current_binary_images = None
    stacks_dict = {}

    with open(args.log) as f:
        for line in f:
            binary_images = BinaryImages(line)
            if binary_images.osVersion:
                current_binary_images = binary_images
                stacks_dict[current_binary_images] = []
                continue

            if current_binary_images:
                if current_binary_images.parse(line):
                    continue
            else:
                continue

            stack = DropStack(line)
            if stack.stack:
                stacks_dict[current_binary_images].append(stack)
                continue

    stacks = []

    for binary_images in stacks_dict:
        symbolicate(binary_images, stacks_dict[binary_images], args.dsym)
        stacks += stacks_dict[binary_images]

    if args.timeline:
        head, tail = os.path.split(args.log)
        serialize_timeline(stacks, args.timeline, "%s serialization" % tail)


if __name__ == "__main__":
    main()
