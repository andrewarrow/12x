import SwiftUI

// Simple structure to hold colors for each month
struct MonthColors {
    // Array of color pairs for each month (1-based indexing)
    static let colors: [(primary: Color, secondary: Color)] = [
        // January - Light blue (Winter)
        (primary: Color(red: 0.53, green: 0.81, blue: 0.92),
         secondary: Color(red: 0.40, green: 0.69, blue: 0.82)),
        
        // February - Medium blue (Winter)
        (primary: Color(red: 0.44, green: 0.73, blue: 0.84),
         secondary: Color(red: 0.35, green: 0.60, blue: 0.79)),
        
        // March - Light green (Spring)
        (primary: Color(red: 0.56, green: 0.78, blue: 0.55),
         secondary: Color(red: 0.40, green: 0.65, blue: 0.45)),
        
        // April - Fresh green (Spring)
        (primary: Color(red: 0.47, green: 0.75, blue: 0.48),
         secondary: Color(red: 0.35, green: 0.62, blue: 0.40)),
        
        // May - Vibrant green (Spring)
        (primary: Color(red: 0.36, green: 0.70, blue: 0.42),
         secondary: Color(red: 0.28, green: 0.56, blue: 0.35)),
        
        // June - Light gold (Summer)
        (primary: Color(red: 0.95, green: 0.77, blue: 0.42),
         secondary: Color(red: 0.85, green: 0.65, blue: 0.30)),
        
        // July - Orange (Summer)
        (primary: Color(red: 0.94, green: 0.65, blue: 0.30),
         secondary: Color(red: 0.82, green: 0.55, blue: 0.25)),
        
        // August - Coral (Summer)
        (primary: Color(red: 0.94, green: 0.52, blue: 0.30),
         secondary: Color(red: 0.82, green: 0.42, blue: 0.25)),
        
        // September - Light brown (Fall)
        (primary: Color(red: 0.80, green: 0.52, blue: 0.25),
         secondary: Color(red: 0.70, green: 0.42, blue: 0.20)),
        
        // October - Rust (Fall)
        (primary: Color(red: 0.70, green: 0.44, blue: 0.40),
         secondary: Color(red: 0.60, green: 0.35, blue: 0.30)),
        
        // November - Plum (Fall)
        (primary: Color(red: 0.55, green: 0.40, blue: 0.60),
         secondary: Color(red: 0.47, green: 0.32, blue: 0.50)),
        
        // December - Winter blue (Winter)
        (primary: Color(red: 0.40, green: 0.58, blue: 0.74),
         secondary: Color(red: 0.30, green: 0.48, blue: 0.62))
    ]
    
    // Helper to get the primary color for a given month (1-12)
    static func primaryForMonth(_ month: Int) -> Color {
        guard month >= 1 && month <= 12 else { return .blue }
        return colors[month - 1].primary
    }
    
    // Helper to get the secondary color for a given month (1-12)
    static func secondaryForMonth(_ month: Int) -> Color {
        guard month >= 1 && month <= 12 else { return .blue.opacity(0.7) }
        return colors[month - 1].secondary
    }
}