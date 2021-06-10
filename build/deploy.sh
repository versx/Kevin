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
unzip -o "$appZip" -d "$buildDir"

# Remove stupid directory settings file
rm -rf __MACOSX


# Copy configs, frameworks, and dynamic libraries
echo "Copying XCTest to $payloadDir/pokemongo.app/Frameworks"
cp -R "../XCTest.framework" "$payloadDir/pokemongo.app/Frameworks/"

echo "Copying XCTAutomationSupport to $payloadDir/pokemongo.app/Frameworks"
cp -R "../XCTAutomationSupport.framework" "$payloadDir/pokemongo.app/Frameworks/"

echo "Copying libJarvis++.dylib to ${payloadDir}"
cp "${CONFIGURATION_BUILD_DIR}/libJarvis++.dylib" "$payloadDir/pokemongo.app/Frameworks/libJarvis++.dylib"


# Install load commands
echo "Installing XCTest to ${payloadDir}/pokemongo.app/pokemongo..."
optool install -c load -p "XCTest.framework/XCTest" -t ${payload}/pokemongo.app/pokemongo

echo "Installing XCTAutomationSupport to ${payloadDir}/pokemongo.app/pokemongo..."
optool install -c load -p "XCTAutomationSupport.framework/XCTAutomationSupport" -t ${payload}/pokemongo.app/pokemongo

echo "Installing Jarvis++ to ${payloadDir}/pokemongo.app/pokemongo..."
optool install -c load -p "@executable_path/Frameworks/libJarvis++.dylib" -t ${payloadDir}/pokemongo.app/pokemongo


# Xerock deployer
# Remove previously signed ipa
rm -rf "/Users/helpdesk/Desktop/deployer-redux/Releases/jarvis/resignedSigned.ipa"

# Remove previously unsigned ipa
rm -rf "/Users/helpdesk/Desktop/deployer-redux/Releases/jarvis/resigned.ipa"

# Zip up final product
zip -r -X "/Users/helpdesk/Desktop/deployer-redux/Releases/jarvis/resigned.zip" "$payloadDir"

# Rename .zip to .ipa
mv "/Users/helpdesk/Desktop/deployer-redux/Releases/jarvis/resigned.zip" "/Users/helpdesk/Desktop/deployer-redux/Releases/jarvis/resigned.ipa"

cd "/Users/helpdesk/Desktop/deployer-redux"

# Run deployer
node "/Users/helpdesk/Desktop/deployer-redux/deploy.js" -f true -l true

echo "Done"
