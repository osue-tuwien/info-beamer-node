#!/usr/bin/env python3
"""
@file
@author Denise Ratasich
@date WS 2017/2018

@brief Generates a schedule for the info beamer nodes.

TUWEL CSV file format, example:
Kurs:; OSUE Test
:
Abgabetermin:;Mittwoch, 9. November 2016, 23:55
;
Datum & Zeit;Ort;Trainer/in;Teilnehmer/innen;Matrikelnummer;Email;Teilg.;Bewertung;Feedback
Fr 11.11.2016 08:00 - 09:30;test;Denise Ratasich;Christian Hirsch[DR];0825187;christian.hirsch@tuwien.ac.at;;;
Fr 11.11.2016 08:00 - 09:30;test;Denise Ratasich;Denise Ratasich;0826389;denise.ratasich@tuwien.ac.at;;;

Students who are registered by supervisors are marked with [xx].

Note: Timestamps are saved as seconds since epoch but given the locale
settings.

Note: Slot start and end time, room name are taken from the TUWEL CSV file.
"""

import argparse
import numpy as np
import datetime


parser = argparse.ArgumentParser(
    description="Prints a schedule for the info-beamer nodes.")
parser.add_argument('csvfile',
                    help="Exported enrolments csv from TUWEL (all columns).")
parser.add_argument('-p', "--preparation", type=int, default=0,
                    help="""Preparation time in minutes (default: 0). Shifts
                    lab start from slot start.""")
parser.add_argument('-r', "--rooms", type=int, default=4,
                    help="""Number of computertest rooms (default: 4). Lab room
                    will be iterated from start room over all rooms.""")
parser.add_argument('-s', "--startroom", type=int, default=4,
                    help="""Start room (default: 4). Rooms are numbered from 1
                    .. number of rooms given with -r.""")
args = parser.parse_args()

# read slots and ids from the enrolments
names = ['date', 'id']
cols = (0, 4)
dtype = [(n, 'S100') for n in names]
data = np.genfromtxt(args.csvfile, delimiter=';', names=names, usecols=cols,
                     skip_header=7, dtype=dtype)

# print schedule
preparation = datetime.timedelta(minutes=args.preparation)
group = 1
room = args.startroom
date_cur = ""
students = []
print("[")
for line in data:
    date = line['date']
    if date != date_cur:
        # end last slot
        if date_cur != "": # except the first time
            print("    \"students\": {}".format(sorted(students)))
            print("  },")
            group = group + 1
            if room >= args.rooms:
                room = 1
            else:
                room = room + 1
        # a new slot
        students = []
        print("  {")
        print("    \"group\": {},".format(group))
        dateparts = date.split()
        startstr = dateparts[1].decode('utf8') + " " + dateparts[2].decode('utf8')
        stopstr = dateparts[1].decode('utf8') + " " + dateparts[4].decode('utf8')
        slotstart = datetime.datetime.strptime(startstr, '%d.%m.%Y %H:%M')
        start = slotstart + preparation
        stop = datetime.datetime.strptime(stopstr, '%d.%m.%Y %H:%M')
        print("    \"slot_start\": \"{}\",".format(slotstart.strftime('%H:%M')))
        print("    \"start\": \"{}\",".format(start.strftime('%H:%M')))
        print("    \"stop\": \"{}\",".format(stop.strftime('%H:%M')))
        print("    \"duration\": {:.0f},".format((stop-start).seconds))
        print("    \"place\": \"Lab {}\",".format(room))
        room_cur = room
        date_cur = date
    # append student id from every line
    student = line['id'].decode('utf8')
    students.append(student)
# end very last slot
print("    \"students\": {}".format(sorted(students)))
print("  }")
print("]")
