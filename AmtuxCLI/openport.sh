#!/bin/bash

# Function to print usage
usage() {
    echo "Usage: portmanager [-a|--action] <open|close> [-l|--local] <ports|all> [-f|--from] <IP/CIDR>"
    echo "       portmanager --help"
    echo ""
    echo "Options:"
    echo "  -a, --action  Specify the action to perform (open or close)"
    echo "  -l, --local   Specify ports to manage (comma-separated or 'all' for all ports)"
    echo "  -f, --from    Specify source IP range (CIDR notation or 'any')"
    echo "  --help        Display this help and exit"
    exit 1
}

# Function to parse ports
parse_ports() {
    echo $1 | tr ',' ' '
}

# Function to set the CIDR block
set_cidr() {
    if [[ $1 == "any" || $1 == "0.0.0.0" ]]; then
        echo "0.0.0.0/0"
    else
        echo $1
    fi
}

# Check for --help argument
if [[ "$1" == "--help" ]]; then
    usage
fi

# Check for arguments
if [ "$#" -lt 6 ]; then
    usage
fi

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -a|--action) action=$2; shift ;;
        -l|--local) local_ports=$(parse_ports $2); shift ;;
        -f|--from) from_source=$(set_cidr $2); shift ;;
        *) usage ;;
    esac
    shift
done

# Validate action
if [[ "$action" != "open" && "$action" != "close" ]]; then
    echo "Invalid action: $action"
    usage
fi

# Confirm if all ports are to be managed
if [[ "$local_ports" == "all" ]]; then
    read -p "Warning: You are about to $action all ports. Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 1
    fi
    local_ports=$(seq 1 65535)
fi

# Get AWS EC2 instance details
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
GROUP_ID=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[*].Instances[*].SecurityGroups[0].GroupId' --output text)

# Manage specified ports
success_ports=""
error_occurred=false
for port in $local_ports; do
    if [[ "$action" == "open" ]]; then
        cmd="authorize-security-group-ingress"
    else
        cmd="revoke-security-group-ingress"
    fi

    if aws ec2 $cmd --group-id $GROUP_ID --protocol tcp --port $port --cidr $from_source; then
        success_ports="$success_ports $port"
    else
        error_occurred=true
    fi
done

# Display success message
if [ -n "$success_ports" ]; then
    echo "${action^}ed ports:$success_ports on instance $INSTANCE_ID to IP range: $from_source"
elif [ "$error_occurred" = true ]; then
    echo -e "\e[1;31mNo ports were ${action}ed. Error ↑\e[0m"
else
    echo "No ports were ${action}ed."
fi

