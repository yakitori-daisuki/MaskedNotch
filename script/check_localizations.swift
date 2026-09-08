// Invoked inside a matching bundle by script/test_localizations.py.
// Uses a process-only -AppleLanguages override.
// No app launch, screen access, or saved preference changes.
import Foundation

let args = CommandLine.arguments
guard args.count >= 3, let bundle = Bundle(path: args[1]) else {
    fatalError("Usage: check_localizations.swift APP_PATH EXPECTED_LANGUAGE -AppleLanguages '(ja-JP)'")
}
let expected = args[2]
precondition(bundle.preferredLocalizations.first == expected,
             "Unexpected language: \(bundle.preferredLocalizations)")
func strings(_ language: String) throws -> [String: String] {
    let url = bundle.resourceURL!.appendingPathComponent("\(language).lproj/Localizable.strings")
    return try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as! [String: String]
}
let english = try strings("en")
let japanese = try strings("ja")
precondition(!english.isEmpty && Set(english.keys) == Set(japanese.keys), "Missing translations")
let placeholders = try NSRegularExpression(pattern: "%[@d]")
func formats(_ text: String) -> [String] {
    placeholders.matches(in: text, range: NSRange(text.startIndex..., in: text)).map {
        String(text[Range($0.range, in: text)!])
    }
}
for (key, value) in english {
    precondition(!japanese[key]!.isEmpty && formats(value) == formats(japanese[key]!), "Invalid translation: \(key)")
    precondition(bundle.localizedString(forKey: key, value: nil, table: nil) == (expected == "ja" ? japanese[key]! : value), "Lookup failed: \(key)")
}
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let matcher = try NSRegularExpression(pattern: #"NSLocalizedString\("((?:\\.|[^"\\])*)""#)
for case let url as URL in FileManager.default.enumerator(at: root.appendingPathComponent("Sources"), includingPropertiesForKeys: nil)! where url.pathExtension == "swift" {
    let source = try String(contentsOf: url, encoding: .utf8)
    for match in matcher.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
        let literal = String(source[Range(match.range(at: 1), in: source)!])
        let key = try JSONDecoder().decode(String.self, from: Data(("\"" + literal + "\"").utf8))
        precondition(english[key] != nil, "Untranslated source key: \(key)")
    }
}
print("PASS: \(expected), \(english.count) translations, placeholders and source coverage")
