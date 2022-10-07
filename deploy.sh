#!/bin/bash

PM_FILE="Koha/Plugin/Fi/KohaSuomi/ReportServices.pm"
VERSION=`grep -oE "\-?[0-9]+\.[0-9]+\.[0-9]" $PM_FILE | head -1`
MINVERSION=`grep -oE "\-?[0-9]+\.[0-9][0-9]" $PM_FILE | head -1`
CURRENT_BRANCH=`git rev-parse --abbrev-ref HEAD`
if [ "$CURRENT_BRANCH" == "master" ]; then
    VERSIONTAG=`git tag -l "v${VERSION}-koha-$MINVERSION"`
    RELEASE_FILE="koha-plugin-report-services-v${VERSION}.kpz"
else
    VERSIONTAG=`git tag -l "v${VERSION}-koha-$MINVERSION-$CURRENT_BRANCH"`
    RELEASE_FILE="koha-plugin-report-services-v${VERSION}.kpz"
fi

if [ $VERSIONTAG ]; then
    echo "Release version already exists!"
    exit 1
fi

rm $RELEASE_FILE

echo "Building release package ${RELEASE_FILE}"

zip -r $RELEASE_FILE ./Koha

if [ "$CURRENT_BRANCH" == "master" ]; then
    echo "Creating tag v${VERSION}-koha-$MINVERSION"
    git tag -a "v${VERSION}-koha-$MINVERSION" -m "Release ${VERSION}"
else
    echo "Creating tag v${VERSION}-koha-$MINVERSION-$CURRENT_BRANCH"
    git tag -a "v${VERSION}-koha-$MINVERSION-$CURRENT_BRANCH" -m "Release ${VERSION}-$CURRENT_BRANCH"
fi

