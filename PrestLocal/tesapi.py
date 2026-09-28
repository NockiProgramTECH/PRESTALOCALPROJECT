import requests

url = "https://developersandbox-api.flutterwave.com/customers?page=1&size=10"

headers = {"accept": "application/json"}

response = requests.get(url, headers=headers)

print(response.text)