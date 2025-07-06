.PHONY: help format

# Default target
help:
	@echo "Available commands:"
	@echo "  format - Format the code"
	@echo "  help   - Show this help message"

# Format the code using altshfmt
format:
	[ -x "$ALTSHFMT" ] && "$ALTSHFMT" -l -w . || echo "ALTSHFMT is not set, run 'direnv allow'"