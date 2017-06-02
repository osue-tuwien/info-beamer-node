Scripts
=======


Configuration for OSUE Exam
---------------------------

* Download exam enrolments from TUWEL.

* Call `create_schedule.sh` to create `schedule.json` for the 1st exam starting
  in lab room 1:
  ```bash
  $ ./create_schedule.sh 1 1 enrolments.csv > ../node/schedule.json
  ```

* Adapt `config.json`, if necessary (change start room).


Start-up on info-beamer Platform
--------------------------------

* Set environment. Value from "SERIAL" is used to map the Pi to a lab room.
  For example, SERIAL=b3 means the board is located in lab number 3. However,
  the mapping can also be configured in the info-beamer node's `config.json`.

* Start info-beamer node:
  ```bash
  $ info-beamer .
  ```

* Start clock distribution:
  ```bash
  $ ./service
  ```
