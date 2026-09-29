import Foundation

/// One undo entry per committed edit, addition or deletion, never per keystroke.
nonisolated struct IngredientEditHistory {
    private(set) var undoStack: [RecipeCustomization] = []
    private(set) var redoStack: [RecipeCustomization] = []
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    mutating func record(_ previous: RecipeCustomization, replacingWith next: RecipeCustomization) {
        guard previous != next else { return }
        undoStack.append(previous)
        if undoStack.count > 50 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    mutating func undo(_ current: inout RecipeCustomization) {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(current)
        current = previous
    }

    mutating func redo(_ current: inout RecipeCustomization) {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(current)
        current = next
    }
}
