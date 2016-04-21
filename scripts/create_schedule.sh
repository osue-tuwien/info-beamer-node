#!/bin/bash
##
# @file
# @author Bernhard Froemel
# @date WS 2014/15
#
# @brief Generates a schedule for the info beamer nodes.
##

function usage {
  cat <<EOF
USAGE: $0 <exam> <start room> <exam date> <enrolments>

Generates a schedule for the info beamer nodes.

Arguments:
  <exam>       Exam number out of {1|2}. Rooms and duration depend on this number.
  <start room> Starting room out of {1|2|3|4}. At the second exam, room 4 is
               not used for the practical part.
  <exam date>  Date of the exam in iso format, e.g., "2016-04-15".
  <enrolments> Exported enrolments csv from myTI.
EOF
  exit 1
}

if [ $# -ne 4 ]; then
  usage
fi

ROOM_START="$2"
EXAM_DATE="$3"

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
  echo "Wrong exam number (must be 1 or 2): '$1'" >&2
  usage
fi

if [ ! -f "$4" ]; then
  echo "File does not exist: '$4'" >&2
  usage
fi

# ignore first line of enrolments
# sort enrolments w.r.t. slot start time and student ID
# and create schedule
tail -n+2 ${4} |
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
      last_slot = $8;
      room = (room + 1) % num_rooms;
      group = group + 1;
      pcid = 0;
      
      if(group != 1) {
        print "]";
        print "  },";
      }
      "date --date=\"'${EXAM_DATE}' " add_minutes(last_slot, -10) " +0100\" +%s" | getline unix_start;
      "date --date=\"'${EXAM_DATE}' " $9 " +0100\" +%s" | getline unix_stop;
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
