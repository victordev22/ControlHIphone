import Foundation
import Observation

@Observable
final class AppState {
    static let shared = AppState()
    private init() {}

    var deviceToken: String?
}
