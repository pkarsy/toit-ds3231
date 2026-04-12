# Ds3231
[Toit](https://toitlang.org/) driver for the DS3231 real time clock.

## Warning
Working with time, especially if there are constraints on the accuracy, is a
hard job. At the moment the library has limited testing and bugs are expected.
Any help on inmpoving the driver is welcome.

## Installing + documentation
See [ds3231 at Toit package registry](https://pkg.toit.io/search?query=ds3231)

## Connection
You need 4 pins:

> SCL SDA VCC GND

The popular blue DS3231 boards (check the documentation for your board) do not
have level conversion circuitry. So the VCC pin should be connected to 3.3V.
The breakout consumes minimal current, and you can use GPIO pins for the VCC and
GND. See the examples.

## RTC Coin Cell
Note: This section applies to the popular blue DS3231 breakout board, with the
primitive diode charging circuit.

Use a good CR2032 coin cell. Some internet sources mention LIR2032 (rechargable)
but with 3.3V (see the above paragraph) the rechargable cell cannot be charged
at all, making the module unusable. The CR2032 is safe with 3.3V for the same
reason the LIR2032 canot be charged (No reverse current, as the diode has a voltage
 drop ~0.7 Volt). You can remove the diode as many sources mention, but it is
 not necessary if you power the module with 3.3V only.

## Accuracy
You can expect to get and set the time with a less than 1-2ms error.
However, the DS3231 RTC clock can have up to 2ppm drift (0 - 40C).

```
1 day : 0.17 sec
1 week : 1.2 sec
1 month : 5 sec
1 year : 1 min
```

The above values are more or less the worst cases, unless you expose the module
to extreme temperatures. (See the Aging Correction below)

If the project can have internet access (even occasionally, for example a mobile
phone as access point) the time could be fixed using NTP. See the
"ntp-plus-rtc.toit" example.

The crystal of the ESP32 board inevitably has much worse performance than
the TCXO crystal of the Ds3231, and it makes sense (when not using NTP) to
update the system (ESP32) time every hour using the DS3231 time. See
the example "nowifi.toit" for this.

All the above are only useful, if you know the wanted accuracy. Some hints:

- For a project having NTP(internet) time, but need the RTC as a backup,
  the DS3231 is already extremely accurate.

- For projects expecting to be mostly without wifi, the aging correction can be
  useful, but a 1 minute error per year can still be insignificant
  (irrigation timer comes to mind). See below on how to calculate the aging offset

- For projects really isolated (from the internet) and still requiring high time
  precision, a GNSS module can be a solution (you have to solve other problems of
  course). For Toit there are GNSS drivers, but I have not tested them.
  I have created such a
  [GNSS time driver for tasmota](https://github.com/pkarsy/TasmotaBerryTime/tree/main/ds3231)
  if you are interested.

## Developer Hints
- library documentation at [ds3231 @ toit package registry](https://pkg.toit.io/search?query=ds3231)
- Inspect the examples to see how they work in practice.
- Almost all library calls can raise exceptions, for example when the cabling is bad.

## Constructor
You can create the driver instance in 2 ways.
- Create the i2c bus object first, and then pass it to the constructor.
- If the DS3231 is the only i2c device in the bus (most common case) you
  can simply pass the pin numbers to the constructor.

## Setting and getting the time
This library, just like the ntp library, uses time-adjustment instead of absolute
time. This is a clever way to set the time correctly, even if there is a time gap
between time-get (for instance from NTP) and time-set (to the DS3231)

## SQW pin
The library does not use/need this pin by itself, but you may find it usefull
for other purposes, as interrupt source etc. The following functions can
control the SQW output.

```
enable-sqw-output
disable-sqw
enable-battery-backed-sqw
disable-battery-backed-sqw
```

DS3232 will retain the register settings as long as the module is active or
is battery backed.

## Temperature
> get-temperature

returns the temperature in °C as a float. Internally is updated every about 1 min (SN model). However you can force a temperature conversion with
> force-temp-conversion

## Clock drift
> expected-drift

shows the expected time drift (assuming 2ppm error) since the given time. The real drift is usually smaller. You can set the ppm error.

## ALARM 1/2
The DS32321 has two alarm slots, and these can be enabled/disabled independently.
They differ only in that Alarm 1 has resolution to the second, Alarm 2 has
resolution only to the minute.  Internally, it functions similar to other time
functions: of the 4 properties (hour, minute, second, day) each can be set as
'match' or 'ignore'.  This allows some interesting alarm types, including
'every minute at :30 seconds' or 'every day'.

The code has several functions supporting alarms:
- `get-alarm`: Returns an `AlarmSpec` object containing the alarm time/moment.
- `set-alarm`: Takes an `AlarmSpec` and sets either of the alarm slots to the
  alarm time.
- `set-sqw-as-interrupt`: takes a boolean to either set or unset the SQW pin as
  a GPIO pin alarm interrupt.
- `enable-alarm`: activates or deactivates either alarm slot.
- `is-alarm-triggered`: returns true when the specified alarm has tripped.
- `clear-alarm`: clears a raised alarm.  (Will not clear by itself.)

If a `AlarmSpec` is configured to the second, but stored in slot 2, the seconds
allocation is dropped but other data still written.

> [!WARNING]
> Out of the box, corrupt/nonsensical data can be in these registers.  This is
> noncritical in that first, they are not enabled by default.  Second, if they
> are enabled, the alarm will trigger when the selected digits from the time
> match.  This would mean that if the data would say 33:00 o'clock, the
> time would never match, and therefore, the alarm will simply never trigger.

### Using AlarmSpec
The `AlarmSpec` object is used to describe an alarm time, and store it in a
format that the DS3231 understands.  The object is designed to be immutable,
however it does have a `.with` function to create a new object by modifying an
existing one.  It has helpers to set common configurations. See the
[examples](./examples/).


Printing it will show the outcome of setting and enabling the alarm.  In this
example, create an 'every-minute' alarm - would raise every time the seconds
get to '30':
```Toit
minutely := AlarmSpec.every-minute --seconds=30
print "Hourly alarm is: $minutely ($(minutely.stringify --debug))"

// Set alarm in the registers:
rtc.set-alarm 1 minutely
print "Alarm 1 now set to: $minutely."
```

## Aging correction

> set-aging-offset

Can get a value from -128 up to 127 to make the clock more accurate (significantly less than 2ppm).
- inside tools there is the **offset-calculator.toit** program. The hardware setup is minimal a
  ESP32x and a Ds3231 module. It is very slow, but you can use
  multiple modules in parallel.
- [this project](https://github.com/gbhug5a/DS3231-Aging-GPS), is much faster but also
  needs more work (and hardware) to implement.

## VCC GND and battery powered projects
On battery, the 4mA the DS3231 is using, is a huge consumption. For this
purpose the VCC and GND can be GPIO pins, and the DS3231 module is powered OFF when
in deep-sleep. Assuming a good CR2032 coin cell, the time keeping function will
still work (for 10 years !) and the registers will retain their values.

## Oscillator Stop Detection
The DS3231 has a Oscillator Stop Flag (OSF) in its status register.  This is set
whenever the oscillator stops — typically because the coin cell battery was
exhausted or removed during a power loss.  This provides a simple way to detect
whether the RTC time is still valid on boot without any additional hardware.

`oscillator-stopped` reads this flag and returns true if the oscillator has
stopped since it was last cleared. `clear-oscillator-stopped` resets the flag
which must be run manualy once the condition has been handled — typically after
resyncing the time from NTP or another trusted source.  An example of this is
in `osf.toit` in the [examples](./examples/) folder.

This approach avoids the need for a voltage divider and ADC input to sense the
coin cell voltage directly.
