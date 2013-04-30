#!/bin/sh

# git-versioning.sh

info()
{
cat << EOF
To start versioning on git you need to do this:
    1. git tag -a -m "init" 1.0
    2. git push --tags
    3. this script will do everything else :-)

Examples:
    short version - 2.1.9
    long version - 2.1.9-abee12c-new_cool_feature

Major and minor will be taken from tag, patch = commits count from tag point
EOF
}

usage()
{
cat << EOF
usage: $0 options
OPTIONS:
    -i info
    -s short version (major.minor.patch)
    -l long version (major.minor.patch-sha1-branch)
    -p package version (short or long version depends on RC branch)
    -b branch name
EOF
}

current_tag()
{
    CURRENT_TAG=$(git describe --tags --always)
    if [[ ! "$CURRENT_TAG" =~ "-" ]]; then
        CURRENT_TAG=${CURRENT_TAG}-0-000000
    fi
    echo ${CURRENT_TAG}
}

current_version()
{
    echo $(current_tag | cut -d'-' -f 1,2 | sed 's/-/\./g')
}

current_sha1()
{
    echo $(current_tag | cut -d'-' -f 3,3)
}

current_branch()
{
    echo $(git for-each-ref --format='%(objectname) %(refname:short)' refs | grep `git rev-parse HEAD`) | cut -d' ' -f 2
}

short_version()
{
    echo $(current_version)
}

long_version()
{
    echo $(current_version)-$(current_sha1)-$(current_branch)
}

package_version()
{
    if [[ $(current_branch) == rc-* ]]; then
        short_version
    else
        long_version
    fi
}

if [[ $# -eq 0 ]]; then
    usage
    exit
fi

while getopts "slpbih?" OPTION
do
    case $OPTION in
    i)
        info
        exit
        ;;
    s)
        short_version
        exit
        ;;
    l)
        long_version
        exit
        ;;
    p)
        package_version
        exit
        ;;
    b)
        current_branch
        exit
        ;;
    *)
        usage
        exit
        ;;
    esac
done
