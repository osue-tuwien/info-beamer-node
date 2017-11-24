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
args = parser.parse_args()

names = ['date', 'room', 'id']
cols = (0, 1, 4)
dtype = [(n, 'S100') for n in names]
data = np.genfromtxt(args.csvfile, delimiter=';', names=names, usecols=cols,
                     skip_header=7, dtype=dtype)

# extract number of rooms
rooms = np.unique(data['room'])
# room mapped to numbers 0,1,... alphabetically
room_no = {}
for i in range(len(rooms)):
    room_no[rooms[i]] = i + 1

# print schedule
group = 0
room_cur = ""
date_cur = ""
students = []
print("[")
for line in data:
    room = line['room']
    date = line['date']
    if room != room_cur and date != date_cur:
        # end last slot
        group = group + 1
        if room_cur != "":
            print("    \"students\": {}".format(sorted(students)))
            print("  },")
        # a new slot
        students = []
        print("  {")
        print("    \"group\": {},".format(group))
        dateparts = date.split()
        startstr = dateparts[1].decode('utf8') + " " + dateparts[2].decode('utf8')
        stopstr = dateparts[1].decode('utf8') + " " + dateparts[4].decode('utf8')
        start = datetime.datetime.strptime(startstr, '%d.%m.%Y %H:%M')
        stop = datetime.datetime.strptime(stopstr, '%d.%m.%Y %H:%M')
        print("    \"slot_start\": \"{}\",".format(start.strftime('%H:%M')))
        print("    \"start\": \"{}\",".format(start.strftime('%H:%M')))
        print("    \"stop\": \"{}\",".format(stop.strftime('%H:%M')))
        print("    \"duration\": {:.0f},".format((stop-start).seconds))
        print("    \"place\": \"Lab {}\",".format(room_no[room]))
        room_cur = room
        date_cur = date
    # append student id from every line
    student = line['id'].decode('utf8')
    students.append(student)
# end very last slot
print("    \"students\": {}".format(sorted(students)))
print("  }")
print("]")
