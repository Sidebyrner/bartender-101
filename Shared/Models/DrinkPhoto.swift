import Foundation

/// A photo taken of a drink, for the bartender's own records. Optional and
/// never prompted for — added from a recipe page's camera button. Stores the
/// drink's name alongside its id, like `MadeDrink`, so the photo still reads
/// correctly if the drink is renamed or deleted.
struct DrinkPhoto: Codable, Identifiable, Hashable {
    let id: UUID
    let drinkID: String
    let drinkName: String
    let takenAt: Date

    var fileName: String { "\(id.uuidString).jpg" }
    var thumbnailFileName: String { "\(id.uuidString)-thumb.jpg" }
}
