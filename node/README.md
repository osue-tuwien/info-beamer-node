info-beamer-node
================


schedule.json
-------------

Generate with [create_schedule.py](../scripts/create_schedule.py) from CSV file
containing the exam enrolments.


config.json
-----------

* devices: Maps IDs of boards to the labs, saved in the environment of the
  board during start-up.
* saal: lab room (used in case the environment variable `SERIAL` is not set).
* rooms: Settings per lab room.
* startid: lowest ID of the TILAB computers (incremented for each student in
  the schedule).
