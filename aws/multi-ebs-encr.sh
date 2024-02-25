# This script will check for the attached volumes of the provided instance ID, verifying whether all volumes are encrypted. 
# If any volumes are not encrypted, the script will create a snapshot, encrypt it, and attach it
#!/bin/bash

set -e

# Check if sufficient arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <Instance ID> <AWS Region>"
    exit 1
fi

# Set your variables
INSTANCE_ID=$1
REGION=$2

# Function to check the encryption status of all volumes attached to the instance
check_all_volumes_encrypted() {
    local instance_id=$1
    local all_encrypted=true

    # Fetch all volumes attached to the instance
    volumes_info=$(aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=$instance_id --query "Volumes[*].{Encrypted:Encrypted}" --output text --region $REGION)

    # Check if any volume is not encrypted
    for encrypted in $volumes_info; do
        if [ "$encrypted" == "False" ]; then
            all_encrypted=false
            break
        fi
    done
    echo $all_encrypted
}


# Check if all volumes are encrypted
all_encrypted=$(check_all_volumes_encrypted $INSTANCE_ID)

if [ "$all_encrypted" == "true" ]; then
    echo "All volumes are already encrypted. No action needed."
    exit 0
else
    echo "Not all volumes are encrypted. Proceeding with encryption process."
fi

# Function to stop the instance
stop_instance() {
    echo "Stopping instance $INSTANCE_ID..."
    aws ec2 stop-instances --instance-ids $INSTANCE_ID --region $REGION
    aws ec2 wait instance-stopped --instance-ids $INSTANCE_ID --region $REGION
    echo "Instance $INSTANCE_ID is stopped."
}

# Function to encrypt a volume
encrypt_volume() {
    local volume_id=$1
    local device_name=$2

    # Fetch volume configuration
    local volume_info=$(aws ec2 describe-volumes --volume-ids $volume_id --query "Volumes[0].{Size:Size,VolumeType:VolumeType,Iops:Iops,Throughput:Throughput}" --output json --region $REGION)
    local size=$(echo $volume_info | jq -r '.Size')
    local volume_type=$(echo $volume_info | jq -r '.VolumeType')
    local iops=$(echo $volume_info | jq -r '.Iops')
    local throughput=$(echo $volume_info | jq -r '.Throughput')

    echo "Creating snapshot of volume $volume_id..."
    local snapshot_id=$(aws ec2 create-snapshot --volume-id $volume_id --query "SnapshotId" --output text --region $REGION)

    echo "Waiting for snapshot $snapshot_id to be available..."
    aws ec2 wait snapshot-completed --snapshot-ids $snapshot_id --region $REGION

    echo "Creating encrypted copy of snapshot $snapshot_id..."
    local encrypted_snapshot_id=$(aws ec2 copy-snapshot --source-snapshot-id $snapshot_id --source-region $REGION --encrypted --query "SnapshotId" --output text --region $REGION)

    echo "Waiting for encrypted snapshot $encrypted_snapshot_id to be available..."
    aws ec2 wait snapshot-completed --snapshot-ids $encrypted_snapshot_id --region $REGION

    echo "Creating new encrypted volume from snapshot $encrypted_snapshot_id..."
    local create_volume_args="--snapshot-id $encrypted_snapshot_id --availability-zone ${REGION}a --volume-type $volume_type --size $size --encrypted --query 'VolumeId' --output text --region $REGION"
    
    # Conditionally add IOPS and Throughput if applicable
    if [[ "$volume_type" == "io1" || "$volume_type" == "io2" ]]; then
        create_volume_args="$create_volume_args --iops $iops"
    elif [[ "$volume_type" == "gp3" ]]; then
        create_volume_args="$create_volume_args --iops $iops --throughput $throughput"
    fi

    local new_volume_id=$(eval aws ec2 create-volume $create_volume_args)

    echo "New encrypted volume $new_volume_id created from snapshot $encrypted_snapshot_id."

    echo "Waiting for volume $new_volume_id to be available..."
    aws ec2 wait volume-available --volume-ids $new_volume_id --region $REGION

    echo "Detaching old volume $volume_id..."
    aws ec2 detach-volume --volume-id $volume_id --region $REGION
    aws ec2 wait volume-available --volume-ids $volume_id --region $REGION

    echo "Attaching new volume $new_volume_id as $device_name..."
    aws ec2 attach-volume --volume-id $new_volume_id --instance-id $INSTANCE_ID --device $device_name --region $REGION
    aws ec2 wait volume-in-use --volume-ids $new_volume_id --region $REGION
}


# Main script starts here
stop_instance

# Get all volumes attached to the instance
volumes_info=$(aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=$INSTANCE_ID --query "Volumes[*].{ID:VolumeId,Device:Attachments[0].Device}" --output text --region $REGION)

# Process each volume
while read -r device_name volume_id; do
    echo "Processing volume $volume_id attached as $device_name"
    # Encrypt volume
    encrypt_volume $volume_id $device_name
done <<< "$volumes_info"

# Start the instance
echo "Starting instance $INSTANCE_ID..."
aws ec2 start-instances --instance-ids $INSTANCE_ID --region $REGION
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION
echo "Instance $INSTANCE_ID has been started with all volumes encrypted."
