# Fusion360 post Processor for Kosy 4 & NCCAD9

Fusion 360 post processer for use with [Kosy 4](https://www.max-computer.de/kosy4.html) milling machine. Produces valid GCode to be run by [NCCad9](https://www.max-computer.de/nccad9.html) from Kosy, which controls the milling machine.

A number of issues were identified with the cgeneated GCode from the Post processor provided by Fusion360 - this code resolves those.

## Items Resolved

_all changes in code marked with 'UPDATE'_

1. Addition of underscores at start of program - not recognised by NCCad.
2. Initial movement to Reference point G76 changed to G0 Z30 because of broken end stop sensor - G76 doesn't work
3. Erronious writing of `G90 G0 X. Y. Z.` - G90 and G0 on same row invalid. Removed unnecessary G90.
