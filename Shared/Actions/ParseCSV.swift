import Foundation
import TabularData
import UniformTypeIdentifiers
import Intents

@MainActor
final class ParseCSVIntentHandler: NSObject, ParseCSVIntentHandling {
	func handle(intent: ParseCSVIntent) async -> ParseCSVIntentResponse {
		let response = ParseCSVIntentResponse(code: .success, userActivity: nil)

		guard let file = intent.file else {
			return response
		}

		let hasHeader = intent.hasHeader as? Bool ?? true

		do {
			let delimiter: Character = try {
				switch intent.delimiter {
				case .unknown, .comma:
					return ","
				case .tab:
					return "\t"
				case .custom:
					guard
						let delimiter = intent.customDelimiter,
						delimiter.count == 1,
						let character = delimiter.first
					else {
						throw NSError.appError("Invalid delimiter. The delimiter should be a single character.")
					}

					return character
				}
			}()

			let dataFrame = try DataFrame(
				csvData: file.data,
				options: .init(
					hasHeaderRow: hasHeader,
					delimiter: delimiter
				)
			)

			// TODO: We cannot return a JSON array as the Shortcuts app crashes. (macOS 12.2)
//			response.result = try JSONSerialization.data(
//				withJSONObject: dataFrame.toArray(),
//				options: .prettyPrinted
//			)
//				.toINFile(
//					contentType: .json,
//					filename: file.filename.replacingSuffix(".csv", with: "")
//				)

			response.result = try dataFrame.rows.indexed().map {
				try JSONSerialization.data(
					withJSONObject: $0.1.toDictionary(),
					options: .prettyPrinted
				)
					.toINFile(contentType: .json, filename: "Row \($0.0 + 1)")
			}
		} catch {
			return .failure(failure: error.presentableMessage)
		}

		return response
	}
}
