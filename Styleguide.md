# Network Handler Style Guide

This document is not comprehensive and will be updated as needed to address issues as they arise.

## Principles

#### Optimize for the reader, not the writer

Codebases often have extended lifetimes and more time is spent reading the code than writing it. We explicitly choose to optimize for the experience of our average software engineer reading, maintaining, and debugging code in our codebase rather than the ease of writing said code. For example, when something surprising or unusual is happening in a snippet of code, leaving textual hints for the reader is valuable.

## Naming

Names should be as descriptive as possible, within reason.

* avoid abbreviations
* unless the name is excessively obvious, use 3 characters at minimum for names

## Indentation

Tabs. You read that right. Tabs are modular. Do you prefer 2 space sized indentation? Feel free to view documents that way. Do you have old person eyes like me? Use 4 space sized tabs.

Frequently navigate via keyboard? Press an arrow key once to get through a tab, not 2-4 or more times.

Commenting out a block? Don't ruin the cleanliness of the columns by offsetting the commented code by 2 columns.

But most importantly, the least selfish reason of mine... If a contributor relies on assistive devices, they typically (always?) require a single keystroke per whitespace character. Using spaces really inhibits their code navigation, even if your IDE of choice handles spaces like tabs transparently. Let's be as welcoming as possible to anyone who wants to bring something to the table. 

## Whitespace

Let's keep our documents as clean as possible.
* eliminate trailing whitespace
* leave a single, blank line of vertical whitespace to create visual separation between "strides" in the code. 
	* if you are attempting to group a thematic section together, you may separate with two vertical whitespaces (use sparingly)
* there should be no vertical whitespace between `// MARK` and the following line in the section it's marking

## Line Length

This isn't intended to be a hard rule, but a guideline. There will be exceptions and they will be subjective. Try to keep your lines at 120 columns wide or less. We don't want to have to scroll horizontally to view an entire line (this is why 80 columns was so prevalent previously, but we have bigger monitors now). It's also statistically proven harder to read when you have to move your eyes too far horizontally.

So how do we break up long lines? If it's a string, usually the best path forward is to make it a multi-line string and add escapes to avoid newlines.

```swift
let sample = """
And THAT'S why you always leave a note. You might wanna lean away from that fire since you're soaked in alcohol. \
Oh…yeah…the guy in the…the $4,000 suit is holding the elevator for a guy who doesn't make that in three months. Come \
on! Hair up, glasses off. Stack the chafing dishes outside by the mailbox. I'm on the job.
"""
```

What about function definitions that exceed the line length, you say? We need a format that is scalable with tabs, yet still easy to read and reason about. We also want something compatible with Xcode's auto indentation to help keep things easier. So here's the guideline (which should apply to both the implementation and call site):

* function name up through the opening paren on the first line
* each argument gets its own line
* the closing paren with the return value (or omitted return value) and opening brace of the implementation gets its own line
	* If the return value is a tuple that pushes the line limit, that can be broken up similarly
* Try not to leave dangling closing parens on their own line.
* generally lean into the styles that Xcode provides via `ctrl-i` and `ctrl-m` - to get these results, there's little to no modification

Here's an example, stright from this project (pro tip - this is usually what Xcode gives you when you place your cursor amongst the arguments and hit `ctrl-m`):
```swift
func performNetworkTransfer(
	request: NetworkRequest,
	uploadProgressContinuation: UploadProgressStream.Continuation?,
	requestLogger: Logger?
) async throws(NetworkError) -> (responseHeader: EngineResponseHeader, responseBody: ResponseBodyStream) {
	// ...
}
```

And here's another, imaginary modification for when the return ends up beyond the line limit:

```swift
func performNetworkTransfer(
	request: NetworkRequest,
	uploadProgressContinuation: UploadProgressStream.Continuation?,
	requestLogger: Logger?
) async throws(NetworkError) -> (
	responseHeader: EngineResponseHeader,
	responseBody: ResponseBodyStream,
	annoyinglyLongTupleComponentName: AnnoyinglyLongSymbolNameThatGetsVerySpecificAndOverlyVerboseButSimultaneouslyHasItsMerits
) {
	// ...
}
```

Call site example:

```swift
delegate.addTask(
	urlTask,
	withStream: payloadStream,
	progressContinuation: uploadProgressContinuation,
	bodyContinuation: bodyContinuation)
```

Tie breaker:

If you have a definition that could get line splits in either the arguments or the return tuple, the arguments get split first:

```swift
	private func getSessionTask(from request: NetworkRequest) throws(NetworkError) -> (task: URLSessionTask, inputStream: InputStream?) { ... }

	// becomes 

	private func getSessionTask(
		from request: NetworkRequest
	) throws(NetworkError) -> (task: URLSessionTask, inputStream: InputStream?) { ... }
```

## Trailing Closures

Use of single trailing closures is fine, if not preferable. Use of multiple trailing closures is difficult to parse, so don't use them.

## Swiftlint

This project uses [Swiftlint](https://github.com/realm/SwiftLint#using-homebrew). Be sure to fix any warnings brought about by swiftlint. If you need to disable or ignore a setting, be sure to justify your reasoning in your pull request.
* if you don't have swiftlint installed, install it (best to use the homebrew method).


Many parts of this document were pulled from Google's [ObjC](http://google.github.io/styleguide/objcguide.html) and [Swift](https://google.github.io/swift/#column-limit) style guides.
