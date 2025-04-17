#!/bin/sh

# Ask the user for a project name
echo "Enter the project name:"
read PROJECT_NAME

# Check if CMakeLists.txt exists
if [ ! -f CMakeLists.txt ]; then
    echo "CMakeLists.txt not found in the current directory."
    exit 1
fi

# Replace the project name in CMakeLists.txt
sed -i.bak "s/set(PROJECT_NAME cpp_wifi_v1)/set(PROJECT_NAME $PROJECT_NAME)/" CMakeLists.txt

# Inform the user
echo "Project name updated to '$PROJECT_NAME' in CMakeLists.txt."