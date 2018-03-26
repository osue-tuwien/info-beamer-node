Scripts
=======


Configuration for OSUE Exam
---------------------------

* Download exam enrolments from TUWEL.

* Call `create_schedule.py` to create `../node/schedule.json`.

* Adapt `../node/config.json`, if necessary (change `saal`).

Note that symlinks are not parsed. So the inputs (`config.json`,
`schedule.json`) must be regular files.


Start-up on info-beamer Platform
--------------------------------

* [optional] Device to place/saal mapping is configured in `config.json`. One
  may also set the appropriate environment variable: "SERIAL" is used to map
  the Pi to a lab room (e.g., SERIAL=b3 means the board is located in "Lab 3").

* Start info-beamer node:
  ```bash
  $ info-beamer .
  ```

* Start clock distribution:
  ```bash
  $ ./service
  ```
