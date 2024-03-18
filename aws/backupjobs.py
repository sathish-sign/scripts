import boto3
from datetime import datetime, timedelta
import csv

# Parameters for the role to assume
role_arn = "arn:aws:iam::<account_id>:role/<switch_role>"
session_name = "assumeRoleSession"

# Create an STS client
sts_client = boto3.client('sts')

# Assume the role
assumed_role_object = sts_client.assume_role(
    RoleArn=role_arn,
    RoleSessionName=session_name,
)

# Extract the temporary security credentials
credentials = assumed_role_object['Credentials']

# Use the temporary credentials to create a session
session = boto3.Session(
    aws_access_key_id=credentials['AccessKeyId'],
    aws_secret_access_key=credentials['SecretAccessKey'],
    aws_session_token=credentials['SessionToken'],
)

# Use the session to create a client for the desired service
backup_client = session.client('backup', region_name="ap-south-1")

# Fetch backup jobs (adjust this call as needed, e.g., by specifying a time range)
response = backup_client.list_backup_jobs()

# Now, proceed with your logic, for example, filtering jobs by date and writing to CSV
# Calculate dates for filtering
first_day_of_current_month = datetime.utcnow().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
first_day_of_previous_month = (first_day_of_current_month - timedelta(days=1)).replace(day=1)

# Prepare CSV file
csv_filename = "backups_previous_month.csv"
with open(csv_filename, mode='w', newline='') as file:
    writer = csv.writer(file)
    writer.writerow(["BackupJobId", "State", "ResourceName", "ResourceType", "CreationDate"])

    # Iterate over backup jobs and filter by date
    for job in response.get('BackupJobs', []):
        creation_date = datetime.strptime(job['CreationDate'], '%Y-%m-%dT%H:%M:%SZ')
        if first_day_of_previous_month <= creation_date < first_day_of_current_month:
            writer.writerow([job['BackupJobId'], job['State'], job['ResourceName'], job['ResourceType'], job['CreationDate']])

print(f"CSV file '{csv_filename}' has been created with backups from the previous month.")
