import Foundation

enum AppLanguage: String, CaseIterable {
    case korean
    case english

    var title: String {
        switch self {
        case .korean: "한국어"
        case .english: "English"
        }
    }
}

func text(_ language: AppLanguage, korean: String, english: String) -> String {
    switch language {
    case .korean: korean
    case .english: english
    }
}
