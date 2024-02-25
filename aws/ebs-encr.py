'''
    This pyhton module will check for EBS volumes attached to EC2 instance are encypted or not.
    if not it will stop the instance and makes the snap shot of all attached volumes.
    makes copy of each snapshot with default ebs encryption.
    then created volumes from the   
    and then start the instance again.
'''
import argparse
import boto3

def parse_args():
    '''
        this function prints the details to use the function if required argumets are not passed
    '''
    parser = argparse.ArgumentParser(description='Encrypt EBS volumes attached to an EC2 instance.')
    parser.add_argument('instance_id', help='The ID of the EC2 instance.')
    parser.add_argument('region', help='The AWS region of the instance.')
    return parser.parse_args()

def check_all_volumes_encrypted(ec2, instance_id):
    '''
        checks whether attached volumes ate encrypted or not
    '''
    response = ec2.describe_volumes(Filters=[{'Name': 'attachment.instance-id', 'Values': [instance_id]}])
    return all(volume['Encrypted'] for volume in response['Volumes'])

def stop_instance(ec2, instance_id):
    '''
        stops the instance and waits untils instance is stopped
    '''
    print(f"Stopping instance {instance_id}...")
    ec2.stop_instances(InstanceIds=[instance_id])
    waiter = ec2.get_waiter('instance_stopped')
    waiter.wait(InstanceIds=[instance_id])
    print("Instance is stopped.")

def start_instance(ec2, instance_id):
    '''
        starts the instance and waits until instance is started
    '''
    print(f"Starting instance {instance_id}...")
    ec2.start_instances(InstanceIds=[instance_id])
    waiter = ec2.get_waiter('instance_running')
    waiter.wait(InstanceIds=[instance_id])
    print("Instance is started.")

def main():
    '''
        This is main function
        calls the other functions
    '''
    args = parse_args()
    ec2 = boto3.client('ec2', region_name=args.region)

    # Check if all volumes are already encrypted
    if check_all_volumes_encrypted(ec2, args.instance_id):
        print("All volumes are already encrypted. No action needed.")
        return

    # If not all volumes are encrypted, proceed with stopping the instance, encrypting volumes, etc.
    stop_instance(ec2, args.instance_id)

    # Insert logic for encrypting volumes here. You might need to implement or adjust this part based on your specific needs.
    start_instance(ec2, args.instance_id)

if __name__ == "__main__":
    main()
