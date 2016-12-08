#!/bin/bash
#
# FILE                      : system-info.sh
# VERSION                   : 0.7
# DESC                      : Linux system email reporter in BASH
# DATE                      : 2009
# AUTHOR                    : LALA -> lala (at) linuxor (dot) sk
#

#
# Instalacia:
# -----------
# # mkdir /tools
# # cp /tmp/SYSTEM_TOOLS.tar /tools
# # tar -xf /tools/SYSTEM_TOOLS.tar
# # rm /tools/SYSTEM_TOOLS.tar
# #
# Pouzitie:
# ---------
# 1) 
# Pre uzivatela root naimportujeme verejny(e) kluc(e) osoby ktorej chceme posielat report (ak ENCRYPT=1)
# # gpg --import public.asc 
# # gpg --edit-key mail@domena.sk ( gpg> trust ) 
#
# 2)
# Editujeme tento skript (nizsie) a do premennej REPORT_TO pridame emailove adresy na ktore budu odosielane reporty.
# REPORT_TO="adresa@localhost
# email2@domena.sk
# email3@domena.sk"
#
# 3)
# Nastavime Uzivatelske nastavenia/User settings
#
# 4)
# Zapneme moduly ktorych kontroly chceme mat v reporte.
#
# Zapnutie modulu
# ---------------
# # /tools/system-info.sh -a [presny_nazov_modulu_ALEBO_cislo_modulu]
# Pr: /tools/system-info.sh -a 18
#
# 5) 
# Nainicializujeme datove subory (inicializaciu vykonavame ak: 
# 1> sa zmeni nejaky subor, ktory je chraneny if (CHECK_FILES_INTEGRITY==1)
# 2> sa zmeni smerovacia tabulka if(CHECK_ROUTE_TABLE_DIFF==1)
# 3> sa zmenia pravidla firewallu if(CHECK_IPTABLES_DIFF==1)
# 4> sa zmeni zoznam nacitanych modulov if(CHECK_LOADED_KERNEL_MODULES_DIFF==1)
#
# Inicializiacia
# --------------
# # /tools/system-info.sh -i
#
# 6)
# Nastavime, aby sa skript spustal cez crontab kazdy den o 8:00 v kontrolnom rezime ( -c ).
# # crontab -e
# 0 8 * * * cd /tools; ./system_info.sh -c
#
# 6)
# alebo
# 
# # touch /etc/cron.d/system_info
# # echo -e "0 8 * * *\troot\tcd /tools;./system_info.sh -c" >> /etc/cron.d/system_info
# # /etc/init.d/cron reload
#
# 7) 
# Pravidelne citame report ;-)
#
################# Uzivatelske nastavenia/User settings
################# Uzivatelske nastavenia/User settings
################# Uzivatelske nastavenia/User settings
################# Uzivatelske nastavenia/User settings


# Install dir
INSTALL_DIR=/tools/

# Stroj z ktoreho robime report
# Host from which we do report
HOST=brana.domena.sk

# distro (debian | redhat)
DISTRO=redhat

# jazyk / language ( sk | en )
LANG=en

# kryptovat(1) alebo nekryptovat(0) ?  to je otazka :-)
# encrypt(1) or no encrypt(0)
ENCRYPT=0

# emailove adresy na ktore sa bude zasielat report
# email adresses to send report
REPORT_TO="root@localhost"

# archivovat (1) alebo nearchivovat(0) report po odoslani?
# archive(1) or no archive(0) report after send
ARCHIVE_REPORT=1


################# Koniec uzivatelskych nastaveni/End of user settings
################# Koniec uzivatelskych nastaveni/End of user settings
################# Koniec uzivatelskych nastaveni/End of user settings
################# Koniec uzivatelskych nastaveni/End of user settings


################# Nastavenie skriptu (nie pre uzivatela)/Script settings (not for user)
VERSION=0.7
AUTHOR="LALA -> lala (at) linuxor (dot) sk"
WORKDIR=$INSTALL_DIR/system_info/workdir
MODULES_AVAILABLE=$INSTALL_DIR/system_info/modules_available
MODULES_ACTIVE=$INSTALL_DIR/system_info/modules_active
OUTPUT=$WORKDIR/report.txt	# subor do ktoreho sa ukladaju informacie
REPORTS_DIR=$INSTALL_DIR/system_info/outputs/reports
BACKUP_DIR=$INSTALL_DIR/system_info/outputs/backups
BACKUP_DIR_TMP=$BACKUP_DIR/tmp
HASH_FILES_DIR=$WORKDIR/hash_files
LOAD_WARN=5.0			# ukaze varovanie ak priemerne vytazenie servera za poslednych 5 minut je nad limitom 


################# INCLUDES
. $INSTALL_DIR/includes/variables
. $INSTALL_DIR/includes/functions


################# LANGUAGES
case $LANG in
sk)	
. $INSTALL_DIR/system_info/lang/sk
;;
en)
. $INSTALL_DIR/system_info/lang/en
;;
*)
. $INSTALL_DIR/system_info/lang/en
;;
esac


################# DISTRIBUTION
case $DISTRO in
debian)	
. $INSTALL_DIR/includes/debian/commands
;;
redhat)	
. $INSTALL_DIR/includes/redhat/commands
;;
*)
. $INSTALL_DIR/includes/debian/commands
;;
esac


################# MAIN
if [ $# -eq "$NO_ARGS" ]
    then
    setcolor $green
    $PRINT "$MSG_USAGE_USAGE: `basename $0` [options]"
    $PRINT "       $MSG_USAGE_ARG_INIT"
    $PRINT "       $MSG_USAGE_ARG_CHECK"
    $PRINT "       $MSG_USAGE_ARG_LIST_MODULES"
    $PRINT "       $MSG_USAGE_ARG_ADD_MODULE"
    $PRINT "       $MSG_USAGE_ARG_DEL_MODULE"
    $RESET
    exit $E_OPTERROR
fi

while getopts ":icla:d:" Option
do
    case $Option in

################# CHECK (-c)
    c)

    if [[ ! -f "$CAT" || ! -f "$FIND" || ! -f "$SORT" ]]
	then
	$PRINT "$MSG_MISSING_COMMAND $CAT, $FIND, $SORT"
	$PRINT "$MSG_NEED_PACKAGE $CAT_package, $FIND_package, $SORT_package"
	exit $E_OPTERROR

	else
	# zmazeme povodny obsah suboru report.txt
	$CAT /dev/null > $OUTPUT 


	######## LOAD ACTIVE MODULES
	for module in `$FIND $MODULES_ACTIVE -type l | $SORT -n`
	do
	    . $module check
	done
    fi


    if [ ! -f "$MAIL" ]
	then
	$PRINT "$MSG_MISSING_COMMAND $MAIL"
	$PRINT "$MSG_NEED_PACKAGE $MAIL_package"
	exit $E_OPTERROR

	else
        ######## SEND REPORT
	for report_to in $REPORT_TO
	do
	    if [ "$ENCRYPT" -eq "1" ]		# ak kryptujeme
		then
		if [ ! -f "$GPG" ]
		    then
		    $PRINT "$MSG_MISSING_COMMAND $GPG"
		    $PRINT "$MSG_NEED_PACKAGE $GPG_package"
		    exit $E_OPTERROR
	
		    else
		    $GPG --no-verbose --output $OUTPUT.pgp --encrypt --textmode --armor --recipient $report_to $OUTPUT
		    $MAIL -s "SYSTEM INFO: $HOST" $report_to <$OUTPUT.pgp
		    $RM $OUTPUT.pgp
		fi
		
		else
		$MAIL -s "SYSTEM INFO: $HOST" $report_to <$OUTPUT
	    fi
	done
    fi


    ######## ARCHIVING REPORTs
    if [ "$ARCHIVE_REPORT" -eq "1" ]
	then
	if [ ! -f "$CP" ]
	    then
	    $PRINT "$MSG_MISSING_COMMAND $CP"
	    $PRINT "$MSG_NEED_PACKAGE $CP_package"
	    exit $E_OPTERROR

	    else
	    REPORT_NAME="report-"
	    REPORT_NAME+=`$DATE +'%F'`

	    $CP $OUTPUT $REPORTS_DIR/$REPORT_NAME
	fi
    fi
    ;;


################# INITIALIZATION (-i)
    i)

    if [[ ! -f "$FIND" || ! -f "$SORT" ]]
	then
	$PRINT "$MSG_MISSING_COMMAND $FIND, $SORT"
	$PRINT "$MSG_NEED_PACKAGE $FIND_package, $SORT_package"
	exit $E_OPTERROR

	else
	for module in `$FIND $MODULES_ACTIVE -type l | $SORT -n`
	do
	    . $module init
	done
    fi
    ;;


################# LIST OF MODULES (-l)
    l)

    if [[ ! -f "$FIND" || ! -f "$SORT" || ! -f "$BASENAME" ]]
	then
	$PRINT "$MSG_MISSING_COMMAND $FIND, $SORT, $BASENAME"
	$PRINT "$MSG_NEED_PACKAGE $FIND_package, $SORT_package, $BASENAME_package"
	exit $E_OPTERROR

	else
	for module in `$FIND $MODULES_AVAILABLE -type f | $SORT -n`
	do
	    current_module=`$BASENAME $module`
	    if [ -f $MODULES_ACTIVE/$current_module ]
		then
		current_module+=" (Active)"
	    fi
	    $PRINT $current_module
	done
    fi
    ;;


################# ACTIVATE MODULE (-a)
    a)

    MODULE_NAME=`$LS $MODULES_AVAILABLE | $GREP ^$2`

    if [ -f "$MODULES_ACTIVE/$MODULE_NAME" ]
        then
        $PRINTE $MSG_USAGE_MODULE_ACTIVE

        else
        if [ -f "$MODULES_AVAILABLE/$MODULE_NAME" ]
    	    then 
	    $LN -s $MODULES_AVAILABLE/$MODULE_NAME $MODULES_ACTIVE/$MODULE_NAME
    	    $PRINTE $MODULE_NAME - $MSG_USAGE_MODULE_STARTED
	    
	    else
	    $PRINTE $MSG_USAGE_MODULE_NOEXIST
	fi
    fi
    ;;


################# DISABLE MODULE (-d)
    d)

    MODULE_NAME=`$LS $MODULES_AVAILABLE | $GREP ^$2`

    if [ ! -f "$MODULES_ACTIVE/$MODULE_NAME" ]
        then
	if [ ! -f "$MODULES_AVAILABLE/$MODULE_NAME" ]
	    then
	    $PRINTE $MSG_USAGE_MODULE_NOEXIST
    	    
	    else
	    $PRINTE $MODULE_NAME - $MSG_USAGE_MODULE_INACTIVE
	fi
	
        else
        if [ -f "$MODULES_AVAILABLE/$MODULE_NAME" ]
    	    then 
	    $RM $MODULES_ACTIVE/$MODULE_NAME
    	    $PRINTE $MODULE_NAME - $MSG_USAGE_MODULE_DISABLED
	    
	    else
	    $PRINTE $MSG_USAGE_MODULE_NOEXIST
	fi
    fi
    ;;


################# DEFAULT
    *)
    setcolor $red
    $PRINT "$MSG_NOT_IMPLEMENTED"
    setcolor $green
    $PRINT "$MSG_USAGE_USAGE: `basename $0` [-i] [-c] [-l] [-a module] [-d module]"
    $PRINT "       $MSG_USAGE_ARG_INIT"
    $PRINT "       $MSG_USAGE_ARG_CHECK"
    $PRINT "       $MSG_USAGE_ARG_LIST_MODULES"
    $PRINT "       $MSG_USAGE_ARG_ADD_MODULE"
    $PRINT "       $MSG_USAGE_ARG_DEL_MODULE"
    $RESET
    exit $E_OPTERROR
    ;;
esac
done


# Dekrementujeme smernik argumentu, takze ukazuje na nasledujuci parameter.
# $1 teraz referuje na prvu polozku (nie volbu) poskytnutu na prikazovom riadku.
shift $(($OPTIND - 1))

# Uspesny koniec
exit 0
