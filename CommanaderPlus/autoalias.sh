#!/bin/bash

# Color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
global=0
fullcommandpath=""
aliasname=""
temp_source_script="/tmp/source_alias_update.sh"

# Function to print usage
usage() {
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  ${GREEN}$0 --path </path/to/command> --alias <alias> [--global]${NC}"
    echo -e "  ${GREEN}$0 <path/to/command> <alias>${NC} (without flags)"
    echo -e "\nOptions:"
    echo -e "  ${YELLOW}--path${NC}: Specify the full path to the command"
    echo -e "  ${YELLOW}--alias${NC}: Specify the alias name"
    echo -e "  ${YELLOW}--global${NC}: Set the alias globally (requires root privileges)"
    echo -e "\nYou can also use the script without flags:"
    echo -e "  ${GREEN}$0 <path/to/command> <desiredalias>${NC}"
    echo -e "  The script will automatically derive if the path is relative or not."
    exit 1
}

# Parse positional arguments if flags are not used
if [ $# -eq 2 ]; then
  fullcommandpath="$1"
  aliasname="$2"
else
  # Parsing command-line options
  while getopts 'p:f:s:g' flag; do
      case "${flag}" in
          p) fullcommandpath="${OPTARG}" ;;
          s) aliasname="${OPTARG}" ;;
          g) global=1 ;;
          *) usage ;;
      esac
  done
fi

# Check if mandatory arguments are not empty
if [ -z "$fullcommandpath" ] || [ -z "$aliasname" ]; then
    usage
fi

# Resolve full path if a relative path is provided
if [[ ! "$fullcommandpath" = /* ]]; then
    fullcommandpath="$(pwd)/$fullcommandpath"
fi

# Check if the file is executable
if [ ! -x "$fullcommandpath" ]; then
    echo -e "${RED}Error:${NC} The file $fullcommandpath is not executable. Please set it as executable using '${GREEN}chmod +x $fullcommandpath${NC}'."
    exit 1
fi

# Detect the user's shell
user_shell=$(basename "$SHELL")

# Function to update or append alias in a file
update_or_append_alias() {
    local file=$1
    local alias_line="alias $aliasname='$fullcommandpath'"
    if grep -q "alias $aliasname=" "$file"; then
        # Alias exists, replace the line
        sed -i "/alias $aliasname=/c\\$alias_line" "$file"
    else
        # Alias does not exist, append to the file
        echo "$alias_line" >> "$file"
    fi
    echo "source $file" > "$temp_source_script"
    echo -e "${GREEN}✔ Updated alias in:${NC} $file"
}

# Function to move file to appropriate location
move_file() {
    local destination=$1
    if [ ! -d "$destination" ]; then
        mkdir -p "$destination"
    fi
    local filename=$(basename "$fullcommandpath")
    cp "$fullcommandpath" "$destination/$filename"
    fullcommandpath="$destination/$filename"
    echo -e "${YELLOW}Moved command file to:${NC} $fullcommandpath"
}

# Function to set alias locally
set_local_alias() {
    local user_bin_dir="$HOME/bin"
    move_file "$user_bin_dir"

    case $user_shell in
        bash) update_or_append_alias ~/.bashrc ;;
        zsh) update_or_append_alias ~/.zshrc ;;
        *) echo -e "${RED}Unsupported shell for local alias setting.${NC}" ;;
    esac
    echo -e "${YELLOW}Alias $aliasname set locally for $fullcommandpath.${NC}"
    echo -e "To apply the changes immediately, run '${GREEN}source $temp_source_script${NC}'."
}

# Function to set alias globally for all shells
set_global_alias() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}Setting a global alias requires root privileges.${NC} Please run the script with '${GREEN}sudo${NC}' for global aliases."
        exit 1
    fi
    move_file "/usr/local/bin"

    update_or_append_alias /etc/bash.bashrc
    update_or_append_alias /etc/zsh/zprofile
    update_or_append_alias /etc/profile
    echo -e "${YELLOW}Alias $aliasname set globally for $fullcommandpath.${NC}"
    echo -e "To apply the changes immediately, run '${GREEN}source $temp_source_script${NC}'."
}

# Set alias based on the global flag
if [ "$global" -eq 1 ]; then
    set_global_alias
else
    set_local_alias
fi

# Final message
echo -e "${GREEN}Note:${NC} Remember to run '${GREEN}source $temp_source_script${NC}' to apply the changes in your current shell session."

