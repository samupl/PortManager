#!/usr/bin/env bash
#
# Copyright (c) 2011 Jakub Szafrański <samu@pirc.pl>
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

# PortManager
#
# syntax and help availble after invoking `pm -h`.

pm_version=0.1.2
basepath="/usr/ports"

usage() {
    echo -e "usage: pm [-hv]\n"\
            "      pm [-cdfp] install port\n"\
            "      pm [-c] deinstall port\n"\
            "      pm [-l] rmunused\n"\
            "      pm [-n|-k] search phrase\n"\
            "      pm update mirror\n"
}

pm_version() {
	echo -e "PM: PortManager v $pm_version\bAuthor: Jakub 'samu' Szafrański <samu@pirc.pl>\n"
}

pm_search4port() {
    port=""
    for p in `/usr/bin/whereis $1`; do
        p=`echo ${p} |grep "${basepath}"`
        if [ ! -z "$p" ]; then
            cd $p
            return
        fi
    done
    
    if [ ! -d "${basepath}/${1}" ]; then
        echo "$1: The requested port does not exist!"
		exit 2
	fi
    cd "$basepath"
    cd "$1"
}

pm_help() {
	echo -e \
			"\nThe following commands are available:\n\n"\
			"    install    Build and install the specified port.\n\n"\
			"    deinstall  Remove the installed port.\n\n"\
			"    rmunused   Remove all unused ports - mostly left dependencies.\n"\
			"    search     Search the ports database for a phrase specified.\n"\
            "    update     Update the ports tree from the mirror specified."
	echo -e \
			"\nPM accepts following switches as it's first argument:\n\n"\
            "    -c      Clean the workdir after the compilation (or deinstallation) is\n"\
            "            done. One would use this option to prevent unnesesary disk space\n"\
            "            usage, but if you would like to recompile the port later, don't\n"\
            "            use this switch, and the compilation process would be noticeable\n"\
            "            faster.\n\n"\
            "    -d      Do not check portaudits database for known vulnerabilities. By\n"\
            "            default, FreeBSD will deny the installation of a port which has\n"\
            "            known vulnerabilities.\n\n"\
            "    -f      When installing a new port, force it's package registration. This\n"\
            "            allows you to overwrite the port if it is already installed.\n\n"\
	        "    -h      Displays this help document.\n\n"\
            "    -k      During the search process, the 'key' keyword will be used.\n\n"\
            "    -l      When using rmunused, do not actually remove unused dependencies,\n"\
            "            but list them.\n\n"\
            "    -n      During the search process, the 'name' keyword will be used.\n\n"\
            "    -p      Preconf, can be used only in INSTALL option. Before the\n"\
            "            compilation process will start, PM will invoke\n"\
            "            'make config' on all dependencies, which will be required\n"\
            "            by the port you are about to install. This can be a time saver,\n"\
            "            when the compilation process can take a long time (countable in\n"\
            "            hours) - you can configure all ports and go for a coffee.\n\n"\
            "    -v      Prints version and author information.\n\n"
            
            # exit status
    echo -e \
			"\nPM will exit, returning one of the follow values:\n\n"\
			"     0      Everything went fine.\n"\
			"     1      Incorrect syntax, or missing argument.\n"\
			"     2      The requested port does not exist.\n"
}

if [[ -z "$1" ]]; then
    usage
    exit 1
fi

while getopts 'hfdvpcnkl' COMMAND_LINE_ARGUMENT ; do
    case "${COMMAND_LINE_ARGUMENT}" in
    h)  usage ; pm_help; exit 0 ;;
    v)  pm_ver=1 ;;
    p)  pm_preconf=1 ;;
    c)  pm_clean=1 ;;
    d)  pm_disablevulns=1 ;;
    f)  pm_forceregister=1 ;;
    n)  pm_s_name=1 ;;
    k)  pm_s_key=1 ;;
    l)  pm_justlist=1 ;;
    v)  pm_version ; exit 0 ;;
    *)  usage ; exit 1 ;;
    esac
done
shift $(( $OPTIND - 1 ))

case "$1" in
	install)
		if [ -z "$2" ]; then
			usage ; exit 1
		fi
        pm_search4port $2
		if [ "$pm_preconf" == 1 ]; then
            /usr/bin/make config-recursive
        else
            /usr/bin/make config
		fi
        
        if [ "$pm_forceregister" == 1 ]; then
            export FORCE_PKG_REGISTER=1;
        fi
        if [ "$pm_disablevulns" == 1 ]; then
            export DISABLE_VULNERABILITIES=1;
        fi
        
		/usr/bin/make install
		if [ "$pm_clean" = 1 ]; then
			/usr/bin/make clean
		fi;
		;;
		
        
	deinstall)
		if [ "$2" == "" ]; then
			usage ; exit 1
		fi
		pm_search4port $2
		/usr/bin/make deinstall
		if [ "$pm_clean" = 1 ]; then
			/usr/bin/make clean
		fi;
		;;
		
        
	rmunused)
        if [ "$pm_justlist" != 1 ];	then
            echo "Removing unused ports is not yet implemented.";
            exit 0;
        fi
        		
		find -s /var/db/pkg/ -type d -mindepth 1 | while read i; do
			if [ ! -s "$i/+REQUIRED_BY" ]; then 
				if [ "$i" != "" ]; then
					if [ "$pm_justlist" == 1 ]; then
						basename $i
					fi
				fi
			fi
		done
		;;
		
      
    update)
        if [ -z "$2" ]; then
            echo "update: You must specify a mirror, ex. pm update cvsup.pl.freebsd.org"
            exit 2
        fi
        /usr/local/bin/cvsup -g -P m -h $2 /usr/share/examples/cvsup/ports-supfile
        ;;
        
	search)
		if [ -z "$2" ]; then
			usage ; exit 1
		fi
		if [[ "$pm_s_name" != 1 && "$pm_s_key" != 1 ]]; then
			usage ; exit 1
		fi
		makecmd="/usr/bin/make search"
		if [ "$pm_s_name" == 1 ]; then
			makecmd="$makecmd name=\"$2\""
		fi
		if [ "$pm_s_key" == 1 ]; then
			makecmd="$makecmd key=\"$2\""
		fi
		cd $basepath
		eval $makecmd |egrep "Port|Path|Info" |sed -e "s/\(Info:.*\)/\1\\
		 /"
		;;
		
        
	*) usage ; exit 1 ;;
esac
