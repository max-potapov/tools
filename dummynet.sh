#!/bin/sh

# network link conditioner
# tested on MacOSX 10.8 & FreeeBSD 9.1

IIF="re1"

UP_BW="1000000"
UP_DELAY="0"
UP_PACKETLOSS="0.0"

DOWN_BW="1000000"
DOWN_DELAY="0"
DOWN_PACKETLOSS="0.0"

usage()
{
    cat << EOF
    usage: $0 options
    OPTIONS:
        -b bandwith (kbps)
        -d delay (ms)
        -l packet loss (%, 0.0-1.0)
        -n profile number
        -i profile list
EOF
}

fail()
{
    echo 'exec failed!'
    exit 1
}

flush()
{
    sudo ipfw -q delete 45678
    sudo ipfw -q delete 45679
    sudo ipfw -f pipe flush || fail
}

info()
{
    echo '(1) 3G, Good      (↓ 850kbps, 100ms, 0.00 / ↑ 420kbps, 100ms, 0.00)'
    echo '(2) 3G, Average   (↓ 780kbps, 100ms, 0.00 / ↑ 330kbps, 100ms, 0.00)'
    echo '(3) 3G, Lossy     (↓ 780kbps, 100ms, 0.01 / ↑ 330kbps, 100ms, 0.00)'
    echo '(4) Edge, Good    (↓ 250kbps, 350ms, 0.00 / ↑ 200kbps, 370ms, 0.00)'
    echo '(5) Edge, Average (↓ 240kbps, 400ms, 0.00 / ↑ 200kbps, 440ms, 0.00)'
    echo '(6) Edge, Lossy   (↓ 240kbps, 400ms, 0.01 / ↑ 200kbps, 440ms, 0.00)'
}

select_profile()
{
    case $1 in
    1)
        DOWN_BW="850"
        DOWN_DELAY="100"
        DOWN_PAKETLOSS="0.0"
        UP_BW="420"
        UP_DELAY="100"
        UP_PAKETLOSS="0.0"
        ;;
    2)
        DOWN_BW="780"
        DOWN_DELAY="100"
        DOWN_PAKETLOSS="0.0"
        UP_BW="330"
        UP_DELAY="100"
        UP_PAKETLOSS="0.0"
        ;;
    3)
        DOWN_BW="780"
        DOWN_DELAY="100"
        DOWN_PAKETLOSS="0.01"
        UP_BW="330"
        UP_DELAY="100"
        UP_PAKETLOSS="0.0"
        ;;
    4)
        DOWN_BW="250"
        DOWN_DELAY="350"
        DOWN_PAKETLOSS="0.0"
        UP_BW="200"
        UP_DELAY="370"
        UP_PAKETLOSS="0.0"
        ;;
    5)
        DOWN_BW="240"
        DOWN_DELAY="400"
        DOWN_PAKETLOSS="0.0"
        UP_BW="200"
        UP_DELAY="440"
        UP_PAKETLOSS="0.0"
        ;;
    6)
        DOWN_BW="240"
        DOWN_DELAY="400"
        DOWN_PAKETLOSS="0.01"
        UP_BW="200"
        UP_DELAY="440"
        UP_PAKETLOSS="0.0"
        ;;
    *)
        echo 'error: unknown profile'
        exit 1
        ;;
    esac
}

configure()
{
    sudo ipfw pipe 1 config bw ${DOWN_BW}Kbit/s delay ${DOWN_DELAY}ms plr ${DOWN_PAKETLOSS} || fail
    sudo ipfw pipe 2 config bw ${UP_BW}Kbit/s delay ${UP_DELAY}ms plr ${UP_PAKETLOSS} || fail
    sudo ipfw -q add 45678 pipe 1 ip from any to any in via $IIF || fail
    sudo ipfw -q add 45679 pipe 2 ip from any to any out via $IIF || fail
}

if [ $# -eq 0 ]; then
    usage
    exit
fi

while getopts "b:d:l:n:ih?" OPTION
do
    case $OPTION in
    b)
        UP_BW="$OPTARG"
        DOWN_BW="$OPTARG"
        ;;
    d)
        UP_DELAY="$OPTARG"
        DOWN_DELAY="$OPTARG"
        ;;
    l)
        UP_PAKETLOSS="$OPTARG"
        DOWN_PAKETLOSS="$OPTARG"
        ;;
    n)
        select_profile "$OPTARG"
        ;;
    i)
        info
        exit
        ;;
    *)
        usage
        exit
        ;;
    esac
done

flush
configure
echo 'done.'
