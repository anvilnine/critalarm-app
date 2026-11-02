import Foundation

/// Native strings in the language picked inside the app.
///
/// Dart writes the pick to the app group (`setAppLocale` in
/// lib/core/l10n/native_locale_bridge.dart), so the app, the notification
/// extension and the widget extension all read the same answer. Each of them
/// carries the `Native` table, generated from the `native` group of the
/// translations by tool/l10n_native.dart.
///
/// The lookup, in order:
/// 1. The picked language's table, when the bundle has it.
/// 2. The phone's own language, the way iOS picks a localization.
/// 3. The English compiled into `NativeText`, so a bundle with no table at
///    all still shows words, never a key.
///
/// Nothing here throws, and every read is a plain defaults read and a bundle
/// lookup: it runs on the alarm path, at 3 a.m., with no app running.
enum NativeL10n {
    static let appGroup = "group.app.critalarm"

    /// A BCP 47 tag such as `de` or `pt-BR`. Missing means System default.
    static let tagKey = "app_locale"

    static let table = "Native"

    /// The debug pseudo-locale. Debug builds fake it from the English, so it
    /// needs no table and never ships.
    static let pseudoTag = "en-XA"

    static var groupDefaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    /// The tag Dart last wrote, or nil for System default.
    static func pickedTag(in defaults: UserDefaults? = groupDefaults) -> String? {
        guard let tag = defaults?.string(forKey: tagKey)?
            .trimmingCharacters(in: .whitespaces), !tag.isEmpty
        else { return nil }
        return tag
    }

    /// Stores the pick. Nil, or an empty tag, goes back to System default.
    static func write(tag: String?, to defaults: UserDefaults?) {
        if let tag, !tag.isEmpty {
            defaults?.set(tag, forKey: tagKey)
        } else {
            defaults?.removeObject(forKey: tagKey)
        }
    }

    /// [id] in the picked language with each `{name}` in it replaced.
    static func text(_ id: NativeText, _ args: [String: String] = [:]) -> String {
        text(id, args, tag: pickedTag(), bundle: .main)
    }

    /// The same, with the pick and the bundle handed in, for the tests.
    static func text(
        _ id: NativeText,
        _ args: [String: String],
        tag: String?,
        bundle: Bundle
    ) -> String {
        fill(template(id, tag: tag, bundle: bundle), args)
    }

    /// The words before and after one `{name}` in [id], for a SwiftUI line
    /// that puts a live timer or a relative date in that place.
    static func around(_ id: NativeText, placeholder: String) -> (before: String, after: String) {
        around(template(id, tag: pickedTag(), bundle: .main), placeholder: placeholder)
    }

    static func around(_ template: String, placeholder: String) -> (before: String, after: String) {
        guard let range = template.range(of: "{\(placeholder)}") else { return (template, "") }
        return (String(template[..<range.lowerBound]), String(template[range.upperBound...]))
    }

    static func template(_ id: NativeText, tag: String?, bundle: Bundle) -> String {
        #if DEBUG
        if tag == pseudoTag { return pseudo(id.english) }
        #endif
        if let tag, let picked = localization(for: tag, in: bundle),
           let value = lookup(id.rawValue, in: picked) {
            return value
        }
        return lookup(id.rawValue, in: bundle) ?? id.english
    }

    /// The `.lproj` bundle for [tag]: the tag itself (`pt-BR`), then its
    /// underscore spelling, then its language alone (`pt`).
    static func localization(for tag: String, in bundle: Bundle) -> Bundle? {
        let language = String(tag.split(whereSeparator: { $0 == "-" || $0 == "_" }).first ?? "")
        let names = [tag, tag.replacingOccurrences(of: "-", with: "_"), language]
        for name in names where !name.isEmpty {
            if let path = bundle.path(forResource: name, ofType: "lproj"),
               let found = Bundle(path: path) {
                return found
            }
        }
        return nil
    }

    private static let missing = "\u{0}missing"

    private static func lookup(_ key: String, in bundle: Bundle) -> String? {
        let value = bundle.localizedString(forKey: key, value: missing, table: table)
        return value == missing || value.isEmpty ? nil : value
    }

    static func fill(_ template: String, _ args: [String: String]) -> String {
        var out = template
        for (name, value) in args {
            out = out.replacingOccurrences(of: "{\(name)}", with: value)
        }
        return out
    }

    #if DEBUG
    /// The same transform as tool/l10n_pseudo.dart: accented letters inside
    /// brackets, padded to 140 percent with `~`, placeholders and keep words
    /// left as they are.
    static func pseudo(_ value: String) -> String {
        let plain = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
        let accented = Array("ÅƁÇÐÉƑĜĤÎĴĶĻḾÑÖÞǪŔŠŢÛṼŴẊÝŽåƀçðéƒĝĥîĵķļḿñöþǫŕšţûṽŵẋýž")
        func accent(_ text: Substring) -> String {
            String(text.map { letter in
                plain.firstIndex(of: letter).map { accented[$0] } ?? letter
            })
        }
        let words = keepWords.sorted { $0.count > $1.count }
        let pattern = ([#"\{([A-Za-z_][A-Za-z0-9_]*)?\}"#]
            + words.map { #"(?<![A-Za-z0-9_])"# + NSRegularExpression.escapedPattern(for: $0) + #"(?![A-Za-z0-9_])"# })
            .joined(separator: "|")
        var result = "["
        var offset = value.startIndex
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let all = NSRange(value.startIndex..., in: value)
            for match in regex.matches(in: value, range: all) {
                guard let range = Range(match.range, in: value) else { continue }
                result += accent(value[offset..<range.lowerBound]) + value[range]
                offset = range.upperBound
            }
        }
        result += accent(value[offset...])
        let target = Int((Double(value.utf16.count) * 1.4).rounded(.up))
        let padding = target - result.utf16.count - 1
        if padding > 0 { result += String(repeating: "~", count: padding) }
        return result + "]"
    }
    #endif
}
