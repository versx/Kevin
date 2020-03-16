#!/bin/bash

# Config

appDir="" # Pogo ipa as zip
payloadDir="" # Payload folder of Pogo unzipped
DEVELOPER="" # This can be found by running `security find-identity -p codesigning`
MOBILEPROV="" # path to provisioning profile

rm -rf "$payloadDir"

# Unzip ipa
unzip app.zip

# Remove stupid directory settings file
rm -rf __MACOSX

#echo "Copying ${CONFIGURATION_BUILD_DIR}/CocoaAsyncSocket/libCocoaAsyncSocket.a to $payloadDir/pokemongo.app/Frameworks"
#cp "${CONFIGURATION_BUILD_DIR}/CocoaAsyncSocket/libCocoaAsyncSocket.a" "$payloadDir/pokemongo.app/Frameworks/libCocoaAsyncSocket.a"

#echo "Copying CocoaHTTPServer to $payloadDir/pokemongo.app/Frameworks"
#cp "${CONFIGURATION_BUILD_DIR}/CocoaHTTPServer/libCocoaHTTPServer.a" "$payloadDir/pokemongo.app/Frameworks/libCocoaHTTPServer.a"

#echo "Copying CocoaLumberjack to $payloadDir/pokemongo.app/Frameworks"
#cp "${CONFIGURATION_BUILD_DIR}/CocoaLumberjack/libCocoaLumberjack.a" "$payloadDir/pokemongo.app/Frameworks/libCocoaLumberjack.a"

#echo "Copying PaperTrailLumberjack to $payloadDir/pokemongo.app/Frameworks"
#cp "${CONFIGURATION_BUILD_DIR}/PaperTrailLumberjack/libPaperTrailLumberjack.a" "$payloadDir/pokemongo.app/Frameworks/libPaperTrailLumberjack.a"

echo "Copying KIF to $payloadDir/pokemongo.app/Frameworks"
cp -R "${CONFIGURATION_BUILD_DIR}/KIF.framework" "$payloadDir/pokemongo.app/Frameworks/"

echo "Copying XCTest to $payloadDir/pokemongo.app/Frameworks"
cp -R "XCTest.framework" "$payloadDir/pokemongo.app/Frameworks/"

echo "Copying XCTAutomationSupport to $payloadDir/pokemongo.app/Frameworks"
cp -R "XCTAutomationSupport.framework" "$payloadDir/pokemongo.app/Frameworks/"

echo "Copying libJarvis++.dylib to ${payloadDir}"
cp "${CONFIGURATION_BUILD_DIR}/libJarvis++.dylib" "$payloadDir/pokemongo.app/libJarvis++.dylib"

#echo "Copying config.plist to ${payloadDir}/pokemongo.app/"
#cp config.plist "$payloadDir/pokemongo.app/"

#echo "Installing CocoaAsyncSocket to ${payloadDir}/pokemongo.app/pokemongo..."
#optool install -c load -p "${CONFIGURATION_BUILD_DIR}/CocoaAsyncSocket/libCocoaAsyncSocket.a" -t ${payload}/pokemongo.app/pokemongo

#echo "Installing CocoaHTTPServer to ${payloadDir}/pokemongo.app/pokemongo..."
#optool install -c load -p "${CONFIGURATION_BUILD_DIR}/CocoaHTTPServer/libCocoaHTTPServer.a" -t ${payload}/pokemongo.app/pokemongo

#echo "Installing CocoaLumberjack to ${payloadDir}/pokemongo.app/pokemongo..."
#optool install -c load -p "${CONFIGURATION_BUILD_DIR}/CocoaLumberjack/libCocoaLumberjack.a" -t ${payload}/pokemongo.app/pokemongo

#echo "Installing PaperTrailLumberjack to ${payloadDir}/pokemongo.app/pokemongo..."
#optool install -c load -p "${CONFIGURATION_BUILD_DIR}/PaperTrailLumberjack/libPaperTrailLumberjack.a" -t ${payload}/pokemongo.app/pokemongo

echo "Installing KIF to ${payloadDir}/pokemongo.app/pokemongo..."
optool install -c load -p "${CONFIGURATION_BUILD_DIR}/KIF/KIF.framework/KIF" -t ${payload}/pokemongo.app/pokemongo

echo "Installing XCTest to ${payloadDir}/pokemongo.app/pokemongo..."
optool install -c load -p "XCTest.framework/XCTest" -t ${payload}/pokemongo.app/pokemongo

echo "Installing XCTAutomationSupport to ${payloadDir}/pokemongo.app/pokemongo..."
optool install -c load -p "XCTAutomationSupport.framework/XCTAutomationSupport" -t ${payload}/pokemongo.app/pokemongo

echo "Installing Jarvis++ to ${payloadDir}/pokemongo.app/pokemongo..."
optool install -c load -p "@executable_path/libJarvis++.dylib" -t ${payloadDir}/pokemongo.app/pokemongo


# Xerock deployer
# Remove previously signed ipa
rm -rf "/Users/helpdesk/Desktop/deployer-redux/Releases/jarvis/resignedSigned.ipa"

# Remove previously unsigned ipa
rm -rf "/Users/helpdesk/Desktop/deployer-redux/Releases/jarvis/resigned.ipa"

# Zip up final product
zip -r -X "/Users/helpdesk/Desktop/deployer-redux/Releases/jarvis/resigned.zip" "Payload/"

# Rename .zip to .ipa
mv "/Users/helpdesk/Desktop/deployer-redux/Releases/jarvis/resigned.zip" "/Users/helpdesk/Desktop/deployer-redux/Releases/jarvis/resigned.ipa"

cd "/Users/helpdesk/Desktop/deployer-redux"

# Run deployer
node "/Users/helpdesk/Desktop/deployer-redux/deploy.js" -f true -l true



#echo "Begin xReSign process..."

#
#  xresign.sh
#  XReSign
#
#  Copyright © 2017 xndrs. All rights reserved.
#

#echo "Start resign the app..."

#OUTDIR=$(dirname "${payloadDir}")
#TMPDIR="$OUTDIR/tmp"
#APPDIR="$TMPDIR/app"


#mkdir -p "$APPDIR"
#cp -R  "${payloadDir}" "$APPDIR"

#APPLICATION=$(ls "$APPDIR/Payload/")


#if [ -z "${MOBILEPROV}" ]; then
#    echo "Sign process using existing provisioning profile from payload"
#else
#    echo "Coping provisioning profile into application payload"
#    cp "$MOBILEPROV" "$APPDIR/Payload/$APPLICATION/embedded.mobileprovision"
#fi

#echo "Extract entitlements from mobileprovisioning"
#security cms -D -i "$APPDIR/Payload/$APPLICATION/embedded.mobileprovision" > "$TMPDIR/provisioning.plist"
#/usr/libexec/PlistBuddy -x -c 'Print:Entitlements' "$TMPDIR/provisioning.plist" > "$TMPDIR/entitlements.plist"


#if [ -z "${BUNDLEID}" ]; then
#    echo "Sign process using existing bundle identifier from payload"
#else
#    echo "Changing BundleID with : $BUNDLEID"
#    /usr/libexec/PlistBuddy -c "Set:CFBundleIdentifier $BUNDLEID" "$APPDIR/Payload/$APPLICATION/Info.plist"
#fi


#echo "Get list of components and resign with certificate: $DEVELOPER"
#find -d "$APPDIR" \( -name "*.app" -o -name "*.appex" -o -name "*.framework" -o -name "*.dylib" \) > "$TMPDIR/components.txt"

#var=$((0))
#while IFS='' read -r line || [[ -n "$line" ]]; do
#	if [[ ! -z "${BUNDLEID}" ]] && [[ "$line" == *".appex"* ]]; then
#	   echo "Changing .appex BundleID with : $BUNDLEID.extra$var"
#	   /usr/libexec/PlistBuddy -c "Set:CFBundleIdentifier $BUNDLEID.extra$var" "$line/Info.plist"
#	   var=$((var+1))
#	fi
#    /usr/bin/codesign --continue -f -s "$DEVELOPER" --entitlements "$TMPDIR/entitlements.plist" "$line"
#done < "$TMPDIR/components.txt"


#echo "Creating the signed ipa"
#cd "$APPDIR"
#filename=$(basename "$APPLICATION")
#filename="${filename%.*}-xresign.ipa"
#zip -qr "../$filename" *
#cd ..
#mv "$filename" "$OUTDIR"


#echo "Clear temporary files"
#rm -rf "$APPDIR"
#rm "$TMPDIR/components.txt"
#rm "$TMPDIR/provisioning.plist"
#rm "$TMPDIR/entitlements.plist"
#rm -rf "$TMPDIR"

#echo "XReSign FINISHED"

#echo "Deploying to Device"

#ios-deploy -b "$OUTDIR"/"$filename"

#echo "Done"
