#!/bin/bash

# Config
buildDir="/Users/helpdesk/Desktop/Projects/Jarvis/build/"
appZip="app.zip" # Path to app.zip
payloadDir="Payload/" # Path to Payload/ directory of unzipped app.zip

# Change directories to build directory
cd "$buildDir"

# Remove previous Payload/ folder
rm -rf "$payloadDir"

# Unzip ipa
unzip app.zip

# Remove stupid directory settings file
rm -rf __MACOSX


# Copy configs, frameworks, and dynamic libraries
echo "Copying XCTest to $payloadDir/pokemongo.app/Frameworks"
cp -R "../XCTest.framework" "$payloadDir/pokemongo.app/Frameworks/"

echo "Copying XCTAutomationSupport to $payloadDir/pokemongo.app/Frameworks"
cp -R "../XCTAutomationSupport.framework" "$payloadDir/pokemongo.app/Frameworks/"

echo "Copying libJarvis++.dylib to ${payloadDir}"
cp "${CONFIGURATION_BUILD_DIR}/libJarvis++.dylib" "$payloadDir/pokemongo.app/Frameworks/libJarvis++.dylib"

echo "Copying config.plist to ${payloadDir}"
cp "${PROJECT_DIR}/config.plist" "$payloadDir/pokemongo.app/config.plist"

# Install load commands
echo "Installing XCTest to ${payloadDir}/pokemongo.app/pokemongo..."
optool install -c load -p "XCTest.framework/XCTest" -t ${payload}/pokemongo.app/pokemongo

echo "Installing XCTAutomationSupport to ${payloadDir}/pokemongo.app/pokemongo..."
optool install -c load -p "XCTAutomationSupport.framework/XCTAutomationSupport" -t ${payload}/pokemongo.app/pokemongo

echo "Installing Jarvis++ to ${payloadDir}/pokemongo.app/pokemongo..."
optool install -c load -p "@executable_path/Frameworks/libJarvis++.dylib" -t ${payloadDir}/pokemongo.app/pokemongo


# Package for redistribution

# Zip up final product
zip -r -X "kevin.zip" "Payload/"

# Remove previous .ipa
rm "kevin.ipa"

# Rename .zip to .ipa
mv "kevin.zip" "kevin.ipa"

echo "Done"
