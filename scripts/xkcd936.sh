#!/usr/bin/env bash
#=============================================================================
# generate a random password per xkcd.com/936/
# save this in ~/bin as either 'xkcd936' or 'password'
# https://gist.github.com/bdobyns/9ae0c8741b4947cbba41df9c8ff422f9
#
# examples:
#     password
#     password 3
#     password german 3                (assumes you have /usr/dict/share/german)
#
function password
{
    DEFAULTPASSWORDCOUNT=3  # used later, but here at the top so it's easy to find and change

    echo "also see xkcd.com/936/"
    echo " "

    DICT=/usr/share/dict
    # allow us to use $DICT/german or whatever
    if [ -f $DICT/$1 ] ; then
    WORDS=$DICT/$1
    shift
    else
    for W in words web2 pass-words 1000 10000 20000 ; do
#   ( cd $DICT ; ls ) | grep -v ascii | grep -v 'sh$' | randline | head -1 | while read W
#   do
        if [ -f $DICT/$W ] ; then
        WORDS=$DICT/$W
        break
        fi
    done
    fi


    # do five candidate passwords
    for i in a b c d e f
    do
    # pick the style of dash, randomly
    COINFLIP=$[ $RANDOM % 2 ]
    if [ $COINFLIP -eq 0 ] ; then DASH='-'
    else DASH='_'; fi

        # only if the the wordlist exists
    if [ -f $WORDS ] ; then
        # we have to reset the word count each time thru
        # since we decrement it at as we generate each row
        if [ -z "$1" ] ; then
        COUNT=$DEFAULTPASSWORDCOUNT
        else
        COUNT=$1
        fi

            # do one candidate password
        # but vary where the numbers might appear
        case $i in # $[ $RANDOM % 5 ] in
        a) # no numbers at all
            while [ $COUNT -gt 0 ]
            do
            WERD=$( randomline $WORDS )
            COINFLIP=$[ $RANDOM % 2 ]
            if [ $COINFLIP -eq 0 ] ; then echo -n $( pascal $WERD )
            else echo -n $WERD ; fi
            COUNT=$[ $COUNT - 1 ]
            if [ $COUNT -gt 0 ] ; then echo -n ${DASH} ; fi
            done
            ;;
        b) # numbers at the end
            while [ $COUNT -gt 0 ]
            do
            WERD=$( randomline $WORDS )
            COINFLIP=$[ $RANDOM % 2 ]
            if [ $COINFLIP -eq 0 ] ; then echo -n $( pascal $WERD )
            else echo -n $WERD ; fi
            COUNT=$[ $COUNT - 1 ]
            if [ $COUNT -gt 0 ] ; then echo -n ${DASH} ; fi
            done
            echo -n ${DASH}$RANDOM
            ;;
        c) # numbers at the start
            echo -n $RANDOM${DASH}
            while [ $COUNT -gt 0 ]
            do
            WERD=$( randomline $WORDS )
            COINFLIP=$[ $RANDOM % 2 ]
                if [ $COINFLIP -eq 1 ] ; then echo -n $( pascal $WERD )
            else echo -n $WERD ; fi
#           echo -n `randomline $WORDS`
            COUNT=$[ $COUNT - 1 ]
            if [ $COUNT -gt 0 ] ; then echo -n ${DASH} ; fi
            done
            ;;
        d) # numbers instead of dashes
            while [ $COUNT -gt 0 ]
            do
            WERD=$( randomline $WORDS )
            COINFLIP=$[ $RANDOM % 2 ]
            if [ $COINFLIP -eq 1 ] ; then echo -n $( pascal $WERD )
            else echo -n $WERD ; fi
            DIGITS=$[ $RANDOM % 100 ]
            COUNT=$[ $COUNT - 1 ]
            if [ $COUNT -gt 0 ] ; then echo -n $DIGITS ; fi
            done
            ;;
        e) # numbers AND dashes, all lowercase
            while [ $COUNT -gt 0 ]
            do
            WERD=$( randomline $WORDS )
            COINFLIP=$[ $RANDOM % 2 ]
#           if [ $COINFLIP -eq 1 ] ; then echo -n $( pascal $WERD )
#           else
            echo -n $WERD # ; fi
            DIGITS=$[ $RANDOM % 100 ]
            COUNT=$[ $COUNT - 1 ]
            if [ $COUNT -gt 0 ] ; then echo -n ${DASH}$DIGITS${DASH} ; fi
            done
            ;;
        *) # numbers in the middle
            while [ $COUNT -gt 0 ]
            do
            WERD=$( randomline $WORDS )
            COINFLIP=$[ $RANDOM % 2 ]
            if [ $COINFLIP -eq 1 ] ; then echo -n $( pascal $WERD )
            else echo -n $WERD ; fi
#           echo -n `randomline $WORDS`
            COUNT=$[ $COUNT - 1 ]
            if [ $COUNT -gt 0 ] ; then echo -n ${DASH} ; fi
            if [ $COUNT -eq 1 ] ; then echo -n $RANDOM${DASH} ; fi
            done
            ;;
        esac
        echo ''
    fi
    done
    echo ' '
} # end of password
#=============================================================================

# helper functions for password generator
function __cleanwords
{
    if [ -z $1 ] ; then return ; fi
    if [ ! -f /tmp/$(basename $1).ascii ] ; then
    cat $1 | sed -e '/^$/d' -e '/^.$/d' -e '/^..$/d' -e '/^...$/d' -e '/^....$/d' 2>/dev/null | grep -v '[^0-9A-Za-z]'  >/tmp/$(basename $1).ascii
    fi
    cat /tmp/$(basename $1).ascii
}

function randomline
{
    if [ -z $1 ] ; then return ; fi
    if [ ! -z `which randline` ] ; then
    __cleanwords $1 |  randline -
    elif [ ! -z `which shuf` ] ; then
    __cleanwords $1 | shuf | head -1
    elif [ -f $1 ] ; then
    __cleanwords $1 | head -$((${RANDOM} % `wc -l < $1` + 1)) $1 | tail -1
    fi
}

#----------------------------------------------------------------------
# these do camel case etc
#   This is upper PascalCase: SomeSymbol
#   This is lower camelCase: someSymbol
#   This is snake_case: some_symbol
#   This is kebab_case: some-symbol
function caseup
{
    echo $* | tr 'A-Z' 'a-z' | tr -c -s 'a-zA-Z0-9' '_' | sed -e 's/_\([a-z]\)/_\u\1/g' -e 's/^_//' -e 's/_$//'
}

function snake # likeThis
{
    caseup $*
    echo ''
}

function kebab #
{
    caseup $* | sed -e 's/_/-/g'
}

function pascal # "Like_This"
{
    caseup _$* | sed -e 's/_//g'
}

function camel # "Like-This"
{
    caseup $* | sed -e 's/_//g'
}

#----------------------------------------------------------------------

if [ -z "$1" ] ; then
    echo "usage:  "$(basename $0)" [count] "
else
    password $*
fi
# end of password

