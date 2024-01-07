#!/bin/bash

# Function to check and install a tool (gh or git)
check_and_install_tool() {
    local tool=$1
    if ! command -v $tool &> /dev/null; then
        echo "$tool is not installed, installing.."
        # Detect Linux distribution and install tool accordingly
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install $tool
        elif command -v yum &> /dev/null; then
            sudo yum install $tool
        elif command -v dnf &> /dev/null; then
            sudo dnf install $tool
        else
            echo "No supported package manager found. Unable to install $tool. Please install it manually."
            exit 1
        fi
    else
        echo "$tool is already installed."
    fi
}

# Function to ensure user is authenticated with GitHub
ensure_authenticated() {
    while ! gh auth status &> /dev/null; do
        echo "You are not authenticated with GitHub. Please authenticate."
        if ! gh auth login; then
            echo "GitHub authentication failed. Please try again."
            exit 1
        fi
    done
    echo "Authentication successful."
}

# Function to handle gitx ship
gitx_ship() {
    check_and_install_tool "gh"
    check_and_install_tool "git"
    ensure_authenticated

    echo "Choose an option:"
    echo "1. Create a new repo"
    echo "2. Connect to an existing repo"
    read -p "Enter choice (1 or 2): " choice

    if [[ "$choice" == "1" ]]; then
        read -p "Enter new repo name: " repo_name
        read -p "Do you want it to be public? (Enter for private, type 'public' for public): " visibility

        local repo_visibility="private"
        if [[ "$visibility" == "public" ]]; then
            repo_visibility="public"
        fi

        # Create the repo and capture the URL
        echo "Creating GitHub repository..."
        create_repo_output=$(gh repo create "$repo_name" --$repo_visibility 2>&1)
        if [[ $? -ne 0 ]]; then
            echo "Failed to create GitHub repository: $create_repo_output"
            exit 1
        fi
        echo "$create_repo_output"

        # Capture the repository URL
        # The URL is typically the last line of the output
        local repo_url=$(echo "$create_repo_output" | tail -n 1)

        # Check if the repository URL is valid
        if [[ $repo_url == http* ]]; then
                git init
                git remote add origin "$repo_url"
                git add .
                git commit -m "first time setup"
        else
            echo "Failed to capture repository URL: $repo_url"
            exit 1
        fi
        # Additional logic for connecting to an existing repo can be added here
    elif [[ "$choice" == "2" ]]; then
        echo "Fetching repositories from your GitHub account..."
        # Get list of repositories and number them
        local i=1
        declare -A repo_map
        while IFS= read -r repo; do
            echo "$i) $repo"
            repo_map[$i]=$repo
            ((i++))
        done < <(gh repo list --limit 100 | awk '{print $1}')

        read -p "Select the repository number to connect: " repo_choice
        selected_repo=${repo_map[$repo_choice]}

        if [[ -z "$selected_repo" ]]; then
            echo "Invalid selection. Please try again."
            exit 1
        fi

        echo "Connecting to repository $selected_repo"
	git init
        git remote add origin "https://github.com/$selected_repo.git"
	git add .
	git commit -m "first time setup"
	git push -u origin main
    else
        echo "Invalid choice. Please enter 1 or 2."
        exit 1
    fi
# Initial commit and push
    git add .
    git commit -m "Initial commit"
    git branch -M main
    git push -u origin main
    if [[ $? -ne 0 ]]; then
        echo "Failed to push to GitHub. Please check your connection and try again."
        exit 1
    fi
}
# Function to handle gitx push
gitx_push() {
    # Check if the current directory is a Git repository
    if ! git rev-parse --is-inside-work-tree &> /dev/null; then
        echo "This directory is not a Git repository. Initiating 'gitx ship' to set up a repository."
        gitx_ship
        return
    fi

    check_and_install_tool "git"
    echo "Enter your commit message (type 'END' on a new line to finish):"
    commit_msg=""
    while IFS= read -r line; do
        if [[ "$line" == "END" ]]; then
            break
        fi
        commit_msg+="$line\n"
    done

    git add .
    git commit -m "$commit_msg"
    git push -u origin main
    if [[ $? -ne 0 ]]; then
        echo "Failed to push to GitHub. Please check your connection and try again."
        exit 1
    fi
}

# Main logic to handle gitx command
if [[ "$1" == "ship" ]]; then
    gitx_ship
elif [[ "$1" == "push" ]]; then
    gitx_push
else
    echo "Invalid command. Use 'gitx ship' or 'gitx push'."
fi

