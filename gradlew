#!/bin/sh
# Gradle wrapper launcher - uses downloaded Gradle if available, else system gradle
if [ -x "$HOME/gradle-8.13/bin/gradle" ]; then exec "$HOME/gradle-8.13/bin/gradle" "$@"; fi
if [ -x "$HOME/gradle-8.5/bin/gradle" ]; then exec "$HOME/gradle-8.5/bin/gradle" "$@"; fi
if command -v gradle >/dev/null 2>&1; then exec gradle "$@"; fi
GRADLE_USER_HOME="${GRADLE_USER_HOME:-$HOME/.gradle}"
WRAPPER_JAR="$(dirname "$0")/gradle/wrapper/gradle-wrapper.jar"
if [ -f "$WRAPPER_JAR" ]; then exec java -jar "$WRAPPER_JAR" "$@"; fi
echo "Gradle not found. Install Gradle 8.5 or run with \$HOME/gradle-8.5/bin/gradle" >&2
exit 1
