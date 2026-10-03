# Checking the alarm loop on a phone

How to prove, on a real phone, that the alarm sound wraps from its last sample to its first with
no gap and no click. Run it after any change to the Android alarm player
(`android/app/src/main/kotlin/app/critalarm/alarm/`) or to the iOS `alarm.caf`.

The bundled sounds all start and end in 80 ms to 1.5 s of silence, so a small gap hides inside
them. Do the check with the test tone below, never with a bundled sound.

## What the code does

- **Android.** `AlarmPlayer` decodes the sound once to 16-bit PCM (`PcmDecoder`) and loops it
  through a streaming `AudioTrack` on `USAGE_ALARM` (`PcmLoopPlayer`). A writer thread feeds the
  same buffer over and over, so the audio server never sees a break. `PcmLoopTest` proves the
  writer hands out every frame once per pass with nothing in between. If decoding fails, the log
  shows `alarm_loop_fallback` and MediaPlayer plays the sound the old way, with a gap.
- **iOS.** AlarmKit rings the compiled-in `ios/Runner/Sounds/alarm.caf`. Whether AlarmKit
  repeats a sound with no gap is not documented anywhere. Step 4 records it.
- **iOS caf files.** `GaplessCaf` writes every bundled and imported sound at its own sample rate
  and exact decoded length. `tool/caf_length_check.sh` proves it on a Mac (step 1).

## 1. File check, on the Mac

```sh
./tool/caf_length_check.sh
```

Every line must say `PASS` and the last line `ALL PASS`. Each line compares one caf against
ffmpeg's decode of the same source: frame count, sample rate, and the largest sample difference
at the same index. The bundled mp3s, mp3s from libmp3lame, m4a from `afconvert` and from
ffmpeg, wav and aiff are all covered.

## 2. Make the test tone

A 750 Hz sine at 48 kHz has a period of exactly 64 samples. A loop that is a whole number of
periods long is one steady tone when it wraps correctly, so any gap or click stands out.

```sh
# 2.000 s, 96000 frames, 1500 periods.
ffmpeg -f lavfi -i "sine=frequency=750:sample_rate=48000" -t 2 -ac 1 -c:a pcm_s16le sine750.wav

# Android: Ogg Opus, the format of the bundled sounds.
ffmpeg -i sine750.wav -c:a libopus -b:a 96k sine750.ogg

# iOS: LPCM caf for AlarmKit.
afconvert -f caff -d LEI16@48000 -c 1 sine750.wav sine750.caf
afinfo sine750.caf   # must show 96000 valid frames + 0 priming + 0 remainder
```

96000 is a multiple of 960, which leaves 648 frames of Opus padding on the last packet. That is
on purpose: the Android decoder has to cut that tail for the loop to be clean, so the tone tests
the trim as well as the wrap.

Do not import the tone through the app's sound picker. A cut is saved as 22.05 kHz with a 50 ms
fade at each end, so the result would dip at every wrap whatever the player does.

## 3. Android

### Build a test apk

Swap the tone in for one bundled sound in a scratch branch and never commit it:

```sh
cp sine750.ogg assets/sounds/classic_siren.ogg
make build-release-apk
git checkout assets/sounds/classic_siren.ogg
```

In the app, pick Classic Siren as the default sound. Do not use `make run-quiet`: a quiet build
plays the sound once and stops after 5 seconds, which never reaches a wrap.

### Putting Z's installed build back

Use a spare Android phone if there is one. If the check runs on Z's Galaxy A25:

1. Before installing, write down the installed version:
   `adb shell dumpsys package app.critalarm | grep versionName`, and keep the apk it came from.
2. `make build-release-apk` signs with the release key when `android/key.properties` is
   present. A build with the same key installs over the current one and keeps its topics and
   tokens: `adb install -r build/app/outputs/flutter-apk/app-release.apk`.
3. If `adb install -r` fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, the keys differ. Stop
   there. Uninstalling to get past it deletes every topic and token on the phone.
4. To put the old build back: `adb install -r -d <the apk from step 1>`, or check out the
   commit it was built from and run `make build-release-apk` again, then `adb install -r -d`.

### Record it

`AudioPlaybackCapture` does not record `USAGE_ALARM`, so screen recorders capture silence. Use
one of these:

- **Wired.** A USB-C to 3.5 mm adapter from the phone into the Mac's line input (or a USB audio
  interface). Android also rings an alarm through the speaker while a headset is plugged in, and
  the alarm forces full volume, so cover the speaker or do this in a room where that is fine.
- **Second phone.** Hold a second phone's microphone 5 to 10 cm from the speaker and record
  with its voice recorder, at 48 kHz if it offers a choice.

Trigger an incident on a topic with critical delivery on, let it ring for at least 25 seconds
(ten wraps of the 2 s tone, plus margin), then acknowledge it. Check the log as it starts:

```sh
adb logcat -s CritAlarmAlarm
```

It must show `alarm_decoded mime=audio/opus rate=48000 channels=1 frames=96000 trimmed=648`
and `alarm_loop_started`, and no `alarm_loop_fallback`.

### What a pass looks like

Open the recording in Audacity and switch the track to Spectrogram view.

- **Pass.** One flat line at 750 Hz from start to acknowledge. Zoom in on at least ten of the
  2 s marks after the first one: no vertical stripe, no drop in level, no break in the line. In
  the waveform view the sine runs straight through each mark.
- **Fail.** A vertical stripe (a click) or a short dark gap (a dropout) at every 2 s mark.
  MediaPlayer's loop looks like this: a gap of some tens of milliseconds at each wrap.

To see what a fail looks like, run the same recording on a build from before this change, or on
a build where the log shows `alarm_loop_fallback`.

## 4. iOS: does AlarmKit repeat `alarm.caf` with no gap?

Needs iOS 26.1 or later. On 26.0 a custom AlarmKit sound played once, so record the version.

1. In a scratch branch, replace `ios/Runner/Sounds/alarm.caf` with `sine750.caf` from step 2,
   keeping the name. Build and install with Xcode or `make run-release`. Never commit the swap.
2. Ring an AlarmKit alarm: an incident push to a topic with critical delivery on, with the phone
   locked.
3. Record with a second phone's microphone held to the speaker. Let it ring for at least
   40 seconds: Apple's limit for a sound is 30 s, so listen past that too.
4. Check the recording the same way as Android: a flat 750 Hz line, and at least ten clean 2 s
   marks.
5. Put the real `alarm.caf` back with `git checkout ios/Runner/Sounds/alarm.caf` and reinstall.

Write the answer into the table below in the same branch as the check, then commit it.

| Date | Phone | OS | Repeats at all? | Gap at the wrap? | Notes |
|---|---|---|---|---|---|
| | | | | | |

## Android results

| Date | Phone | Android | Build | Clean wraps checked | Result |
|---|---|---|---|---|---|
| | | | | | |
