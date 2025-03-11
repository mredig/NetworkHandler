import Testing
import NetworkHandler
import PizzaMacros
import Foundation

struct EngineHeaderTests {
	@Test func responseDescription() {
		let url = #URL("https://redeggproductions.com")
		var response = EngineResponseHeader(
			status: 200,
			url: url,
			headers: [
				.contentLength: "\(1024)",
				.contentDisposition: "attachment; filename=\"asdf qwerty.jpg\"",
				.contentType: .json,
			])

		let description = "\(response)"

		print(description)

		#expect(description.contains("Status - 200"))
		#expect(description.contains("URL - https://redeggproductions.com"))
		#expect(description.contains("Expected length - 1024"))
		#expect(description.contains("MIME Type - application/json"))
		#expect(description.contains("Suggested Filename - asdf qwerty.jpg"))

		response = EngineResponseHeader(
			status: 200,
			url: url,
			headers: [
				.contentLength: "\(1024)",
				.contentType: .json,
			])
		let description2 = "\(response)"
		#expect(description2.contains("Suggested Filename") == false)
	}
}
