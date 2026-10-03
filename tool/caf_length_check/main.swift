// Checks ios/Runner/GaplessCaf.swift on this Mac: every caf it writes must
// hold exactly the frames ffmpeg decodes from the same source, starting at
// the same sample. Run through tool/caf_length_check.sh.
//
// Usage: caf_length_check <out-dir> <source> <expected.f32> [<source> <expected.f32> ...]
// Each expected file is ffmpeg's mono float32 decode of its source at the
// source's own rate, with the encoder delay and padding removed.

import AVFoundation
import Foundation

var failures = 0

func check(_ ok: Bool, _ message: String) {
  print("\(ok ? "PASS" : "FAIL")  \(message)")
  if !ok { failures += 1 }
}

func readFloats(_ url: URL) -> [Float] {
  let data = (try? Data(contentsOf: url)) ?? Data()
  return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
}

func readCaf(_ url: URL) -> (frames: Int64, rate: Double, samples: [Float])? {
  guard let file = try? AVAudioFile(forReading: url),
        let buffer = AVAudioPCMBuffer(
          pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))
  else { return nil }
  do { try file.read(into: buffer) } catch { return nil }
  let channel = buffer.floatChannelData![0]
  return (file.length, file.fileFormat.sampleRate,
          Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength))))
}

/// The largest sample difference between [a] and [b] at the same index,
/// over the whole file. A caf that starts late or early, even by a whole
/// number of periods of a steady tone, differs where the sound begins and
/// ends. Two decoders of the same lossy stream differ by far less.
func maxError(_ a: [Float], _ b: [Float]) -> Float {
  var worst: Float = 0
  for i in 0..<min(a.count, b.count) { worst = max(worst, abs(a[i] - b[i])) }
  return worst
}

/// The same, with [b] shifted by [lag] frames, to show what a wrong trim
/// would look like.
func maxError(_ a: [Float], _ b: [Float], lag: Int) -> Float {
  var worst: Float = 0
  for i in 0..<a.count where i + lag >= 0 && i + lag < b.count { worst = max(worst, abs(a[i] - b[i + lag])) }
  return worst
}

// Pure logic first.
check(GaplessTrim.validRange(length: 707_328, delay: 576, padding: 1152) == 576..<705_600 + 576,
      "trim: 707328 decoded, delay 576, padding 1152 keeps 705600")
check(GaplessTrim.validRange(length: 100, delay: 80, padding: 40) == 0..<100,
      "trim: counts larger than the decode are ignored")
check(GaplessTrim.clipRange(valid: 576..<706_176, sampleRate: 44_100, start: 1, end: 2) == 44_676..<88_776,
      "clip: 1 s to 2 s is measured from the first real frame")
check(GaplessTrim.clipRange(valid: 0..<100, sampleRate: 100, start: 0.5, end: 9) == 50..<100,
      "clip: an end past the sound stops at the sound")
check(GaplessTrim.fadeGain(index: 0, count: 100, fadeFrames: 10) == 0
      && GaplessTrim.fadeGain(index: 50, count: 100, fadeFrames: 10) == 1
      && GaplessTrim.fadeGain(index: 99, count: 100, fadeFrames: 10) == 0
      && GaplessTrim.fadeGain(index: 5, count: 100, fadeFrames: 0) == 1,
      "fade: silent at both ends, untouched in the middle and with no fade")

/// Largest sample difference allowed against ffmpeg, full scale 1.
let maxAllowedError: Float = 0.01

check(Mp3Gapless.id3v2Length(of: Data([0x49, 0x44, 0x33, 3, 0, 0, 0x00, 0x12, 0x7F, 0x7F])) == 10 + 311_295,
      "id3: syncsafe size read from the header")
check(Mp3Gapless.id3v2Length(of: Data([0xFF, 0xFB, 0x90, 0xC4])) == 0, "id3: no tag is length 0")

let args = Array(CommandLine.arguments.dropFirst())
let outDir = URL(fileURLWithPath: args[0])
var pairs = args.dropFirst()
while pairs.count >= 2 {
  let source = URL(fileURLWithPath: pairs.removeFirst())
  let expected = readFloats(URL(fileURLWithPath: pairs.removeFirst()))
  let name = source.lastPathComponent
  let destination = outDir.appendingPathComponent(name + ".caf")
  guard GaplessCaf.convert(source: source, destination: destination),
        let caf = readCaf(destination) else {
    check(false, "\(name): convert failed")
    continue
  }
  let sourceRate = (try? AVAudioFile(forReading: source))?.fileFormat.sampleRate ?? 0
  let error = maxError(caf.samples, expected)
  let shifted = maxError(caf.samples, expected, lag: 576)
  check(caf.frames == Int64(expected.count) && caf.rate == sourceRate && error < maxAllowedError,
        "\(name): caf \(caf.frames) frames at \(Int(caf.rate)) Hz, ffmpeg \(expected.count) at \(Int(sourceRate)) Hz, "
          + String(format: "max error %.4f (%.4f if 576 frames off)", error, shifted))
}

// A cut keeps exactly the frames asked for.
if let first = args.dropFirst().first {
  let source = URL(fileURLWithPath: first)
  let destination = outDir.appendingPathComponent("cut.caf")
  let rate = (try? AVAudioFile(forReading: source))?.fileFormat.sampleRate ?? 0
  let ok = GaplessCaf.convert(source: source, destination: destination, start: 1, end: 3)
  let frames = readCaf(destination)?.frames ?? -1
  check(ok && frames == Int64(2 * rate), "cut: 1 s to 3 s of \(source.lastPathComponent) is \(frames) frames, want \(Int64(2 * rate))")
}

print(failures == 0 ? "ALL PASS" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
