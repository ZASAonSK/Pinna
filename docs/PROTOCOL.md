# Galaxy Buds over Bluetooth LE — what Pinna uses

Measured on Galaxy Buds3 Pro (SM-R630) with an iPhone. Other models use the
same messages but have not been tested.

## Services

| Service | Characteristic | Use |
| --- | --- | --- |
| `A7A473E9-19C6-491B-AEA6-7EA92B8F043A` (Samsung data channel) | `A7A48311-…` write | Settings messages, executed by the earbuds |
| | `A7A48322-…` notify | Never sends anything to an iPhone (see below) |
| `180F` Battery Service (one per earbud / case) | `2A19` + `2904` description | Live battery; `2904` description `0x010D` left, `0x010E` right, `0x0110` case |
| `1844` Volume Control Service | `2B7D` state `[volume 0–255, mute, change counter]`, `2B7E` control point | Live volume; opcodes `0` down, `1` up, `4` set, `5` unmute, `6` mute |
| `180A` Device Information | `2A24` model, `2A26` firmware | Model detection |

Samsung's advertisement (company ID `0x0075`) carries the battery of both
earbuds and the case and the model/colour ID (big-endian at offset 14, e.g.
`0x0154` = Buds3 Pro). It does **not** change with noise mode or in-ear state.

## Message frame

```
FD | size (2 B, LE) | id | payload | CRC16 (LE) | DD
```

- `size & 0x3FF` = 1 + payload length + 2.
- Bit `0x1000` marks a response, `0x2000` a fragment. Settings are sent without either.
- CRC-16/XMODEM (poly `0x1021`, init `0`) over `id + payload`.
- The first Galaxy Buds (2019) use `FE … EE` instead of `FD … DD`.

Example: ANC on = `FD 04 00 78 01 D1 91 DD`.

## Settings messages

| ID | Setting | Payload |
| --- | --- | --- |
| `0x78` | Noise control | `[0 off, 1 ANC, 2 ambient, 3 adaptive]` |
| `0x83` | ANC strength | `[0…4]` on Buds3 Pro |
| `0x84` | Ambient volume | `[0…4]` on Buds3 Pro |
| `0x6F` | Noise control with one earbud | `[0, 0, on]` on Buds3 Pro, `[on]` on older models |
| `0x7A` | Voice detect | `[on]` |
| `0x86` | Equalizer preset | `[0…5]` |
| `0x8F` | Balance | `[0…32]`, 16 = centre |
| `0x8B` | Ambient sound during calls | `[on]` |
| `0x85` | Game mode | `[on]` |
| `0x6C` | Pause media when removed | `[on]` |
| `0x6E` | Calls to earbuds when inserted | `[off]` (inverted) |
| `0x90` | Gestures and lights | see below |
| `0x92` | Touch-and-hold action | `[left, right]` |
| `0x79` | Noise modes for pinch-and-hold | `[left, right]`, bits `0x08` ANC, `0x04` off, `0x02` adaptive, `0x01` ambient |
| `0x95` | Double-tap edge for volume | `[on]` (older models) |
| `0xA0` / `0xA1` | Find My Earbuds start / stop | — |
| `0xAF` | Seamless switching | `[off]` (inverted) |
| `0xC9` | Neck stretch reminder | `[on]` |

`0x90` (lock touchpad) layout by generation:

| Generation | Payload |
| --- | --- |
| Buds, Buds+, Buds Live, Buds Pro | `[locked]` |
| Buds2 … Buds3 | `[on, tap, double, triple, hold, calls double, calls hold]` |
| Buds3 Pro | the above + `[swipe, lights 1 steady / 2 solid / 3 breathing, double pinch-and-hold]` |

Lights are switched on and off on the earbuds themselves by pinching and
holding both earbuds at once; `0x90` only selects their style.

## Why the app cannot read the current state

- With notifications enabled on `A7A48322` (CCCD read back as `1`), the
  earbuds still send nothing — not for `MANAGER_INFO 0x88`, status requests
  (`0x26`, `0x24`, `0x22`, `0x29`, `0x60`, `0x61`) or acknowledgements.
- The data channel is a generic profile from the earbuds' chip vendor; it
  only forwards what the firmware hands to it. Samsung's firmware sends
  status and replies over Bluetooth Classic (RFCOMM), which is what Samsung's
  own Android app uses. iOS does not let third-party apps open RFCOMM.
- No Fast Pair (`FE2C`) or other vendor service is present on SM-R630.

So noise mode, in-ear state and settings shown in Pinna are the values last
sent from the app. Battery and volume are live.

## Sources

- [GalaxyBudsClient](https://github.com/timschneeb/GalaxyBudsClient) — message IDs and payloads.
- [SamsungGalaxyBuds2Pro](https://github.com/msrk0320/SamsungGalaxyBuds2Pro) — writing settings over the LE data channel.
- [OpenPineBuds](https://github.com/pine64/OpenPineBuds) — reference for the chip vendor's data-path profile.
- Payload layouts for Buds3 Pro were confirmed against the behaviour of Samsung's Galaxy Buds3 Pro Manager.
