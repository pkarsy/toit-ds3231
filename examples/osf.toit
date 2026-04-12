import ds3231 show Ds3231
import esp32 show adjust_real_time_clock
import ntp
import monitor

/*
Scenario:
We have an RTC and we wish to see if the oscillator has stopped.  If it has
  stopped, it must be because the battery failed.  Therefore, reset the flag,
  and set the time on the DS3231.

*/

rtc ::= Ds3231 --scl=20 --sda=19   /* esp32-c6 DFrobot Beetle */
ntp-ready ::= monitor.Latch
ntp-update-period-success ::= Duration --m=30
ntp-update-period-fail ::= Duration --s=30

main:
  /* Run NTP Update in the background constantly. */
  task:: update-time

  /* Block here until NTP sync has completed at least once. */
  print "Waiting for NTP..."
  ntp-ready.get

  /* Display current time (NTP and RTC) for interest. */
  rtc-time := rtc-current-time
  print "Current RTC Time : $rtc-time"
  print "Current NTP Time : $Time.now"

  /* Evaluate if the OSF flag is tripped, and take action. */
  if rtc.oscillator-stopped:
    print "DS3231 Oscillator: OSF flag tripped - had stopped!"
    rtc.clear-oscillator-stopped
    print "                   -> Stop flag cleared!"
    rtc.set (Duration.ZERO)
    print "                   -> RTC now set to $Time.now"
  else:
    print "DS3231 Oscillator: OSF flag OK."

/*
Just work out the time from the RTC.  (To help understand the actions above.)
*/
rtc-current-time -> Time:
  adjustment := rtc.get --allow-wrong-time // Just to allow show and prevent a throw
  rtc-time := Time.now + adjustment
  return rtc-time

/*
Updates the system time. (From NTP only.)
- Signals $ntp-ready once the first NTP sync completes.
- Does not update RTC by itself.
*/
update-time:
  last-ntp-time/Time? := null
  while true:
    result := ntp.synchronize
    if result:
      if last-ntp-time != null and result.accuracy > (Duration --ms=100):
        print "NTP accuracy too low, skipping."
        sleep --ms=1
        continue
      last-ntp-time = Time.now + result.adjustment
      adjust_real_time_clock result.adjustment
      /* Commented out just for clarity */
      // print "NTP sync done (adjustment=$result.adjustment acc=$result.accuracy)"

      /* Signal that NTP has completed (at least once). */
      if not ntp-ready.has-value:
        ntp-ready.set true

      /* Sleep until next update time */
      sleep ntp-update-period-success
    else:
      /* Sleep until next update attempt */
      print "NTP synchronization failed. (Trying again in $ntp-update-period-fail)"
      sleep ntp-update-period-fail
