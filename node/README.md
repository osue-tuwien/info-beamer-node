info-beamer-node
================


schedule.json
-------------

Generate with [create_schedule.sh](../scripts/create_schedule.sh) from CSV file
containing the exam enrolments.


config.json
-----------

* devices: Maps IDs of boards to the labs, saved in the environment of the
    	   board during start-up.
* exam: Number of the exam, out of {1|2}. Defines the "phases" of an exam,
  	e.g., duration.
* saal: Default room (for testing). Boards load this value from the environment
  	(SERIAL).
* rooms: Settings per lab room.
* speed: Speed of rotation of background/vortex (the higher this value, the
  	 lower the speed).
* startid: ID of the TILAB computers for the students (the number of computers
  	   is hardcoded).
