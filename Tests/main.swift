import Foundation

func data(_ s: String) -> Data { Data(s.split(separator: " ").map { UInt8($0, radix: 16)! }) }
func hex(_ d: Data) -> String { d.map { String(format: "%02X", $0) }.joined(separator: " ") }

// Real 39-byte merged advertisement + scan response from the inspected Buds3 Pro.
let frame = data("75 00 42 09 81 02 14 15 03 21 01 08 A2 0C 01 54 06 3C 00 00 00 00 00 00 00 00 00 5A 1E 77 C3 08 00 2C 58 58 00 03 14")
let token = data("5A 1E 77 C3 08 00")

precondition(frame.count == 39)
precondition(AdvertisementDecoder.isBudsFrame(frame))
precondition(AdvertisementDecoder.learnedToken(from: frame) == token)

let full = AdvertisementDecoder.decode(frame)!
precondition(full.caseLevel == 44 && full.a == 88 && full.b == 88)
precondition(full.status == 0x00)
precondition(full.suffix == [0x00, 0x03, 0x14])
precondition(full.token == token)
precondition(full.batteryCount == 3 && !full.partial && full.hasBatteryValues)
precondition(full.validBatteryCount == 3)
precondition(full.rawValues == [44, 88, 88])

// Bit-7 charging is an unverified diagnostics candidate only.
precondition(AdvertisementDecoder.chargingCandidate(0x2C) == nil)
precondition(AdvertisementDecoder.chargingCandidate(0xFF) == nil)
precondition(AdvertisementDecoder.chargingCandidate(0x80) == 0)
precondition(AdvertisementDecoder.chargingCandidate(0xE4) == 100)
precondition(AdvertisementDecoder.chargingCandidate(0xE5) == nil)

// Each percentage is independently optional; >100 is "unavailable", not a flag.
for index in [33, 34, 35] {
    var b = [UInt8](frame); b[index] = 255
    let p = AdvertisementDecoder.decode(Data(b))!
    let values = [p.caseLevel, p.a, p.b]
    precondition(values[index - 33] == nil)
    precondition(p.validBatteryCount == 2)
    for other in 0..<3 where other != index - 33 { precondition(values[other] != nil) }
}

var b = [UInt8](frame)
b[33] = 255; b[35] = 255
let leftOnly = AdvertisementDecoder.decode(Data(b))!
precondition(leftOnly.caseLevel == nil && leftOnly.a == 88 && leftOnly.b == nil)
b[34] = 0
precondition(AdvertisementDecoder.decode(Data(b))?.a == 0)
b[34] = 255
let none = AdvertisementDecoder.decode(Data(b))!
precondition(none.a == nil && none.b == nil && none.caseLevel == nil && !none.hasBatteryValues)
precondition(none.validBatteryCount == 0)

// A raw byte of 0x80|percent stays "unavailable" for the real values and only
// shows up as a charging candidate in diagnostics.
var charging = [UInt8](frame)
charging[34] = 0xE4
let candidateFrame = AdvertisementDecoder.decode(Data(charging))!
precondition(candidateFrame.a == nil && candidateFrame.validBatteryCount == 2)
precondition(candidateFrame.rawValues == [44, 0xE4, 88])
precondition(AdvertisementDecoder.chargingCandidate(candidateFrame.rawValues[1]) == 100)

// Advertising-only frame: still recognised as Buds, but no battery block.
let advertisingOnly = Data(frame.prefix(26))
precondition(AdvertisementDecoder.isBudsFrame(advertisingOnly))
precondition(AdvertisementDecoder.decode(advertisingOnly) == nil)
precondition(AdvertisementDecoder.learnedToken(from: advertisingOnly) == nil)

// Learned identity finds the same block when the blob is shifted or reordered.
let shifted = Data(frame.prefix(26)) + Data([0xAA, 0xBB]) + Data(frame[26...])
precondition(shifted.count == 41)
let shiftedDecoded = AdvertisementDecoder.decode(shifted, tokens: [token])!
precondition(shiftedDecoded.caseLevel == 44 && shiftedDecoded.a == 88 && shiftedDecoded.b == 88)
precondition(shiftedDecoded.frameLength == 41 && shiftedDecoded.batteryCount == 3)
precondition(AdvertisementDecoder.decode(shifted) == nil)

// A coincidental token match in the advertising tail must not hide the real
// block near the end of the blob.
let earlyToken = Data(frame.prefix(15)) + token + Data(frame[21...])
precondition(earlyToken.count == 39)
let earlyDecoded = AdvertisementDecoder.decode(earlyToken, tokens: [token])!
precondition(earlyDecoded.caseLevel == 44 && earlyDecoded.a == 88 && earlyDecoded.b == 88)
precondition(earlyDecoded.batteryCount == 3)

// Bootstrapping without a learned token: a shortened scan response keeps the
// block at the observed offset and still decodes the values it carries.
let oneValueFrame = Data(frame.prefix(26)) + data("00") + token + data("2C") + data("00 03 14")
precondition(oneValueFrame.count == 37)
let oneValue = AdvertisementDecoder.decode(oneValueFrame)!
precondition(oneValue.caseLevel == 44 && oneValue.a == nil && oneValue.b == nil)
precondition(oneValue.batteryCount == 1 && oneValue.partial && oneValue.token == token)

let twoValueFrame = Data(frame.prefix(26)) + data("00") + token + data("2C 58") + data("00 03 14")
precondition(twoValueFrame.count == 38)
let twoValues = AdvertisementDecoder.decode(twoValueFrame)!
precondition(twoValues.caseLevel == 44 && twoValues.a == 88 && twoValues.b == nil)
precondition(twoValues.batteryCount == 2 && twoValues.partial && twoValues.token == token)

// A learned identity also wins when the trailing bytes are not the known
// 00 03 14 suffix; the decoder must not drop the frame because of it.
let otherSuffix = Data(frame.prefix(26)) + data("00") + token + data("2C 58 58") + data("01 07 22")
let tolerant = AdvertisementDecoder.decode(otherSuffix, tokens: [token])!
precondition(tolerant.caseLevel == 44 && tolerant.a == 88 && tolerant.b == 88)
precondition(tolerant.suffix == [0x01, 0x07, 0x22])
precondition(AdvertisementDecoder.decode(otherSuffix) == nil)

// Without a learned identity only the canonical block positions are accepted.
for n in 0..<frame.count { precondition(AdvertisementDecoder.decode(Data(frame.prefix(n))) == nil) }
b = [UInt8](frame); b[36] = 1
precondition(AdvertisementDecoder.decode(Data(b)) == nil)
precondition(AdvertisementDecoder.decode(frame + Data([0])) == nil)
precondition(AdvertisementDecoder.decode(data("75 00 42 09 81 02 14 15 03 21 02 08 A2 0C 01 54 06 3C 00 00 00 00 00 00 00 00 00 5A 1E 77 C3 08 00 2C 58 58 00 03 14")) == nil)
precondition(!AdvertisementDecoder.isBudsFrame(data("4C 00 42 09 81 02 14 15 03 21 01")))
precondition(!AdvertisementDecoder.isBudsFrame(Data()))

// MARK: - Protocol (Pinna 1.0)

func frameHex(_ d: Data) -> String { hex(d) }

// Frames verified by ear on SM-R630 over the BLE data path.
precondition(frameHex(BudsCommand.noise(.off).frame) == "FD 04 00 78 00 F0 81 DD")
precondition(frameHex(BudsCommand.noise(.anc).frame) == "FD 04 00 78 01 D1 91 DD")
precondition(frameHex(BudsCommand.noise(.ambient).frame) == "FD 04 00 78 02 B2 A1 DD")
precondition(frameHex(BudsCommand.noise(.adaptive).frame) == "FD 04 00 78 03 93 B1 DD")
precondition(FrameCodec.crc16([0x26]) == 0x44A4)
precondition(frameHex(FrameCodec.encode(id: 0x26)) == "FD 03 00 26 A4 44 DD")
precondition(frameHex(FrameCodec.encode(id: 0x88, payload: data("01 01 22"))) == "FD 06 00 88 01 01 22 DA 58 DD")
precondition(frameHex(FrameCodec.encode(id: 0x78, payload: data("01"), response: true)) == "FD 04 10 78 01 D1 91 DD")
precondition(FrameCodec.encode(id: 0x78, payload: data("01"), legacy: true).first == 0xFE)
precondition(FrameCodec.encode(id: 0x78, payload: data("01"), legacy: true).last == 0xEE)

// Strict decode: wrong markers, CRC or fragments are rejected.
precondition(FrameCodec.decode(data("FD 04 00 78 01 D1 91 DD"))?.id == 0x78)
precondition(FrameCodec.decode(data("FD 04 00 78 02 D1 91 DD")) == nil)
precondition(FrameCodec.decode(data("FD 04 00 78 01 D1 91 EE")) == nil)
precondition(FrameCodec.decode(data("FD 04 20 78 01 D1 91 DD")) == nil)
precondition(FrameCodec.decode(data("FD 04 90 88 00 31 92 DD"))?.isResponse == true)

// Real RFCOMM frames from SM-R630 (fw R630XXU0AZG2).
let realStatus = data("FD 40 00 61 04 08 64 64 01 01 33 4A 00 01 FF 22 00 00 54 01 54 01 07 00 04 C5 00 04 00 10 00 01 00 00 11 02 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 01 00 02 00 01 FF 01 01 00 00 00 00 2C 5A DD")
precondition(FrameCodec.decode(realStatus)?.id == 0x61)
let realNoise = data("FD 0B C0 77 00 33 01 00 0C 05 02 02 3D 3C DD")
precondition(FrameCodec.decode(realNoise)?.payload.count == 8)

// Payload layouts from Samsung's Buds3 Pro Manager plugin.
precondition(BudsCommand.ancOneEarbud(true, padded: true).payload == data("00 00 01"))
precondition(BudsCommand.ancOneEarbud(true, padded: false).payload == data("01"))
precondition(BudsCommand.seamless(true).payload == data("00"))
precondition(BudsCommand.inEarCalls(true).payload == data("00"))
precondition(BudsCommand.ancLevel(9, levels: 5).payload == data("04"))
precondition(BudsCommand.ambientLevel(-2, levels: 3).payload == data("00"))
precondition(BudsCommand.balance(40).payload == data("20"))
var touch = TouchSettings()
touch.enabled = false
precondition(BudsCommand.touch(touch, layout: .advancedLighting).payload == data("00 01 01 01 01 01 01 01 01 00"))
precondition(BudsCommand.touch(touch, layout: .advanced).payload == data("00 01 01 01 01 01 01"))
precondition(BudsCommand.touch(touch, layout: .single).payload == data("01"))

// Pinch-and-hold noise modes (0x79): left ANC+off, right ambient+off.
precondition(frameHex(BudsCommand.touchHoldNoiseModes(left: [.anc, .off], right: [.ambient, .off]).frame) == "FD 05 00 79 0C 05 51 53 DD")
precondition(BudsCommand.noiseModeMask([.anc, .off, .adaptive, .ambient]) == 0x0F)

// Custom equalizer (0x89): [9, bands…], signed −10…+10, clamped.
precondition(frameHex(BudsCommand.customEqualizer([1, -1, 0, 0, 0, 0, 0, 0, 14]).frame) == "FD 0D 00 89 09 01 FF 00 00 00 00 00 00 0A 45 08 DD")
precondition(BudsCommand.equalizer(6).payload == data("06"))
precondition(BudsModel.detect(modelNumber: "SM-R630").has(.customEqualizer))

// Model detection.
precondition(BudsModel.detect(modelNumber: "SM-R630").id == "buds3pro")
precondition(BudsModel.detect(modelNumber: "SM-R530").id == "buds3")
precondition(BudsModel.detect(modelNumber: nil, name: "Galaxy Buds3 Pro (A1B2)").id == "buds3pro")
precondition(BudsModel.detect(modelNumber: nil, name: "Buds3 (A1B2)").id == "buds3")
precondition(BudsModel.detect(modelNumber: nil, name: "My Earbuds").id == "unknown")
precondition(BudsModel.detect(colorID: 340).id == "buds3pro")
precondition(AdvertisementDecoder.modelColorID(frame) == 340)
precondition(Set(BudsModel.all.map(\.id)).count == BudsModel.all.count)
for m in BudsModel.all { precondition(m.noiseModes.first == .off) }

print("Pinna protocol, model and advertisement tests passed")
