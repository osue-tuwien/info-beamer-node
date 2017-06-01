#!/bin/bash
##
# @file
# @author Bernhard Froemel, Denise Ratasich
# @date WS 2014/15
#
# @brief Generates a schedule for the info beamer nodes.
#
# TUWEL CSV file format, example:
# Kurs:; OSUE Test
# :
# Abgabetermin:;Mittwoch, 9. November 2016, 23:55
# ;
# Datum & Zeit;Ort;Trainer/in;Teilnehmer/innen;Matrikelnummer;Email;Teilg.;Bewertung;Feedback
# Fr 11.11.2016 08:00 - 09:30;test;Denise Ratasich;Christian Hirsch[DR];0825187;christian.hirsch@tuwien.ac.at;;;
# Fr 11.11.2016 08:00 - 09:30;test;Denise Ratasich;Denise Ratasich;0826389;denise.ratasich@tuwien.ac.at;;;
#
# Students who are registered by supervisors are marked with [xx].
##

function usage {
  cat <<EOF
USAGE: $0 <exam> <start room> <enrolments>

Generates a schedule for the info beamer nodes.

Arguments:
  <exam>       Exam number out of {1|2}. Rooms and duration depend on this number.
  <start room> Starting room out of {1|2|3|4}. At the second exam, room 4 is
               not used for the practical part.
  <enrolments> Exported enrolments csv from TUWEL.
EOF
  exit 1
}

if [ $# -ne 3 ]; then
  echo "[ERROR] Wrong number of arguments." >&2
  usage
fi

ROOM_START="$2"
CSVFILE="$3"

# Exam number specific settings:
# TIL_ROOMS ... number of available rooms
# LAB_START_OFFSET ... nr of minutes from slot start when the lab part starts
if [ "$1" -eq 1 ]; then
  TIL_ROOMS=4
  LAB_START_OFFSET=20
elif [ "$1" -eq 2 ]; then
  TIL_ROOMS=3 # (TI4 is for multiple-choice test)
  LAB_START_OFFSET=30
else
  echo "[ERROR] Wrong exam number (must be 1 or 2): '$1'" >&2
  usage
fi

if [ ! -f "${CSVFILE}" ]; then
  echo "[ERROR] File does not exist: '${CSVFILE}'" >&2
  usage
fi


##
# TUWEL to myTI csv
##

#
# convert TUWEL csv to old csv format (TUWEL csv cannot be sorted by the date
# field, although this may not be necessary, as before exporting it can be
# sorted by date and time - actually it is by default)
#
# Date & time;Location;Teacher;Participant;ID number;Att.;Grade;Feedback
# Mon 9.11.2015 08:00 - 09:30;Eingang TI Seminarraum, Operngasse 9;Fabjan Sukalia;Bernhard Frömel;0326077;;;
#

# converted csv file
TMPFILE=tmp.csv

# eval header length in lines
lines=$(grep -n "^;" "${CSVFILE}" | awk 'BEGIN {FS=":"}{print $1}')
lines=$((lines+2))

# remove header and rearrange columns
tail -n +$lines "${CSVFILE}" |\
awk '
BEGIN {
  FS = ";"
  print "Matriculation Number;First Name;Last Name;Enrolment Date;Is Excused;Was Present;Slot Date;Slot Start;Slot End"
}
{
  datetime = $1
  location = $2
  teacher = $3
  student = $4
  matrnr = $5

  split(datetime, datetime_arr, " ")
  split(datetime_arr[2], date_arr, ".")
  date = sprintf("%4d-%02d-%02d", date_arr[3], date_arr[2], date_arr[1])
  slot_start = datetime_arr[3]
  slot_end = datetime_arr[5]

  student_n = split(student, student_arr, " ")
  firstname = student_arr[1]
  for(i = 2; i < student_n; i++)
    firstname = firstname" "student_arr[i]
  lastname = student_arr[student_n]

  if(matrnr ~ /[0-9]+/)
    print "\""matrnr"\";"firstname";"lastname";;;;"date";"slot_start";"slot_end
}
' > "${TMPFILE}"


##
# csv to config (print to stdout)
##

# ignore first line of enrolments
# sort enrolments w.r.t. slot start time and student ID
# and create schedule
tail -n+2 "${TMPFILE}" |
sort -t ';' -k 8,8 -k 1,1 |
gawk -F ";" '
function add_minutes(start, duration_mins) {
  if ((p=index(start,":")) > 0) {
    hrs = substr(start,1,p-1)
    mins = substr(start,p+1)

    added_mins = 60*hrs + mins + duration_mins;
    return sprintf("%02d:%02d", added_mins/60, added_mins%60)
  }
  return start
}
BEGIN { 
  OFS="";
  print "[";
  room = '$ROOM_START'-2;
  group = 0;
  last_slot = 0;
  num_rooms = '${TIL_ROOMS}';
  pcid = 1;
  pcoff = 0;
}
{
    if ($8 != last_slot) {
      slot_date = $7;
      last_slot = $8;
      room = (room + 1) % num_rooms;
      group = group + 1;
      pcid = 0;
      
      if(group != 1) {
        print "]";
        print "  },";
      }
      "date --date=\"" slot_date " " add_minutes(last_slot, -10) " +0100\" +%s" | getline unix_start;
      "date --date=\"" slot_date " " $9 " +0100\" +%s" | getline unix_stop;
      unix_start = unix_start + 10*60;
      print "  {"
      print "    \"group\": ", group, ",";
      print "    \"start\": \"", $8, "\",";
      print "    \"room_start\": \"", add_minutes($8, '${LAB_START_OFFSET}'), "\",";
      print "    \"stop\": \"", $9, "\",";
      print "    \"unix_start\": \"", unix_start, "\",";
      print "    \"unix_stop\": \"", unix_stop, "\",";
      print "    \"place\": \"Lab ", room+1, "\",";
      printf("    \"students\": [ %s", $1);
    } else {
      printf(", %s", $1);
    }

    pcid = pcid + 1;
}
END {
print "]"
print "  }"
print "]"
}
'

##
# cleanup
##
rm -f "$TMPFILE"
