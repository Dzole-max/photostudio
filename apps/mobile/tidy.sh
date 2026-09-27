#!/usr/bin/env sh
# Format, apply lint fixes, format again (the formatter can split one-line ifs).
set -e
dart format lib test >/dev/null
dart fix --apply lib >/dev/null
dart fix --apply test >/dev/null
dart format lib test >/dev/null
