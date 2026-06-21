import CoreGraphics

/// Sizing derived from the tray's available area. Pure — no SwiftUI.
struct TrayCellMetrics: Equatable {
    let cell: CGFloat
    let symbolFont: CGFloat
    let cornerFont: CGFloat
    let showCornerNumbers: Bool
}

/// Compute the per-cell size that fits `columns` × `rows` into width × height,
/// plus the font sizes derived from it. `cell` is clamped to `minCell`.
/// Corner atomic/mass numbers are hidden when `cell < cornerThreshold`.
func trayCellMetrics(width: CGFloat, height: CGFloat,
                     columns: Int = 18, rows: Int = 9,
                     spacing: CGFloat = 2, minCell: CGFloat = 18,
                     cornerThreshold: CGFloat = 28) -> TrayCellMetrics {
    let widthFit = (width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
    let heightFit = (height - CGFloat(rows - 1) * spacing) / CGFloat(rows)
    let cell = max(minCell, floor(min(widthFit, heightFit)))
    return TrayCellMetrics(
        cell: cell,
        symbolFont: cell * 0.37,             // preserves today's 14/38 ratio
        cornerFont: max(5, cell * 0.18),
        showCornerNumbers: cell >= cornerThreshold
    )
}
