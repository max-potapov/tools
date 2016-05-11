#!/usr/bin/python

import argparse
import re
import operator

class LocalizationString:
    keyval_re = re.compile(r"\"(.*)\"[ ]*=[ ]*\"(.*)\";\n")

    def __init__(self):
        self.comments = []
        self.key = ""
        self.value = ""

    def parse(self, line):
        keyval = LocalizationString.keyval_re.findall(line)
        if keyval:
            self.key = keyval[0][0]
            self.value = keyval[0][1]
            return True
        else:
            self.comments.append(line);
            return False;

def validate(strings):
    keys = [string.key for string in strings]
    duplicate_keys = set([x for x in keys if keys.count(x) > 1])
    if duplicate_keys:
        print "ERROR: Following keys are not unique:"
        for i in duplicate_keys:
            print "\t%s" % i

    vals = [string.value for string in strings]
    duplicate_vals = set([x for x in vals if vals.count(x) > 1])
    if duplicate_vals:
        print "WARNING: Following values are not unique:"
        for i in duplicate_vals:
            print "\t%s" % i

def main():
    parser = argparse.ArgumentParser(description='Parse sort strings in localizable file.')
    parser.add_argument('--input', dest='input', required=True, help='a path to input localizable file.')
    parser.add_argument('--output', dest='output', required=True, help='a path to output localizable file.')

    args = parser.parse_args()

    header = True
    result = []
    strings = []

    current_localized_string = LocalizationString()

    with open(args.input) as f:
        for line in f:
            if header:
                result.append(line)
            else:
                if current_localized_string.parse(line):
                    strings.append(current_localized_string)
                    current_localized_string = LocalizationString()

            if line == "/* ================= Application Strings ================= */\n":
                header = False

    strings.sort(key=operator.attrgetter('key'))

    validate(strings)

    for string in strings:
        result.extend(string.comments)
        result.append("\"%s\" = \"%s\";\n" % (string.key, string.value))

    output = open(args.output, "w")
    for item in result:
        output.write(item)
    output.close()

if __name__ == "__main__":
    main()
