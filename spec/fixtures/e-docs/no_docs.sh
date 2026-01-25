#!/usr/bin/env bash
# Fixture with function that has no documentation

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Version: 1.0.0
## License: MIT

# This function has no ## documentation block
undocumented_func() {
  echo "no docs"
}

# Regular comment, not documentation
regular_func() {
  echo "regular"
}
