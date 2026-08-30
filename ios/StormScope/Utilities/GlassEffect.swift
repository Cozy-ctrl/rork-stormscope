import SwiftUI

extension View {
    /// Applies the iOS 26 Liquid Glass material to floating controls
    /// (toolbars, pills, action bars), falling back to an ultra-thin material
    /// on earlier OS versions so nothing breaks below iOS 26.
    ///
    /// Glass is deliberately reserved for the navigation/control layer —
    /// content cards keep their solid surfaces for legibility.
    @ViewBuilder
    func stormGlass<S: Shape>(in shape: S, interactive: Bool = false, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            let glass = Self.glassVariant(interactive: interactive, tint: tint)
            self.glassEffect(glass, in: shape)
        } else if let tint {
            self.background(tint.opacity(0.14), in: shape)
                .overlay(shape.stroke(tint.opacity(0.25), lineWidth: 1))
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }

    @available(iOS 26.0, *)
    private static func glassVariant(interactive: Bool, tint: Color?) -> Glass {
        var glass = Glass.regular
        if let tint {
            glass = glass.tint(tint)
        }
        if interactive {
            glass = glass.interactive()
        }
        return glass
    }
}
