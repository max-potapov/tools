#!/bin/bash

IPA_TO_RESIGN=$1
PROFILE=$2
CERTIFICATE=$3
PATH_TO_IPA_TO_RESIGN=`cd $(dirname $IPA_TO_RESIGN); pwd`
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
./resign-ipa.sh Wiper.ipa Wiper_Appstore_Profile.mobileprovision "iPhone Distribution: Wiper, Inc."

Resulting ipa gets the same name + '-store' suffix.
Result will be put next to input ipa.
=======
EOF
}

fail()
{
    echo "*** Resigning failed ***"
    exit 1
}

check_passed_parameter()
{
	echo "*** check_passed_parameter started ***"
	if [[ $IPA_TO_RESIGN == *.ipa ]] && [ -f "$IPA_TO_RESIGN" ]
	then
		echo "Parameter passed verification."
	else
		echo "Bad parameter: it either doesn't have .ipa at the end or couldn't be found."
		exit 1
	fi
	echo "*** check_passed_parameter finished ***"
}

create_tmp_dir()
{
	echo "*** create_tmp_dir started ***"
	if [ ! -d "$TMP_DIR_NAME_WITH_PATH" ]
	then
		mkdir $TMP_DIR_NAME_WITH_PATH || fail
	else
		echo "Temporary dir with name $TMP_DIR_NAME_WITH_PATH already exists, please rename or delete it and start over."
		exit 1
	fi
	echo "*** create_tmp_dir finished ***"
}

remove_tmp_dir()
{
	echo "*** remove_tmp_dir started ***"
        if [ -d "$TMP_DIR_NAME_WITH_PATH" ]
	then
                rm -rf $TMP_DIR_NAME_WITH_PATH || fail
        else
		echo "Couldn't delete temporary dir: it doesn't exist."
                exit 1
        fi
	echo "*** remove_tmp_dir finished ***"
}

unzip_ipa()
{
	echo "*** unzip_ipa started ***"
	unzip -q $IPA_TO_RESIGN -d $TMP_DIR_NAME_WITH_PATH || fail
	echo "*** unzip_ipa finished ***"
}

generate_ent()
{
	echo "*** generate_ent started ***"
	APP_NAME=`ls $TMP_DIR_NAME_WITH_PATH/$UNZIPPED_DIR_NAME/`

	/usr/bin/codesign -d --entitlements :- $TMP_DIR_NAME_WITH_PATH/$UNZIPPED_DIR_NAME/$APP_NAME > $TMP_DIR_NAME_WITH_PATH/Entitlements.plist || fail
	echo "*** generate_ent finished ***"
}

replace_profile_and_sign()
{
	echo "*** replace_profile_and_sign started ***"
	APP_NAME=`ls $TMP_DIR_NAME_WITH_PATH/$UNZIPPED_DIR_NAME/`

	rm -r $TMP_DIR_NAME_WITH_PATH/$UNZIPPED_DIR_NAME/$APP_NAME/_CodeSignature || fail
	cp "$PROFILE" $TMP_DIR_NAME_WITH_PATH/$UNZIPPED_DIR_NAME/$APP_NAME/embedded.mobileprovision || fail
	/usr/bin/codesign -f -s "$CERTIFICATE" --resource-rules $TMP_DIR_NAME_WITH_PATH/$UNZIPPED_DIR_NAME/$APP_NAME/ResourceRules.plist --entitlements $TMP_DIR_NAME_WITH_PATH/Entitlements.plist $TMP_DIR_NAME_WITH_PATH/$UNZIPPED_DIR_NAME/$APP_NAME || fail
	echo "*** replace_profile_and_sign finished ***"
}

zip_ipa()
{
	echo "*** zip_ipa started ***"
	SHORT_VERSION=`/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" $TMP_DIR_NAME_WITH_PATH/$UNZIPPED_DIR_NAME/$APP_NAME/Info.plist || fail`
	LONG_VERSION=`/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" $TMP_DIR_NAME_WITH_PATH/$UNZIPPED_DIR_NAME/$APP_NAME/Info.plist || fail`

	pushd $TMP_DIR_NAME_WITH_PATH || fail
	zip -qr $PATH_TO_IPA_TO_RESIGN/Wiper-$SHORT_VERSION-$LONG_VERSION-store.ipa $UNZIPPED_DIR_NAME || fail
	popd
	echo "*** zip_ipa finished ***"
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
