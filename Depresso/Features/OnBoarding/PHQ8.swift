//
//  PHQ8.swift
//  Depresso
//
//  Created by ElAmir Mansour on 11/10/2025.
//

// In Features/Onboarding/PHQ8.swift
import Foundation

struct PHQ8 {
    // Represents a single question in the PHQ-8.
    struct Question: Identifiable, Equatable {
        let id: Int
        let text: String
        var answer: Answer?
    }

    // Represents the possible answers for each question.
    enum Answer: Int, CaseIterable, Equatable {
        case notAtAll = 0
        case severalDays = 1
        case moreThanHalfTheDays = 2
        case nearlyEveryDay = 3

        var description: String {
            switch self {
            case .notAtAll: "Not at all"
            case .severalDays: "Several days"
            case .moreThanHalfTheDays: "More than half the days"
            case .nearlyEveryDay: "Nearly every day"
            }
        }
    }

    // The list of all 8 questions for the questionnaire.
    static let allQuestions: [Question] = [
        Question(id: 1, text: "Little interest or pleasure in doing things"),
        Question(id: 2, text: "Feeling down, depressed, or hopeless"),
        Question(id: 3, text: "Trouble falling or staying asleep, or sleeping too much"),
        Question(id: 4, text: "Feeling tired or having little energy"),
        Question(id: 5, text: "Poor appetite or overeating"),
        Question(id: 6, text: "Feeling bad about yourself—or that you are a failure or have let yourself or your family down"),
        Question(id: 7, text: "Trouble concentrating on things, such as reading the newspaper or watching television"),
        Question(id: 8, text: "Moving or speaking so slowly that other people could have noticed. Or the opposite—being so fidgety or restless that you have been moving around a lot more than usual")
    ]
}
