#!/bin/sh

# What it does:
# Script goes through project and generates keys-values.
# Then it copies apns-section of strings file between TOP_THRESHOLD_STRING and BOTTOM_THRESHOLD_STRING and pastes into file with newly generated keys-values

# How to use:
# 1) create a dir;
# 2) put the script in a created dir;
# 3) set up PROJECT_FILES_PATH (see below) according to your project location. It should point to the Wiper dir in the project;
# 4) if user wants to see diff at the end of generation, DiffMerge tool should be installed. (https://sourcegear.com/diffmerge/downloads.php)

PROJECT_FILES_PATH_UI=
PROJECT_FILES_PATH_CORE=
LOCALIZATION_FILE_PATH=${PROJECT_FILES_PATH_UI}/Resources/en.lproj/Localizable.strings

ORIGINAL_STRINGS_FILE_NAME=LocalizableOriginal.strings
NEW_STRINGS_FILE_NAME=LocalizableNew.strings
NEW_LOCALIZATION_STRINGS_WITHOUT_APNS_SECTION=Localizable.strings
TEMP_FILE_NAME=tmp
TOP_THRESHOLD_STRING="* APNS *"
BOTTOM_THRESHOLD_STRING="delete this 2 comment lines. It is used by auto generation script. ===! "

copy_original_file()
{
	cp ${LOCALIZATION_FILE_PATH} ./${ORIGINAL_STRINGS_FILE_NAME}
}

generate_strings_file()
{
	find ${PROJECT_FILES_PATH_UI} ${PROJECT_FILES_PATH_CORE} -name \*.m -print0 | xargs -0 genstrings -o .
	rm InfoPlist.strings
}

copy_apns_section()
{
	 iconv -f UTF-16 -t UTF-8 ${ORIGINAL_STRINGS_FILE_NAME} | sed -n "/${TOP_THRESHOLD_STRING}/,/${BOTTOM_THRESHOLD_STRING}/p" > ${TEMP_FILE_NAME}
}

copy_newly_generated_strings()
{
	echo "" >> ${TEMP_FILE_NAME}
	iconv -f UTF-16 -t UTF-8 ${NEW_LOCALIZATION_STRINGS_WITHOUT_APNS_SECTION} >> ${TEMP_FILE_NAME}
	iconv -f UTF-8 -t UTF-16 ./${TEMP_FILE_NAME} > ./${NEW_STRINGS_FILE_NAME}
}

clean()
{
	rm ${NEW_LOCALIZATION_STRINGS_WITHOUT_APNS_SECTION}
	rm ${TEMP_FILE_NAME}
}

start_diffmerge()
{
	diffmerge ./${ORIGINAL_STRINGS_FILE_NAME} ./${NEW_STRINGS_FILE_NAME}
}

copy_original_file
generate_strings_file
copy_apns_section
copy_newly_generated_strings
clean
start_diffmerge
