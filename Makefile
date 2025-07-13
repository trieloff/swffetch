.PHONY: test coverage build clean lint format install

# Build the project
build:
	swift build

# Run all tests
test:
	swift test

# Run tests with coverage report
coverage:
	swift test --enable-code-coverage
	@echo "Coverage report available at: .build/arm64-apple-macosx/debug/codecov/default.profdata"
	@echo "Run: make coverage-report"

# Generate detailed coverage report
coverage-report: coverage
	@echo "Generating coverage report for SwiftFFetch..."
	@xcrun llvm-cov report -instr-profile=.build/arm64-apple-macosx/debug/codecov/default.profdata \
		.build/arm64-apple-macosx/debug/SwiftFFetchPackageTests.xctest/Contents/MacOS/SwiftFFetchPackageTests | grep -A 20 "Sources/SwiftFFetch"

# Run swiftlint
lint:
	swiftlint --strict

# Format code (requires swiftformat)
format:
	swiftformat --swiftversion 5.9 Sources Tests

# Clean build artifacts
clean:
	rm -rf .build

# Install dependencies (if any)
install:
	swift package resolve

# Help
help:
	@echo "Available commands:"
	@echo "  make build           - Build the project"
	@echo "  make test            - Run all tests"
	@echo "  make coverage        - Run tests with coverage"
	@echo "  make coverage-report - Generate detailed coverage report"
	@echo "  make lint            - Run swiftlint"
	@echo "  make format          - Format code with swiftformat"
	@echo "  make clean           - Clean build artifacts"
	@echo "  make install         - Install dependencies"