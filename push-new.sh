# Script to generate and upload source maps to BugSnag
echo "Building and uploading source maps for BugSnag"

# Global variables
API_KEY="4d9773ed08d70318fb72ddfc7244d73a"
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'


# Generating Directory for Code Push bundles
BUNDLE_PATH="generated_bundle"
if [ ! -d "$BUNDLE_PATH" ]
then
    echo "Bundle Directory doesn't exist. Creating now"
    mkdir ./$BUNDLE_PATH
    echo "Bundle Directory created"
else
    echo "Bundle Directory exists, Removing all the recent bundle files!"
    rm -f ./$BUNDLE_PATH/*
fi


# Ask App version
echo "Enter App version to upload the Source map: Example 0.0.1?"
read APP_VERSION

if [ "$APP_VERSION" == "" ]
then
    echo "Setting default App version to 0.0.1"
    APP_VERSION="0.0.1"
fi

echo "Enter Description of this new update? Default: New updates"
read UPDATE_DESCRIPTION

if [ "$UPDATE_DESCRIPTION" == "" ]
then
    echo "Setting default Description to New changes"
    UPDATE_DESCRIPTION="New changes"
fi

echo "Generating Source map for Version : $APP_VERSION , Update Description : $UPDATE_DESCRIPTION"



# Variants
PLATFORMS=("android" "ios")
VARIANTS=("debug" "release")
declare -A CODEPUSH_PROJECTS  
CODEPUSH_PROJECTS=( [android]=MTC [ios]=MTC-IOS )
for platform in "${PLATFORMS[@]}"
do
   for variant in "${VARIANTS[@]}"
    do
        echo -e "$BLUE Generating Source map for $platform $variant $NC"
        react-native bundle \
            --platform $platform \
            --dev $variant === "debug" ? true : false \
            --entry-file index.js \
            --bundle-output $BUNDLE_PATH/$platform-$variant.bundle \
            --sourcemap-output $BUNDLE_PATH/$platform-$variant.bundle.map
        echo -e "$GREEN Successfully generated Source map for $platform $variant $NC"

        echo -e "$BLUE Uploading Source map for $platform $variant $NC"  
        curl https://upload.bugsnag.com/react-native-source-map \
            -F apiKey=$API_KEY \
            -F appVersion=$APP_VERSION \
            -F dev=$variant === "debug" ? true : false \
            -F platform=$platform \
            -F sourceMap=@$BUNDLE_PATH/$platform-$variant.bundle.map \
            -F bundle=@$BUNDLE_PATH/$platform-$variant.bundle
        echo -e "$GREEN Successfully uploaded Source map for $platform $variant $NC" 
        
        if [ $variant == "release" ]
        then
            echo -e "$BLUE Runnig code push for Project : ${CODEPUSH_PROJECTS[$platform]}, Platform : $platform , Variant : $variant $NC"  
           
           echo "code-push release ${CODEPUSH_PROJECTS[$platform]} ./$BUNDLE_PATH/$platform-$variant.bundle $APP_VERSION -m --description $UPDATE_DESCRIPTION --deploymentName Production"
            code-push release ${CODEPUSH_PROJECTS[$platform]} ./$BUNDLE_PATH/$platform-$variant.bundle $APP_VERSION -m --description $UPDATE_DESCRIPTION --deploymentName Production
            echo -e "$GREEN Successfully Code pushed for $platform $variant $NC" 
        fi
    done
done