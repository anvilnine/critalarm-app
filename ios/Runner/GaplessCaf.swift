import AVFoundation
import Foundation

/// Encoder delay and padding of an MP3, read from its Xing or Info frame.
///
/// LAME and ffmpeg write both counts into the LAME extension of that frame.
/// Core Audio removes the decoder's own 529-sample delay but never reads
/// these two, so an MP3 decoded on iOS starts [delay] frames late and runs
/// [padding] frames long. See http://gabriel.mp3-tech.org/mp3infotag.html.
struct Mp3Gapless: Equatable {
  let delay: Int
  let padding: Int

  /// The counts from the first audio frame of [data], or nil when there is
  /// no Xing/Info frame with a LAME extension.
  static func read(from data: Data) -> Mp3Gapless? {
    // An ID3v2 tag comes first, and cover art can make it megabytes long,
    // so the first frame is looked for in the 256 KB after the tag.
    let tag = id3v2Length(of: data)
    guard tag < data.count else { return nil }
    let start = data.startIndex + tag
    let bytes = [UInt8](data[start..<min(data.endIndex, start + 256 * 1024)])
    var at = 0
    while at + 4 <= bytes.count {
      if let info = frameAt(at, in: bytes) { return info.gapless }
      at += 1
    }
    return nil
  }

  /// Bytes taken by an ID3v2 tag at the start of [data]: a 10-byte header,
  /// a syncsafe size and an optional 10-byte footer. Zero when there is none.
  static func id3v2Length(of data: Data) -> Int {
    let head = [UInt8](data.prefix(10))
    guard head.count == 10, head[0] == 0x49, head[1] == 0x44, head[2] == 0x33 else { return 0 }
    let size = (Int(head[6] & 0x7F) << 21) | (Int(head[7] & 0x7F) << 14)
      | (Int(head[8] & 0x7F) << 7) | Int(head[9] & 0x7F)
    let footer = head[5] & 0x10 != 0 ? 10 : 0
    return 10 + size + footer
  }

  private struct Header {
    let gapless: Mp3Gapless?
  }

  /// A valid Layer III frame header at [at], and the gapless counts in it.
  /// Nil when [at] is not a frame header.
  private static func frameAt(_ at: Int, in bytes: [UInt8]) -> Header? {
    let b1 = bytes[at + 1], b2 = bytes[at + 2], b3 = bytes[at + 3]
    guard bytes[at] == 0xFF, b1 & 0xE0 == 0xE0 else { return nil }
    let version = (b1 >> 3) & 0x3 // 3 = MPEG 1, 2 = MPEG 2, 0 = MPEG 2.5
    let layer = (b1 >> 1) & 0x3 // 1 = Layer III
    let bitrate = b2 >> 4
    let rate = (b2 >> 2) & 0x3
    guard version != 1, layer == 1, bitrate != 0, bitrate != 0xF, rate != 3 else { return nil }
    let mono = (b3 >> 6) == 3
    let sideInfo = version == 3 ? (mono ? 17 : 32) : (mono ? 9 : 17)
    let crc = b1 & 0x1 == 0 ? 2 : 0
    for offset in Set([4 + sideInfo, 4 + sideInfo + crc]).sorted() {
      if let gapless = lameCounts(at: at + offset, in: bytes) { return Header(gapless: gapless) }
    }
    // The first real frame has no Xing/Info tag: a plain CBR file.
    return Header(gapless: nil)
  }

  private static func lameCounts(at tag: Int, in bytes: [UInt8]) -> Mp3Gapless? {
    guard tag + 8 <= bytes.count else { return nil }
    let name = String(bytes: bytes[tag..<tag + 4], encoding: .ascii)
    guard name == "Xing" || name == "Info" else { return nil }
    let flags = (Int(bytes[tag + 4]) << 24) | (Int(bytes[tag + 5]) << 16)
      | (Int(bytes[tag + 6]) << 8) | Int(bytes[tag + 7])
    var lame = tag + 8
    if flags & 0x1 != 0 { lame += 4 } // frame count
    if flags & 0x2 != 0 { lame += 4 } // byte count
    if flags & 0x4 != 0 { lame += 100 } // seek table
    if flags & 0x8 != 0 { lame += 4 } // quality
    guard lame + 24 <= bytes.count else { return nil }
    // The extension opens with the encoder name, "LAME3.100" or "Lavc62.28".
    // A Xing frame from an encoder that wrote no extension has zeros there.
    let first = bytes[lame]
    guard first >= 0x20, first < 0x7F else { return nil }
    let d0 = Int(bytes[lame + 21]), d1 = Int(bytes[lame + 22]), d2 = Int(bytes[lame + 23])
    return Mp3Gapless(delay: (d0 << 4) | (d1 >> 4), padding: ((d1 & 0xF) << 8) | d2)
  }
}

/// The frame arithmetic behind [GaplessCaf], apart from any file.
enum GaplessTrim {
  /// The frames of a decode [length] long that are the real sound, once
  /// [delay] is cut from the front and [padding] from the end. Counts that
  /// would leave nothing are ignored and the whole decode is kept.
  static func validRange(length: Int64, delay: Int, padding: Int) -> Range<Int64> {
    let start = Int64(max(0, delay))
    let end = length - Int64(max(0, padding))
    guard start < end else { return 0..<max(0, length) }
    return start..<end
  }

  /// The part of [valid] from [start] to [end] seconds, measured from the
  /// first real frame. Nil for either end means that end of [valid].
  static func clipRange(
    valid: Range<Int64>, sampleRate: Double, start: Double?, end: Double?
  ) -> Range<Int64> {
    func frame(_ seconds: Double) -> Int64 {
      let at = valid.lowerBound + Int64((seconds * sampleRate).rounded())
      return min(max(at, valid.lowerBound), valid.upperBound)
    }
    let from = start.map(frame) ?? valid.lowerBound
    let to = end.map(frame) ?? valid.upperBound
    return from < to ? from..<to : from..<from
  }

  /// Gain for frame [index] of [count]: a straight ramp up over the first
  /// [fadeFrames] and down over the last, 1 in between. No fade when
  /// [fadeFrames] is 0.
  static func fadeGain(index: Int64, count: Int64, fadeFrames: Int64) -> Float {
    guard fadeFrames > 0 else { return 1 }
    let up = Float(index) / Float(fadeFrames)
    let down = Float(count - 1 - index) / Float(fadeFrames)
    return min(1, max(0, min(up, down)))
  }
}

/// Writes a sound as 16-bit mono LPCM caf at the source's own sample rate,
/// exactly as long as the decoded source.
///
/// Reads through `AVAudioFile` (ExtAudioFile), which honours the priming and
/// remainder of AAC in m4a, whether written by Apple's encoder or by ffmpeg.
/// MP3 delay and padding come from [Mp3Gapless]. WAV, AIFF and caf have
/// neither. `UNNotificationSound` plays LPCM caf at any of these rates.
enum GaplessCaf {
  /// The caf format: LPCM 16-bit mono at [sampleRate].
  static func settings(sampleRate: Double) -> [String: Any] {
    [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: sampleRate,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
    ]
  }

  /// Converts [source] into [destination]. With [start] or [end] (seconds
  /// from the first real frame) only that part is written, with a
  /// [fadeSeconds] ramp at each end so the cut does not click.
  ///
  /// False when `AVAudioFile` cannot read the source or anything fails, and
  /// then nothing is left at [destination].
  static func convert(
    source: URL, destination: URL, start: Double? = nil, end: Double? = nil,
    fadeSeconds: Double = 0.05
  ) -> Bool {
    try? FileManager.default.removeItem(at: destination)
    let ok = write(source: source, destination: destination, start: start, end: end, fadeSeconds: fadeSeconds)
    if !ok { try? FileManager.default.removeItem(at: destination) }
    return ok
  }

  /// Frames of the real sound in [source] when converted whole, or nil when
  /// it cannot be read.
  static func validFrames(of source: URL) -> Range<Int64>? {
    guard let input = try? AVAudioFile(forReading: source) else { return nil }
    return validRange(of: input, at: source)
  }

  private static func validRange(of input: AVAudioFile, at source: URL) -> Range<Int64> {
    var gapless: Mp3Gapless?
    if input.fileFormat.streamDescription.pointee.mFormatID == kAudioFormatMPEGLayer3,
       let data = try? Data(contentsOf: source, options: .mappedIfSafe) {
      gapless = Mp3Gapless.read(from: data)
    }
    return GaplessTrim.validRange(
      length: input.length, delay: gapless?.delay ?? 0, padding: gapless?.padding ?? 0
    )
  }

  private static func write(
    source: URL, destination: URL, start: Double?, end: Double?, fadeSeconds: Double
  ) -> Bool {
    guard let input = try? AVAudioFile(forReading: source) else { return false }
    let rate = input.fileFormat.sampleRate
    guard rate > 0 else { return false }
    let valid = validRange(of: input, at: source)
    let span = GaplessTrim.clipRange(valid: valid, sampleRate: rate, start: start, end: end)
    let total = span.upperBound - span.lowerBound
    guard total > 0 else { return false }
    let isCut = start != nil || end != nil
    let fadeFrames = isCut ? Int64((fadeSeconds * rate).rounded()) : 0

    let chunk: AVAudioFrameCount = 8192
    guard let mono = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 1, interleaved: false),
          let inBuffer = AVAudioPCMBuffer(pcmFormat: input.processingFormat, frameCapacity: chunk),
          let outBuffer = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: chunk),
          let output = try? AVAudioFile(
            forWriting: destination, settings: settings(sampleRate: rate),
            commonFormat: .pcmFormatFloat32, interleaved: false)
    else { return false }

    let channels = Int(input.processingFormat.channelCount)
    var done: Int64 = 0
    do {
      input.framePosition = span.lowerBound
      while done < total {
        let want = AVAudioFrameCount(min(Int64(chunk), total - done))
        try input.read(into: inBuffer, frameCount: want)
        let got = Int(inBuffer.frameLength)
        guard got > 0, let from = inBuffer.floatChannelData, let to = outBuffer.floatChannelData?[0]
        else { break }
        for i in 0..<got {
          var sum: Float = 0
          for c in 0..<channels { sum += from[c][i] }
          let gain = GaplessTrim.fadeGain(index: done + Int64(i), count: total, fadeFrames: fadeFrames)
          to[i] = sum / Float(channels) * gain
        }
        outBuffer.frameLength = AVAudioFrameCount(got)
        try output.write(from: outBuffer)
        done += Int64(got)
      }
    } catch {
      NSLog("CritAlarmSound: caf_write_failed path=%@ error=%@", destination.path, "\(error)")
      return false
    }
    if done != total {
      NSLog("CritAlarmSound: caf_short path=%@ wrote=%lld wanted=%lld", destination.path, done, total)
      return false
    }
    return true
  }
}
