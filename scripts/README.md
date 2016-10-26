Scripts
=======


Configuration for OSUE Exam
---------------------------

* Download exam enrolments from TUWEL.

* Call `create_schedule.sh` to create `schedule.json`:

      $ ./create_schedule.sh 1 1 "2016-04-15" enrolments.csv > schedule.json
  
* Adapt `config.json` for the exam.


Launch on info-beamer Platform
------------------------------

* Set environment. The value of `SERIAL` is used to map the Pi to a lab
  room. For example, `SERIAL=b3` means the board is located in lab
  room 3. However, the mapping can also be configured in the info-beamer node's
  `config.json`.

* Change to folder `../node/`.

* Start info-beamer node:

      $ info-beamer .

* Start clock for local node:

      $ ./service
