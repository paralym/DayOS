import SwiftUI

enum TerminalTheme {
    // MARK: - Colors
    static let background = Color(red: 0.02, green: 0.04, blue: 0.02)
    static let surface = Color(red: 0.05, green: 0.09, blue: 0.05)
    static let border = Color(red: 0.12, green: 0.35, blue: 0.12)
    static let borderDim = Color(red: 0.07, green: 0.18, blue: 0.07)

    static let primary = Color(red: 0.18, green: 0.98, blue: 0.18)      // phosphor green
    static let primaryDim = Color(red: 0.08, green: 0.45, blue: 0.08)
    static let cyan = Color(red: 0.0, green: 0.88, blue: 0.88)
    static let amber = Color(red: 1.0, green: 0.72, blue: 0.0)
    static let red = Color(red: 1.0, green: 0.22, blue: 0.22)
    static let purple = Color(red: 0.75, green: 0.18, blue: 1.0)

    // MARK: - Fonts
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static let header = Font.system(size: 13, weight: .bold, design: .monospaced)
    static let body = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let small = Font.system(size: 11, weight: .regular, design: .monospaced)
    static let micro = Font.system(size: 9, weight: .regular, design: .monospaced)

    // MARK: - Layout
    static let hourHeight: CGFloat = 80
    static let timeColumnWidth: CGFloat = 52
    static let windowWidth: CGFloat = 500
    static let windowHeight: CGFloat = 720
}

// MARK: - View Modifiers
extension View {
    func glowEffect(_ color: Color = TerminalTheme.primary, radius: CGFloat = 3) -> some View {
        self.shadow(color: color.opacity(0.7), radius: radius, x: 0, y: 0)
    }

    func terminalBorder(_ color: Color = TerminalTheme.border, width: CGFloat = 1) -> some View {
        self.overlay(Rectangle().stroke(color, lineWidth: width))
    }

    func pixelCard() -> some View {
        self
            .background(TerminalTheme.surface)
            .terminalBorder()
    }
}

// MARK: - Scanline Overlay
struct ScanlineOverlay: View {
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                    with: .color(.black.opacity(0.12))
                )
                y += 3
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - Blinking Cursor
struct BlinkingCursor: View {
    @State private var visible = true
    var color: Color = TerminalTheme.primary
    var width: CGFloat = 8
    var height: CGFloat = 13

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: width, height: height)
            .glowEffect(color)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}
