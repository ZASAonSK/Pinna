# Changelog

## 1.9.4

- Fixes the layout broken in 1.9.3: content reached past the edges of the screen on every iPhone, because the larger background glow stretched the screens. The background no longer affects the layout at all.

## 1.9.3

- More speed-ups, mainly for older iPhones:
  - Nearby Bluetooth devices are tracked only while the device picker is open; before, every device around (dozens in a city) kept redrawing all screens.
  - The background glow is drawn with gradients instead of a large blur – same look, a fraction of the work.
  - On iOS 16 the cards are solid instead of frosted glass and have no shadow, so scrolling stays smooth on iPhone 8 and X. iOS 17 and later look the same as before.

## 1.9.2

- Fixes constant lag on older iPhones (iOS 16, e.g. iPhone X): the softly moving background made every frosted card redraw its blur 60 times a second. On iOS 16, and everywhere when *Reduce Motion* is on, the background and the status dot now stay still.

## 1.9.1

- Smoother app, especially on older iPhones with iOS 16: Bluetooth broadcasts (dozens a second) no longer redraw the whole screen each time – only real changes do.

## 1.9.0

- **Battery on the Lock Screen as a Live Activity** (iOS 16.2+): left, right and case on the Lock Screen and in the Dynamic Island, updated on every change even with the app closed – widgets only get refreshed by iOS about every 30 minutes. Turn it on under *More features → Battery*. iOS ends it after 8 hours; opening Pinna starts it again.
- **Low battery alert**: a notification when an earbud is at 15 % or less, once per charge. Also under *More features → Battery*.
- Widgets show how long ago the battery last changed.
- *Diagnostics → Report on GitHub* opens a new issue with the log filled in, so you can check it before sending.

## 1.8.3

- Case battery updates when you open the case: an earbud out of the case keeps reporting the case level it saw last, which used to override the fresh value broadcast from inside the open case. Pinna now uses whichever value changed most recently, for the case and both earbuds.

## 1.8.2

- Battery no longer gets stuck: the earbuds don't always report changes on their own, so Pinna now reads the battery when you open it and every few seconds while it is open, and widgets follow. The diagnostics log shows each battery change.

## 1.8.1

- The small round **Battery** widget on the Lock Screen now shows both earbuds, left and right, instead of only the lower one. The L/R letters follow your phone's language in all widgets (e.g. Ľ/P in Slovak, G/D in French).

## 1.8.0

- **Editable Home screen.** Tap **Edit Home** at the bottom of the Home screen to reorder the cards, hide the ones you don't use and add others. New optional card: **Equalizer** with the presets one tap away. The settings menu always stays so the other screens remain reachable; **Reset** brings back the default layout.

## 1.7.2

- The left earbud announces itself only now and then. While not connected, Pinna now keeps listening for it in the background too (LE Audio announcement `184E`), so it learns and connects to it even when the app isn't open. Listening stops as soon as the earbuds are connected. (1.7.1 was published without this change by mistake.)

## 1.7.0

- **Connects with only the left earbud.** In LE Audio each earbud is a separate Bluetooth LE device: the right one was the identity Pinna knew, the left one has its own (found with a debug build – same name, Samsung data path in its broadcast). Pinna now recognises the other earbud when it advertises, remembers it and waits for both at once, so either earbud alone can connect. The first time, give the left earbud a minute or two to show up.

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
