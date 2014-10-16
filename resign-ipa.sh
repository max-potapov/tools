#!/bin/bash

IPA_TO_RESIGN=$1
PROFILE=$2
CERTIFICATE=$3
PATH_TO_IPA_TO_RESIGN=$(dirname $IPA_TO_RESIGN)
TMP_DIR_NAME=resign_tmp_dir
TMP_DIR_NAME_WITH_PATH=$PATH_TO_IPA_TO_RESIGN/$TMP_DIR_NAME
UNZIPPED_DIR_NAME=Payload

usage()
{
cat << EOF
=======
3 parameters are needed:
	1st - ipa file;
	2nd - provisioning profile;
	3rd - certificate.

Example:
./resign.sh Wiper.ipa Wiper_Appstore_Profile.mobileprovision "iPhone Distribution: Wiper, Inc."

Resulting ipa gets the same name + '-store' suffix.
Result will be put next to input ipa.
=======
EOF
}

check_passed_parameter()
{
	if [[ $IPA_TO_RESIGN == *.ipa ]] && [ -f "$IPA_TO_RESIGN" ]
	then
		echo "Parameter passed verification."
	else
		echo "Bad parameter: it either doesn't have .ipa at the end or couldn't be found."
		exit
	fi
}

create_tmp_dir()
{
	if [ ! -d "$TMP_DIR_NAME_WITH_PATH" ]
	then
		mkdir $TMP_DIR_NAME_WITH_PATH
	else
		echo "Temporary dir with name $TMP_DIR_NAME_WITH_PATH already exists, please rename or delete it and start over."
		exit
	fi
}

remove_tmp_dir()
{
        if [ -d "$TMP_DIR_NAME_WITH_PATH" ]
	then
                rm -rf $TMP_DIR_NAME_WITH_PATH
        else
		echo "Couldn't delete temporary dir: it doesn't exist."
                exit
        fi
}

unzip_ipa()
{
	unzip -q $IPA_TO_RESIGN -d $TMP_DIR_NAME_WITH_PATH
}

generate_ent()
{
	APP_NAME=`ls $TMP_DIR_NAME_WITH_PATH/$UNZIPPED_DIR_NAME/`

	/usr/bin/codesign -d --entitlements :- $TMP_DIR_NAME_WITH_PATH/$UNZIPPED_DIR_NAME/$APP_NAME > $TMP_DIR_NAME_WITH_PATH/Entitlements.plist
}

replace_profile_and_sign()
{
	APP_NAME=`ls $TMP_DIR_NAME_WITH_PATH/$UNZIPPED_DIR_NAME/`

	rm -r $TMP_DIR_NAME_WITH_PATH/$UNZIPPED_DIR_NAME/$APP_NAME/_CodeSignature
	cp "$PROFILE" $TMP_DIR_NAME_WITH_PATH/$UNZIPPED_DIR_NAME/$APP_NAME/embedded.mobileprovision
	/usr/bin/codesign -f -s "$CERTIFICATE" --resource-rules $TMP_DIR_NAME_WITH_PATH/$UNZIPPED_DIR_NAME/$APP_NAME/ResourceRules.plist --entitlements $TMP_DIR_NAME_WITH_PATH/Entitlements.plist $TMP_DIR_NAME_WITH_PATH/$UNZIPPED_DIR_NAME/$APP_NAME
}

zip_ipa()
{
	SHORT_VERSION=`/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" $TMP_DIR_NAME_WITH_PATH/$UNZIPPED_DIR_NAME/$APP_NAME/Info.plist`
	LONG_VERSION=`/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" $TMP_DIR_NAME_WITH_PATH/$UNZIPPED_DIR_NAME/$APP_NAME/Info.plist`

	PREV_PWD=$PWD
	cd $TMP_DIR_NAME_WITH_PATH
	zip -qr $PREV_PWD/Wiper-$SHORT_VERSION-$LONG_VERSION-store.ipa $UNZIPPED_DIR_NAME
	cd $PREV_PWD
}

if [[ $# -eq 0 ]]; then
    usage
    exit
fi

check_passed_parameter
create_tmp_dir
unzip_ipa
generate_ent
replace_profile_and_sign
zip_ipa
remove_tmp_dir
