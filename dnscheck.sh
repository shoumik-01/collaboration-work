#!/usr/bin/ksh
#
#       Name:           dnscheck.sh
#
#       Purpose:        To Check DNS Service Availabilty
#
#       Modification History:
#
#       Date            Modified By             Change Description
#
#       Nov 24 2018     Steve Taylor            Create Initial Script
#       Nov 24 2018     Steve Taylor            Added EMAIL On ALERT
#       Dec  3 2018     Steve Taylor            Added EMAIL / syslog option
#       May 30 2019     Shoumik Hasan           Fixed the color codings for the output
###########################################################################################################################
#
# To Customize Change :
#
# DNS_QUERY_TIME_WARN_MSEC     = IF RESPONSE > THIS VALUE WARNING MESSAGE
#
################################################################################


DNS_QUERY_TIME_WARN_MSEC=100
DNS_CONFIG_FILE=/home/staylor/dnscheck/dnscheck.cfg
DIG_TOOL=/usr/bin/dig
set -A EXT_DNS_SERVER 8.8.8.8
set -A INT_DNS_SERVER x.x.x.x
TMPDIR=/tmp
AWK=/usr/bin/awk
RM=/usr/bin/rm
SED=/usr/bin/sed
MAIL_OPS="TRUE"
OPS_EMAIL_ADDRESS="staylor@domain.com"
CREATE_SYSLOG_EVENT="TRUE"
LAAL=$'\e[1;31m'
NIIL=$'\e[1;34m'
HOLUD=$'\e[1;33m'
SHOBUJ=$'\e[1;32m'
SHESH=$'\e[0m'

#************************  Start of Test Specific Code *****************************


TEST="DNSCHECK"
MACHINE=`uname -n | $AWK -F. '{print $1}'`

DIG_TEMPOUTFILE=$TMPDIR/DIGTEMPOUTFILE.$$
DNS_CONFIG_FILE_LIST=$TMPDIR/DNS_CONFIG_FILE_LIST.$$

cat -s $DNS_CONFIG_FILE | grep -v "^#" | tr '|' '\t'  > $DNS_CONFIG_FILE_LIST

printf "\nSTATUS  \t: %18s : %50s : %50s : %s \n" "APPLICATION" "DNS ENTRY" "EXPECTED IP" "DNS SERVER"  >> $TMPDIR/${TEST}.green.$$
printf "======  \t: %18s : %50s : %50s : %s \n\n" "===========" "=========" "===========" "=========="  >> $TMPDIR/${TEST}.green.$$

while read -r APPKEY ENDPOINT_TYPE DNS_VALUE EXPECTED_IP DNS_CHECK_TYPE PERFORM_DNS_CHECK
do

        if [[ "${ENDPOINT_TYPE}" = "EXT" ]] then
          DNS_SERVER_DESC="EXTERNAL"
        else
          DNS_SERVER_DESC="INTERNAL"
        fi


        if [[ "${PERFORM_DNS_CHECK}" = "Y" ]]; then

          if [[ "${ENDPOINT_TYPE}" = "EXT" ]] then
            $DIG_TOOL @${EXT_DNS_SERVER} ${DNS_VALUE} >$DIG_TEMPOUTFILE
          else
            $DIG_TOOL @${INT_DNS_SERVER} ${DNS_VALUE} >$DIG_TEMPOUTFILE
          fi

          integer DNS_QUERY_TIME=0

          if [[ "${DNS_CHECK_TYPE}" = "AREC" ]] ;  then

             if [ `cat -s $DIG_TEMPOUTFILE | grep "^${DNS_VALUE}" | \
                  grep "A"| grep ${EXPECTED_IP} | wc -l` -gt 0 ] ; then
               FOUND_RECORD=TRUE
             else
               FOUND_RECORD=FALSE
             fi

          else # Assume CNAME Type

            if [ `cat -s $DIG_TEMPOUTFILE | grep "^${DNS_VALUE}" | \
                  grep "CNAME"| grep ${EXPECTED_IP} | wc -l` -gt 0 ] ; then
               FOUND_RECORD=TRUE
            else
               FOUND_RECORD=FALSE
            fi

          fi

          if [[ "${FOUND_RECORD}" = "TRUE" ]]; then

              DNS_QUERY_TIME=`grep -i "query time:" $DIG_TEMPOUTFILE | cut -d: -f2 | sed 's/msec//'| sed 's/ //g'`

              if [ $DNS_QUERY_TIME -gt $DNS_QUERY_TIME_WARN_MSEC ]; then

                printf "${HOLUD}FOUND      ${SHESH}\t: %18s : %50s : %50s : %s %s : RESPONSE TIME $DNS_QUERY_TIME MILLISECONDS\n"  \
                       "${APPKEY}" "${DNS_VALUE}" "${EXPECTED_IP}" "${DNS_SERVER_DESC}" "${DNS_SERVER}"  >> $TMPDIR/${TEST}.yellow.$$
              else

                printf "${SHOBUJ}FOUND      ${SHESH}\t: %18s : %50s : %50s : %s %s \n"  \
                       "${APPKEY}" "${DNS_VALUE}" "${EXPECTED_IP}" "${DNS_SERVER_DESC}" "${DNS_SERVER}"  >> $TMPDIR/${TEST}.green.$$
              fi
          else
                printf "${LAAL}NOT FOUND      ${SHESH}\t: %18s : %50s : %50s : %s %s \n"  \
                       "${APPKEY}" "${DNS_VALUE}" "${EXPECTED_IP}" "${DNS_SERVER_DESC}" "${DNS_SERVER}"  >> $TMPDIR/${TEST}.red.$$
          fi
       else
         printf "DISABLED      \t: %18s : %50s : %50s : %s  %s \n"  \
                "${APPKEY}" "${DNS_VALUE}" "${EXPECTED_IP}" "${DNS_SERVER_DESC}" "${DNS_SERVER}"  >> $TMPDIR/${TEST}.green.$$
       fi


done <$DNS_CONFIG_FILE_LIST


#************************  End of Test Specific Code ***************

COLOR="red"
STATUSMSG="ALERT: unable to gather information on ${TEST}!"
if [[ -s $TMPDIR/${TEST}.green.$$ ]]
then
    COLOR="green"
    GREENS=`head -1 $TMPDIR/${TEST}.green.$$`
    STATUSMSG="ok"
    MSGBODY=`cat $TMPDIR/${TEST}.green.$$`
fi
if [[ -s $TMPDIR/${TEST}.yellow.$$ ]]
then
    COLOR="yellow"
    YELLOWS=`head -1 $TMPDIR/${TEST}.yellow.$$`
    STATUSMSG="WARNING: `echo $YELLOWS | $SED 's/\&yellow //g'`"
    MSGBODY=`cat $TMPDIR/${TEST}.yellow.$$ |head -100; cat $TMPDIR/${TEST}.green.$$ 2>/dev/null`
fi
if [[ -s $TMPDIR/${TEST}.red.$$ ]]
then
    COLOR="red"
    REDS=`head -1 $TMPDIR/${TEST}.red.$$`
    STATUSMSG="ALERT: `echo $REDS | $SED 's/\&red //g'`"
    MSGBODY=`cat $TMPDIR/${TEST}.red.$$ |head -100; cat $TMPDIR/${TEST}.yellow.$$ 2>/dev/null; cat $TMPDIR/${TEST}.green.$$ 2>/dev/null`
fi
if [[ -s $TMPDIR/${TEST}.blue.$$ ]]
then
    COLOR="blue"
    BLUES=`head -1 $TMPDIR/${TEST}.blue.$$`
    if [ "${MESSAGE_ALERT}" = "TRUE" ]
    then
        STATUSMSG="ALERT: `echo $BLUES | $SED 's/\&blue //g'`"
    else
        STATUSMSG="Maintenance: `echo $BLUES | $SED 's/\&blue //g'`"
    fi
    MSGBODY=`cat $TMPDIR/${TEST}.blue.$$ |head -100; cat $TMPDIR/${TEST}.red.$$ 2>/dev/null; cat $TMPDIR/${TEST}.yellow.$$ 2>/dev/null; cat $TMPDIR/${TEST}.green.$$ 2>/dev/null`
fi

LINE="$MACHINE.$TEST $COLOR `date` - $STATUSMSG

EXTERNAL DNS Server = $EXT_DNS_SERVER
INTERNAL DNS Server = $INT_DNS_SERVER

$MSGBODY

"

echo "$LINE"

#############

# Mail Status To OPS

#############

if [ "$COLOR" = "red" ];

then

  export CONTENT=$TMPDIR/DNS-$TEST-CONTENT.$$
  echo "$LINE"  > $CONTENT
  export SUBJECT=" $MACHINE.$TEST ALERT `date` - $STATUSMSG"

  if [ "${MAIL_OPS}" = "TRUE" ]
  then

    (
     echo "Subject: $SUBJECT"
     echo "MIME-Version: 1.0"
     echo "Content-Type: text/html"
     echo "Content-Disposition: inline"
     echo "<HTML><BODY><PRE>"
     cat $CONTENT
     echo "</PRE></BODY></HTML>"
    ) | /usr/sbin/sendmail $OPS_EMAIL_ADDRESS

   fi

   if [ "${CREATE_SYSLOG_EVENT}" = "TRUE" ]
   then
     logger -t "DNSCHECK_ALERT: " -p alert -f $CONTENT
   fi
fi

$RM -f ${DNS_CONFIG_FILE_LIST} $TMPDIR/${TEST}.red.$$ $TMPDIR/${TEST}.yellow.$$ $TMPDIR/${TEST}.green.$$ $TMPDIR/${TEST}.blue.$ $CONTENT ${DIG_TEMPOUTFILE} 2>&1

exit 0
