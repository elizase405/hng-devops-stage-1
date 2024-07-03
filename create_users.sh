#!/usr/bin/bash

# Function to generate a random password
generate_password() {
	openssl rand -base64 16
}

# Log file to record actions
LOG_FILE="/var/log/user_management.log"

# File to store passwords securely
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Input file containing usernames and groups
INPUT_FILE=$1

# Check if the script is run with root privileges
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root. Use 'sudo $0'." >&2
    exit 1
fi

# Loop through each line in the input file
while IFS=';' read -r username groups_str; do
    # Remove any leading or trailing whitespace from username and groups
    username=$(echo "$username" | tr -d '[:space:]')
    groups_str=$(echo "$groups_str" | tr -d '[:space:]')

    # Check if the username and groups are provided
    if [ -z "$username" ] || [ -z "$groups_str" ]; then
        echo "Error: Invalid input format. Skipping line."
        echo "Invalid input: $username; $groups_str" >> "$LOG_FILE"
        continue
    fi

    # Split groups by comma into an array
    IFS=',' read -ra groups <<< "$groups_str"

    # Create user's primary group if it doesn't exist
    if ! grep -q "^$username:" /etc/passwd; then
        groupadd "$username"
        echo "Group $username created." >> "$LOG_FILE"
    fi

    # Create the user if it doesn't exist
    if ! id "$username" &>/dev/null; then
        password=$(generate_password)
        useradd -m -s /bin/bash -g "$username" "$username"
        echo "$username:$password" | chpasswd
        echo "User $username with password $password created." >> "$LOG_FILE"
        echo "$username:$password" >> "$PASSWORD_FILE"
        chmod 600 "$PASSWORD_FILE"  # Secure permissions for password file
    else
        echo "User $username already exists. Skipping." >> "$LOG_FILE"
    fi

    # Add user to additional groups
    for group in "${groups[@]}"; do
        if ! grep -q "^$group:" /etc/group; then
            groupadd "$group"
            echo "Group $group created." >> "$LOG_FILE"
        fi
        usermod -a -G "$group" "$username"
        echo "User $username added to group $group." >> "$LOG_FILE"
    done

    # Set permissions on home directory
    if [ -d "/home/$username" ]; then
        chmod 700 "/home/$username"
        chown -R "$username:$username" "/home/$username"
        echo "Permissions set for /home/$username." >> "$LOG_FILE"
    fi

done < "$INPUT_FILE"

echo "Script execution completed."
