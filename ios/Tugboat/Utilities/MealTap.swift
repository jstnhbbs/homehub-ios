import Foundation

/// What a tap on a meal in the Weekly Plan (or Today's Food card) does. Edit mode is what makes a tap change a
/// meal; outside it a tap only reads: open the saved recipe, or show the notes of a meal with no recipe.
enum MealTapAction: Equatable {
    case edit
    case openRecipe(String)
    case showNotes
    case nothing

    static func resolve(meal: Meal?, isEditing: Bool, canManage: Bool, canOpenRecipes: Bool) -> MealTapAction {
        if canManage && isEditing { return .edit }
        guard let meal else { return .nothing }
        if let recipeId = meal.recipeId, canOpenRecipes { return .openRecipe(recipeId) }
        if let notes = meal.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .showNotes }
        return .nothing
    }
}
