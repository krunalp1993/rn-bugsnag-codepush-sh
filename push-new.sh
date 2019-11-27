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
    rm -rf ./$BUNDLE_PATH/*
fi

clean_build_dir()
{
    echo -e "$RED Cleaning Build Directory!! ==> "
    rm -rf ./$BUNDLE_PATH/*
    echo -e "$GREEN DONE Cleaning Build Directory!! ==> "
}

delete_source_map()
{
    echo -e "$RED Cleaning Source map file!! ==> "
    rm -rf ./$BUNDLE_PATH/*.map
    echo -e "$GREEN DONE Cleaning Source map file!! ==> "
}

# Generating Directory for Assets
# ASSETS_PATH="generated_bundle/assets"
# if [ ! -d "$ASSETS_PATH" ]
# then
#     echo "Bundle Directory doesn't exist. Creating now"
#     mkdir ./$ASSETS_PATH
#     echo "Bundle Directory created"
# else
#     echo "Bundle Directory exists, Removing all the recent bundle files!"
#     rm -f ./$ASSETS_PATH/*
# fi


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
        clean_build_dir

        DEV=false
        if [ $variant == debug ]
        then
            DEV=true
        fi
        echo -e "$BLUE Generating Source map for $platform $variant $NC DEV = $DEV"

        BUNDLE_NAME="index.android.bundle"
        if [ $platform == ios ]
        then
            BUNDLE_NAME=main.jsbundle
        fi

        react-native bundle \
            --platform $platform \
            --dev $DEV \
            --entry-file index.js \
            --bundle-output $BUNDLE_PATH/$BUNDLE_NAME \
            --sourcemap-output $BUNDLE_PATH/$BUNDLE_NAME.map \
            --assets-dest $BUNDLE_PATH
        echo -e "$GREEN Successfully generated Source map for $platform $variant $NC"

        echo -e "$BLUE Uploading Source map for $platform $variant $NC"  
        curl https://upload.bugsnag.com/react-native-source-map \
            -F apiKey=$API_KEY \
            -F appVersion=$APP_VERSION \
            -F dev=$DEV \
            -F platform=$platform \
            -F sourceMap=@$BUNDLE_PATH/$BUNDLE_NAME.map \
            -F bundle=@$BUNDLE_PATH/$BUNDLE_NAME
        echo -e "$GREEN Successfully uploaded Source map for $platform $variant $NC" 
        
        delete_source_map

        if [ $variant == "release" ]
        then
            echo -e "$BLUE Runnig code push for Project : ${CODEPUSH_PROJECTS[$platform]}, Platform : $platform , Variant : $variant $NC"  
            code-push release ${CODEPUSH_PROJECTS[$platform]} ./$BUNDLE_PATH $APP_VERSION -m --description "$UPDATE_DESCRIPTION" --deploymentName Production --noDuplicateReleaseError
            echo -e "$GREEN Successfully Code pushed for $platform $variant $NC" 
        fi
    done
done