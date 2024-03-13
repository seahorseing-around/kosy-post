# kosy-post for Fusion360

A fixed Kosy Post processer for Fusion 360 for use with Kosy 4, 3 Degrees of Freedom milling machine. Produces valid GCode to be understood and used by NCCad9 from Kosy.

## Items Resolved

    *all changes in code marked with 'UPDATE'*

1. Addition of underscores at start of program - not recognised by NCCad.
2. Initial movement to Reference point G76 changed to G0 Z30 because of broken end stop sensor - G76 doesn't work
3. Erronious writing of `G90 G0 X. Y. Z.` - G90 and G0 on same row invalid. Removed unnecessary G90.
