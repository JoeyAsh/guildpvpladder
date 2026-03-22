#!/usr/bin/env bash
# build_dist.sh — Package GuildPvPLadder for distribution.
# Output: dist/GuildPvPLadder/  (ready to drop into WoW AddOns folder)

set -euo pipefail

ADDON_NAME="GuildPvPLadder"
DIST_DIR="dist/${ADDON_NAME}"

# Clean previous build
if [ -d "dist" ]; then
    rm -rf "dist"
fi

# Create directory structure
mkdir -p "${DIST_DIR}/Core"
mkdir -p "${DIST_DIR}/Locale"
mkdir -p "${DIST_DIR}/UI"

# Root files
cp "${ADDON_NAME}.toc"  "${DIST_DIR}/"
cp "${ADDON_NAME}.lua"  "${DIST_DIR}/"

# Core module
cp Core/GuildManager.lua        "${DIST_DIR}/Core/"
cp Core/RatingTracker.lua       "${DIST_DIR}/Core/"
cp Core/AchievementTracker.lua  "${DIST_DIR}/Core/"
cp Core/DataCollector.lua       "${DIST_DIR}/Core/"

# UI module
cp UI/MainFrame.lua   "${DIST_DIR}/UI/"
cp UI/MainFrame.xml   "${DIST_DIR}/UI/"
cp UI/LadderRow.lua   "${DIST_DIR}/UI/"
cp UI/Tooltips.lua    "${DIST_DIR}/UI/"
cp UI/Minimap.lua     "${DIST_DIR}/UI/"

# Locale
cp Locale/enUS.lua "${DIST_DIR}/Locale/"

echo ""
echo "Build complete: ${DIST_DIR}/"
echo ""
echo "Files included:"
find "${DIST_DIR}" -type f | sort | sed "s|${DIST_DIR}/||"
echo ""
echo "To install: copy '${DIST_DIR}' into your WoW AddOns folder."
