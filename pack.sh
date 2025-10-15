#!/usr/bin/env zsh

function sign {
    TARGET="$1"
    PLUGIN="$TARGET/mac_x64/$TARGET.xpl"
    BUNDLE_ID="skiselkov.xtcas"
    
    CERT=$(security find-certificate -Z -c "Developer ID Application:" | \
        grep "SHA-1" | \
        awk 'NF { print $NF }')
    
    echo "Signing $PLUGIN ($BUNDLE_ID)..."
    codesign "$PLUGIN" \
        --sign "$CERT" \
        --force \
        --options runtime \
        --timestamp \
        --identifier "$BUNDLE_ID"
}


function notarize {
    TARGET="$1"
    PLUGIN="$1/mac_x64/$1.xpl"
    ZIPFILE="$(mktemp -u /tmp/$TARGET.XXXXXX).zip"
    PLISTBUDDY="/usr/libexec/PlistBuddy"
    
    SUBMIT_LOG="notarize/submission.plist"
    RESULT_LOG="notarize/notarization.plist"
    
    echo "Creating /notarize..."
    mkdir -p notarize
    
    echo "Packaging $PLUGIN for notarization..."
    zip "$ZIPFILE" "$PLUGIN" > /dev/null
    
    echo "Submitting notarization request..."
    xcrun notarytool submit "$ZIPFILE" \
        --keychain-profile AC_PASSWORD \
        --output-format plist > "$SUBMIT_LOG" || exit 1
    ID=$($PLISTBUDDY -c "Print :id" "$SUBMIT_LOG")
    
    xcrun notarytool wait "$ID" \
        --keychain-profile AC_PASSWORD || exit 1
    
    echo "Notarization complete"
    xcrun notarytool info "$ID" \
        --keychain-profile AC_PASSWORD \
        --output-format plist > "$RESULT_LOG" || exit 1
    
    STATUS=$($PLISTBUDDY -c "Print :status" "$RESULT_LOG")
    
    if [[ "$STATUS" == "Accepted" ]]; then
        echo "Notarization successful"
    else
        echo "Notarization error\nCheck notarize/notarization.plist for more info"
    fi
    
    rm "$ZIPFILE"
}



GIT_REV=$(git describe --tags --always)
BUILD_ID="$(date +"%m%d")-$GIT_REV"
BUILD_ZIP="X-TCAS-$BUILD_ID.zip"

sign "X-TCAS"
notarize "X-TCAS"
zip -rq $BUILD_ZIP "$TARGET" "${EXTRA[@]}" -x ".*" -x "__MACOSX" 