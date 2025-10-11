#!/usr/bin/env bash

echo "-+-+-+-+-+-+-+-+-+-+"
echo "|Orthodox language.|"
echo "-+-+-+-+-+-+-+-+-+-+"
echo ""

# -+-+-+-+-+-+-+-+-+-+-+- FIND MINIMUM ZIG VERSION +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

MIN_VERSION="0.14.0"

# Function to compare semantic versions
version_ge() {
    IFS='.' read -r -a ver1 <<< "$1"
    IFS='.' read -r -a ver2 <<< "$2"

    for i in 0 1 2; do
        v1=${ver1[i]:-0}
        v2=${ver2[i]:-0}
        if (( v1 > v2 )); then
            return 0
        elif (( v1 < v2 )); then
            return 1
        fi
    done
    return 0
}

# Check if zig is installed
if ! command -v zig &> /dev/null; then
    printf "Zig is not installed.\n"
    printf "Download zig from https://ziglang.org/download/\n"
    exit 1
fi

ZIG_VERSION=$(zig version)
if ! version_ge "$ZIG_VERSION" "$MIN_VERSION"; then
    printf "Installed zig version:: $ZIG_VERSION, required zig version:: $MIN_VERSION+\n"
    printf "Update Zig: https://ziglang.org/download/\n"
    exit 1
fi

# also check clang++
if ! command -v clang++ &> /dev/null; then
    printf "clang++ is not installed. Orthodox can work with g++ but needs to be edited in-code(./InformedEmission.zig).\n"
    exit 1
fi

# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

# install codegen infrastructure
printf ". installing codegen infrastructure\n"

zig build-exe CodeGen.zig -femit-bin=orth -OReleaseFast &> /dev/null
rm orth.o &> /dev/null

if [[ $? -eq 0 ]]; then
    printf "done .\n\n"
else
    printf "ERROR: error encountered while installing codegen infrastructure\n"
    printf "ERROR: this is most likely due to an error in (./CodeGen.zig)\n"
    exit 1
fi

# install python orthodox cli
printf ". installing orthodox cli\n"

if [[ -f ORTHODOX.py ]]; then
    chmod +x ORTHODOX.py
else
    printf "ERROR: ORTHODOX.py file not found\n"
    exit 1
fi

# -+-+-+-+-+-+-+-+-+-+-+-+-+-+ SHELL SETUP +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

# installing these files to /usr/bin/ then, symlinking ORTHODOX.py to orthodox
PY_FILE="ORTHODOX.py"
BINARY_FILE="orth"
SYMLINK_NAME="orthodox"

SHELL_PATH=$(getent passwd $USER | cut -d: -f7)
# default shell name
SHELL_NAME=$(basename "$SHELL_PATH")

# Determine rc file
case "$SHELL_NAME" in
    bash)
        RC_FILE="$HOME/.bashrc"
        ;;
    zsh)
        RC_FILE="$HOME/.zshrc"
        ;;
    fish)
        RC_FILE="$HOME/.config/fish/config.fish"
        ;;
    *)
        printf "Unsupported shell: $SHELL_NAME. Add symlink manually.\n"
        RC_FILE=""
        ;;
esac

# Move files to /usr/bin/ 
printf "      -> moving $PY_FILE and $BINARY_FILE to /usr/bin/...\n"
sudo cp "$PY_FILE" /usr/bin/
sudo mv "$BINARY_FILE" /usr/bin/
printf "        done .\n\n"

# Create symlink
printf "      -> creating symlink /usr/bin/$SYMLINK_NAME → /usr/bin/$PY_FILE\n"
sudo ln -sf /usr/bin/$PY_FILE /usr/bin/$SYMLINK_NAME
printf "       done .\n\n"

printf "done .\n\n"
printf "orthodox installed, evoke orthodox --help to learn more\n\n"

# -+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
