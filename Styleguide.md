#  Network Handler Style Guide

This document is not comprehensive and will be updated as needed to address issues as they arise.

## Principles

#### Optimize for the reader, not the writer

Codebases often have extended lifetimes and more time is spent reading the code than writing it. We explicitly choose to optimize for the experience of our average software engineer reading, maintaining, and debugging code in our codebase rather than the ease of writing said code. For example, when something surprising or unusual is happening in a snippet of code, leaving textual hints for the reader is valuable.

## Naming

Names should be as descriptive as possible, within reason.
* avoid abbreviations
* unless the name is excessively obvious, use 3 characters at minimum for names

## Indentation

Tabs.

## Whitespace

Let's keep our documents as clean as possible.
* eliminate trailing whitespace
* leave a single, blank line of vertical whitespace to create visual separation between "strides" in the code. 
	* if you are attempting to group a thematic section together, you may separate with two vertical whitespaces (use sparingly)
* there should be no vertical whitespace between `// MARK` and the following line in the section it's marking

## Swiftlint

This project uses [Swiftlint](https://github.com/realm/SwiftLint#using-homebrew). Be sure to fix any warnings brought about by swiftlint. If you need to disable or ignore a setting, be sure to justify your reasoning in your pull request.
* if you don't have swiftlint installed, install it (best to use the homebrew method).


Many parts of this document were pulled from Google's [ObjC](http://google.github.io/styleguide/objcguide.html) and [Swift](https://google.github.io/swift/#column-limit) style guides.
