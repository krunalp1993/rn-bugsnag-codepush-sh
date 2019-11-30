# Script to generate and upload source maps to BugSnag
echo "Building and uploading source maps for BugSnag"

# Global variables
# SET YOUR BUG SNAG API KEY HERE
API_KEY="e45ba106348d59a7c4eb1ae52ed311d6"
declare -A CODEPUSH_PROJECTS  
CODEPUSH_PROJECTS=( [android]=tallo-Android [ios]=tallo-iOS )

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'


if [ "$API_KEY" == "" ]
then
    echo "You must set BugSnag API Key to use this script! Edit the script and set API_KEY in line no 6."
    exit 0
fi


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
echo "Enter Android App version to upload the Source map: Example 0.0.1?"
read APP_VERSION

if [ "$APP_VERSION" == "" ]
then
    echo "Setting default App version to 0.0.1"
    APP_VERSION="0.0.1"
fi

echo "Enter IOS version to upload the Source map? Just skip if you want to use same as Android"
read IOS_APP_VERSION

if [ "$IOS_APP_VERSION" == "" ]
then
    echo "Setting default App version to 0.0.1"
    IOS_APP_VERSION=$APP_VERSION
fi

echo "Enter Description of this new update? Default: New updates"
read UPDATE_DESCRIPTION

if [ "$UPDATE_DESCRIPTION" == "" ]
then
    echo "Setting default Description to New changes"
    UPDATE_DESCRIPTION="New changes"
fi

# Ask if want to do only bugsnag or both
echo "Do you want to push new code with CodePush! Please enter 1 to enable and 0 to skip."
read DO_CODEPUSH

if [[ "$DO_CODEPUSH" == "" ]] || [[ "$DO_CODEPUSH" != "1" && "$DO_CODEPUSH" == "0"  ]]
then
    echo -e "$BLUE Setting Default Codepush disabled"
    DO_CODEPUSH=0
fi


echo "Generating Source map for Version Android : $APP_VERSION, IOS : $IOS_APP_VERSION , Update Description : $UPDATE_DESCRIPTION"



# Variants
PLATFORMS=("android" "ios")
VARIANTS=("debug" "release")

for platform in "${PLATFORMS[@]}"
do
   for variant in "${VARIANTS[@]}"
    do
        clean_build_dir

        if [[ $variant == "release" ]] && [[ "$DO_CODEPUSH" == "1" ]]
        then
            echo "Code push not skipped."
        fi

        C_APP_VERSION="$APP_VERSION"
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
            C_APP_VERSION="$IOS_APP_VERSION"
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
            -F appVersion=$C_APP_VERSION \
            -F dev=$DEV \
            -F platform=$platform \
            -F sourceMap=@$BUNDLE_PATH/$BUNDLE_NAME.map \
            -F bundle=@$BUNDLE_PATH/$BUNDLE_NAME
        echo -e "$GREEN Successfully uploaded Source map for $platform $variant $NC" 
        
        delete_source_map

        if [[ $variant == "release" ]] && [[ "$DO_CODEPUSH" == "1" ]]
        then
            echo -e "$BLUE Runnig code push for Project : ${CODEPUSH_PROJECTS[$platform]}, Platform : $platform , Variant : $variant $NC"  
            code-push release ${CODEPUSH_PROJECTS[$platform]} ./$BUNDLE_PATH $C_APP_VERSION -m --description "$UPDATE_DESCRIPTION" --deploymentName Production --noDuplicateReleaseError
            echo -e "$GREEN Successfully Code pushed for $platform $variant $NC" 
        else
            echo -e "$RED Skipping code push as not enabled :: => $DO_CODEPUSH"
        fi
    done
done
