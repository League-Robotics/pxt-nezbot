# Calibrating the line sensor

The PlanetX Trackbit reports each of its four reflectance sensors as
on or off. Which colour counts as "on" is not fixed: it is set by the
sensor's own calibration, and it is easy to set it the wrong way round.
When that happens every program that reads the sensor sees the track
inverted, and a line follower drives straight off the line.

Our code assumes **black is on and white is off**. Calibrate so that
holds.

## The LEDs

There are six LEDs on top of the sensor: one above each of the four
reflectance sensors, and two below them marked with a closed dot and an
open dot.

## The procedure

1. Put the sensor over **white**, well away from any line.
2. Press the calibration button. The open-dot LED lights and the
   sensor LEDs flash faintly. Whatever the sensor is over while this
   LED is lit becomes "off", so it must be over white now.
3. The LEDs then blink brightly and the open and closed dot LEDs
   alternate. The sensor is now learning both colours: move it back
   and forth across white and black until the blinking stops.

Starting step 2 over black makes black "off" and white "on", which is
the inverted state. If the sensor seems backwards, that is the first
thing to check.

## Checking it

The template program's `sense` run command prints the four sensors
left to right, `#` for on and `.` for off, with the bias the line
follower computes:

```
RUN sense     ->  sense #### bias 0      all four on black
                  sense .... bias 999    all four on white
                  sense ..## bias -18    line under the right two
```

If white gives `####`, the sensor was calibrated the wrong way round.
