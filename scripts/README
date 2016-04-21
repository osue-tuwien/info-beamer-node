Scripts
=======


Configuration for OSUE Exam
---------------------------

* Download exam enrolments from myTI.
* Call create_schedule.sh to create schedule.json:

  $ ./create_schedule.sh 1 1 "2016-04-15" enrolments.csv > schedule.json
  
* Adapt config.json for the exam.


Start-up on info-beamer Platform
--------------------------------

* Set environment. Value from "SERIAL" is used to map the Pi to a lab room.
  For example, SERIAL=b3 means the board is located in lab number 3. However,
  the mapping can also be configured in the info-beamer node's 'config.json'.

* Start info-beamer node:

  $ info-beamer .

* Start clock distribution:

  $ ./service
