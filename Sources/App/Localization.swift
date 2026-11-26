import Foundation

/// Localised string. The English text is the key, so a missing translation
/// simply shows English. `%@` / `%ld` placeholders are filled from `args`.
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, comment: "")
    return args.isEmpty ? format : String(format: format, arguments: args)
}
