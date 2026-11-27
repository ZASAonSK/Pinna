# Changelog

## 1.6.1

- Connecting with a single earbud: a pending connection is no longer cancelled and restarted every 30 seconds – a single earbud answers rarely and the restarts kept missing it. The attempt now runs uninterrupted and is renewed only after 150 seconds (or when Bluetooth or the earbuds' connection to the phone changes).
- If the left and right earbud turn out to have separate Bluetooth identities, Pinna remembers each one that ever connected and waits for all of them at once, using whichever answers first.
- The diagnostics log shows a short device ID with every connect and disconnect (e.g. `Sluchovody [9FD1]`).

## 1.6.0

- **Widgets**: Battery (Home Screen and Lock Screen – circular, rectangular and inline), Noise control (small and medium, with mode buttons on iOS 17+) and Battery & noise control (medium and large).
- **Control Center controls (iOS 18)**: a Noise cancelling toggle that shows the current state, plus Ambient, Off and Adaptive buttons – with their own icons, no Shortcuts needed.
- All of it is optional: add only what you want. Widget buttons and controls run in the app, which keeps the Bluetooth link in the background.
- Note for free Apple IDs: the widget extension uses one more App ID when sideloading.

## 1.5.0

- Control noise cancelling without opening the app: new actions "Toggle noise cancelling" (ANC ↔ Ambient) and "Set noise control" for Control Center (iOS 18: edit Control Center → Add a Control → Shortcuts), the Action button, Siri and the Shortcuts app. They use the same Bluetooth link as the app, which stays connected in the background since 1.4.0.
- *More features* explains how to add them.

## 1.4.0

- Faster start: Pinna now keeps the Bluetooth link to your earbuds while it is closed (background Bluetooth with state restoration), so the controls are usually ready the moment you open it. If iOS ends the app in the background, it relaunches it with the existing link. Nothing else runs in the background.

## 1.3.0

- Custom equalizer: a 7th preset "Custom" with nine bands (63 Hz – 16 kHz, −10 … +10) and a reset button, sent exactly like Samsung's app does (curve first, then the custom preset). Available on Galaxy Buds3, Buds3 Pro, Buds3 FE, Buds4 and Buds4 Pro.

## 1.2.0

- Choose which noise modes pinch-and-hold switches between, separately for each earbud (e.g. left: ANC ↔ Off, right: Ambient ↔ Off), like "Switch noise controls" in Samsung's app. Shown under *Gestures & lights → Pinch and hold actions* when an earbud is set to Noise control; at least two modes stay selected.

## 1.1.0

- Runs on **iOS 16** too. On iOS 17 and later everything looks and animates exactly as before; on iOS 16 the animations use the closest older equivalent, and the frosted-material design is used as on iOS 17–18.

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
