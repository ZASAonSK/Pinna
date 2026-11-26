# Changelog

## 1.0.3

- Fixes connections being dropped right after they succeeded (1.0.1–1.0.2): iOS reports the app's own link as "earbuds connected", which made the app cancel and restart it; a retry on every broadcast also cancelled attempts that were about to succeed. The app now never cancels a link that is up, uses the connection notice only when nothing is pending, and renews only an attempt stuck for 30 seconds.

## 1.0.2

- Fixes 1.0.1 not connecting at all: the iOS auto-reconnect option made every connection attempt to Galaxy Buds3 Pro fail, and the app retried in a tight loop. The option is gone and a failed attempt now waits 3 seconds before the next one. Reconnecting after Bluetooth is toggled or the case is reopened is kept.

## 1.0.1

- Reconnects after Bluetooth is turned off and on or the case is closed and reopened: Pinna now notices when the earbuds reconnect to the phone and brings its own link back up, lets iOS re-establish the link automatically, and renews a connection attempt that hangs for more than 20 seconds.
- If the earbuds still don't connect, the app suggests pairing mode.

## 1.0.0

First release of Pinna.

- Control Samsung Galaxy Buds from iPhone over the Bluetooth LE data channel: noise control (off, ANC, ambient, adaptive), ANC strength and ambient volume, equalizer, balance, ambient sound during calls, game mode, gestures and lights, touch-and-hold actions, voice detect, ANC with one earbud, in-ear detection, seamless switching, neck stretch reminder and Find My Earbuds.
- Live battery for both earbuds and the case; live earbud volume with −/+, slider and mute.
- Automatic connection and a device picker that also lists renamed earbuds.
- Profiles for 13 Galaxy Buds models; verified on Galaxy Buds3 Pro, the rest experimental.
- Liquid Glass interface on iOS 26 with a material fallback on iOS 17–18.
- 11 languages.
