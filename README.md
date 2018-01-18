info-beamer-node for OSUE Exams
===============================

An info-beamer node from
[dividuum/info-beamer-nodes](https://github.com/dividuum/info-beamer-nodes),
modified for the OSUE exams @ TU Wien.

The subdirectory `scripts` contains startup scripts for the Raspberry Pi or
Jetson TK boards connected to the displays of our labs, and a tool to generate
the exam schedule for the nodes.

The info-beamer node is running during the OSUE exams to display student IDs
w.r.t. slot, i.e., time and room. Tutors can use this info to log in the
students. Further it shows how much time the students have left (per slot).

PLEASE NOTE: The software is based on other open source software, check the
subdirectories for the LICENSE.


Configuration
-------------

See the [README](scripts/README.md) in the `scripts` folder how to configure
the nodes for an exam.


Installation
------------

Copy the `node` directory to the Raspberry Pi.

Install the startup scripts (e.g., add a cronjob).


Usage
-----

Copy the python script `send-command` or clone this repo to the lab application
server.

For example, start the first slot in lab room 4.
``` bash
$ ssh <lab/osue/info-beamer-node>
$ ./send-command -r 4 reset
$ ./send-command -r 4 forward
$ ./send-command -r 4 start
```


References
----------

* [info-beamer Documentation](https://info-beamer.com/doc/info-beamer)
* [info-beamer Source](https://github.com/dividuum/info-beamer)
* Modified [info-beamer for RPi](https://github.com/tuw-cpsg/info-beamer)


Credits
-------

* Florian Wesch - for this great tool
* Bernhard Frömel - for coming up with this cool idea for the exams and installation in the labs (WS14/15)
