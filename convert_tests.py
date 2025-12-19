#!/usr/bin/env python3

"""
Script to automatically convert failing shellspec tests from BeforeCall pattern
to inline setup pattern to fix macOS CI failures.

The issue is that BeforeAll/BeforeCall setups don't persist environment variables
like HOOKS_DIR to the test execution context in macOS CI environment due to
shellspec context isolation.
"""

import re
import sys

def convert_test_pattern(content):
    """Convert BeforeCall setup pattern to inline setup pattern."""
    
    # Pattern to match tests with BeforeCall setup
    pattern = r'''(    It '[^']+'\n)(      setup\(\) \{[^}]+\})\n(      BeforeCall 'setup')\n\n(      When call [^\n]+)\n\n((?:      The [^\n]+\n)+)    End'''
    
    def replace_test(match):
        it_line = match.group(1)
        setup_func = match.group(2)
        when_call = match.group(4)
        assertions = match.group(5)
        
        # Extract the test name from the It line
        test_name_match = re.search(r"It '([^']+)'", it_line)
        if not test_name_match:
            return match.group(0)  # Return unchanged if we can't parse
        
        test_name = test_name_match.group(1)
        
        # Create a function name from the test name
        func_name = re.sub(r'[^a-zA-Z0-9_]', '_', test_name.lower())
        func_name = re.sub(r'_+', '_', func_name)  # Remove multiple underscores
        func_name = func_name.strip('_')  # Remove leading/trailing underscores
        func_name = f"test_{func_name}"
        
        # Extract the setup function body
        setup_body_match = re.search(r'setup\(\) \{(.*)\}', setup_func, re.DOTALL)
        if not setup_body_match:
            return match.group(0)  # Return unchanged if we can't parse
        
        setup_body = setup_body_match.group(1).strip()
        
        # Extract the hook call from When call
        when_match = re.search(r'When call (.+)', when_call)
        if not when_match:
            return match.group(0)  # Return unchanged if we can't parse
        
        hook_call = when_match.group(1)
        
        # Build the new test function
        new_test = f"""{it_line}      {func_name}() {{
        # Set up test environment
        mkdir -p /tmp/test_hooks
        export HOOKS_DIR=/tmp/test_hooks
        
{setup_body}
        
        {hook_call}
        
        # Clean up
        rm -f /tmp/test_hooks/*
      }}

      When call {func_name}

{assertions}    End"""
        
        return new_test
    
    # Apply the conversion
    converted = re.sub(pattern, replace_test, content, flags=re.MULTILINE | re.DOTALL)
    
    return converted

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 convert_tests.py <spec_file>")
        sys.exit(1)
    
    spec_file = sys.argv[1]
    
    try:
        with open(spec_file, 'r') as f:
            content = f.read()
        
        converted_content = convert_test_pattern(content)
        
        with open(spec_file, 'w') as f:
            f.write(converted_content)
        
        print(f"Converted {spec_file}")
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()