import ds3231 show Ds3231

/*
Scenario:

We have an RTC and we wish to see if the oscillator has stopped.

If it has stopped, reset the flag.

In practise we might elect not to trust the time on the RTC if this is true.

*/

rtc ::= Ds3231 --scl=20 --sda=19   /* esp32-c6 DFrobot Beetle */

main:
  if rtc.oscillator-stopped:
    print "Oscillator Stopped!"
    rtc.clear-oscillator-stopped
    print "Oscillator Stop flag cleared!"
  else:
    print "Oscillator OK."
