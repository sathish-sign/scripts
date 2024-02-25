import requests
metadata_url = "http://metadata.google.internal/computeMetadata/v1/project/numeric-project-id"
headers = {'Metadata-Flavor': 'Google'}
response = requests.get(metadata_url, headers=headers)
print(type(response))
print(response)
