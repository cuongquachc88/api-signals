import SwiftUI
import AppKit

// MARK: - Color Palette

public extension Color {
    // HTTP Methods
    static let dsGET     = Color(hex: "#3FB950")
    static let dsPOST    = Color(hex: "#F0883E")
    static let dsPUT     = Color(hex: "#79C0FF")
    static let dsDELETE  = Color(hex: "#FF7B72")
    static let dsPATCH   = Color(hex: "#D2A8FF")
    static let dsHEAD    = Color(hex: "#A5D6FF")
    static let dsOPTIONS = Color(hex: "#FFA657")

    // Status
    static let dsSuccess = Color(hex: "#3FB950")
    static let dsWarning = Color(hex: "#D29922")
    static let dsError   = Color(hex: "#FF7B72")
    static let dsInfo    = Color(hex: "#79C0FF")

    // Semantic backgrounds (adaptive — works in both dark & light)
    static var dsBg: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.name == .darkAqua || appearance.name == .vibrantDark
                ? NSColor(hex: "#0D1117")
                : NSColor(hex: "#ECEEF1")  // slightly cool grey — main canvas
        })
    }

    static var dsSurf: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.name == .darkAqua || appearance.name == .vibrantDark
                ? NSColor(hex: "#161B22")
                : NSColor(hex: "#FFFFFF")  // card / panel surface
        })
    }

    static var dsSurfEl: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.name == .darkAqua || appearance.name == .vibrantDark
                ? NSColor(hex: "#21262D")
                : NSColor(hex: "#E6E8EB")  // element inside surface
        })
    }

    static var dsBord: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.name == .darkAqua || appearance.name == .vibrantDark
                ? NSColor(hex: "#30363D")
                : NSColor(hex: "#C4C8CE")  // stronger border in light mode
        })
    }

    static var dsTextPrim: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.name == .darkAqua || appearance.name == .vibrantDark
                ? NSColor(hex: "#E6EDF3")
                : NSColor(hex: "#1F2328")
        })
    }

    static var dsTextSec: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.name == .darkAqua || appearance.name == .vibrantDark
                ? NSColor(hex: "#7D8590")
                : NSColor(hex: "#656D76")
        })
    }

    static var dsAcc: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.name == .darkAqua || appearance.name == .vibrantDark
                ? NSColor(hex: "#2F81F7")
                : NSColor(hex: "#0969DA")
        })
    }

    static var dsTextTertiary: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.name == .darkAqua || appearance.name == .vibrantDark
                ? NSColor(hex: "#484F58")
                : NSColor(hex: "#8C959F")
        })
    }

    // Aliases for clarity
    static var dsBackground: Color { dsBg }
    static var dsSurface: Color { dsSurf }
    static var dsBorder: Color { dsBord }
    static var dsTextPrimary: Color { dsTextPrim }
    static var dsTextSecondary: Color { dsTextSec }
    static var dsAccent: Color { dsAcc }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8)  & 0xFF) / 255
        let b = CGFloat(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - Method Color

public extension HTTPMethod {
    var color: Color {
        switch self {
        case .get:     return .dsGET
        case .post:    return .dsPOST
        case .put:     return .dsPUT
        case .delete:  return .dsDELETE
        case .patch:   return .dsPATCH
        case .head:    return .dsHEAD
        case .options: return .dsOPTIONS
        default:       return .dsTextSec
        }
    }
}

// MARK: - Spacing

public enum DS {
    public enum Spacing {
        public static let xs:   CGFloat = 4
        public static let sm:   CGFloat = 8
        public static let md:   CGFloat = 12
        public static let lg:   CGFloat = 16
        public static let xl:   CGFloat = 24
        public static let xxl:  CGFloat = 32
    }

    public enum Radius {
        public static let xs:  CGFloat = 4
        public static let sm:  CGFloat = 6
        public static let md:  CGFloat = 8
        public static let lg:  CGFloat = 12
        public static let pill: CGFloat = 100
    }

    public enum Font {
        public static let caption   = SwiftUI.Font.system(size: 11, weight: .regular)
        public static let captionMono = SwiftUI.Font.system(size: 11, weight: .regular, design: .monospaced)
        public static let body      = SwiftUI.Font.system(size: 13, weight: .regular)
        public static let bodyMono  = SwiftUI.Font.system(size: 12, weight: .regular, design: .monospaced)
        public static let labelSm   = SwiftUI.Font.system(size: 11, weight: .medium)
        public static let label     = SwiftUI.Font.system(size: 13, weight: .medium)
        public static let labelLg   = SwiftUI.Font.system(size: 14, weight: .semibold)
        public static let title     = SwiftUI.Font.system(size: 15, weight: .semibold)
        public static let urlBar    = SwiftUI.Font.system(size: 13, weight: .regular, design: .monospaced)
    }

}

// MARK: - Status Code Color

public func statusCodeColor(_ code: Int) -> Color {
    switch code {
    case 100..<200: return .dsInfo
    case 200..<300: return .dsSuccess
    case 300..<400: return .dsWarning
    case 400..<600: return .dsError
    default:        return .dsTextSec
    }
}

// MARK: - Shadow struct helper (not in SwiftUI)

public struct Shadow {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat
}

// MARK: - View Modifiers

public struct DSCardStyle: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background(Color.dsSurf)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(Color.dsBord, lineWidth: 1)
            )
    }
}

public struct DSRowHover: ViewModifier {
    @State private var isHovered = false
    public func body(content: Content) -> some View {
        content
            .background(isHovered ? Color.dsBord.opacity(0.5) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
            .onHover { isHovered = $0 }
    }
}

public extension View {
    func dsCard() -> some View { modifier(DSCardStyle()) }
    func dsRowHover() -> some View { modifier(DSRowHover()) }
}

// MARK: - Method Badge

public struct MethodBadge: View {
    let method: HTTPMethod
    var compact: Bool = false

    public var body: some View {
        Text(method.rawValue)
            .font(compact ? DS.Font.captionMono : DS.Font.labelSm)
            .fontWeight(.bold)
            .foregroundStyle(method.color)
            .padding(.horizontal, compact ? 4 : 6)
            .padding(.vertical, compact ? 1 : 3)
            .background(method.color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
    }
}

// MARK: - Status Badge

public struct StatusBadgeDS: View {
    let code: Int

    public var body: some View {
        let color = statusCodeColor(code)
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(code) \(statusText)")
                .font(DS.Font.label)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var statusText: String {
        HTTPURLResponse.localizedString(forStatusCode: code)
            .split(separator: " ")
            .prefix(2)
            .joined(separator: " ")
    }
}

// MARK: - Section Header

public struct DSSectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionIcon: String = "plus"

    public var body: some View {
        HStack {
            Text(title.uppercased())
                .font(DS.Font.labelSm)
                .foregroundStyle(Color.dsTextSec)
                .tracking(0.5)
            Spacer()
            if let action {
                Button(action: action) {
                    Image(systemName: actionIcon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.dsTextSec)
                }
                .buttonStyle(.plain)
                .frame(width: 20, height: 20)
                .dsRowHover()
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
    }
}

// MARK: - Divider

public struct DSDivider: View {
    public var body: some View {
        Rectangle()
            .fill(Color.dsBord)
            .frame(height: 1)
    }
}

// MARK: - NSColor APISignalsCore import bridge

import APISignalsCore
