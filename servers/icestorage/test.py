# SPDX-FileCopyrightText: 2020 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

import urllib.request
import json

baseurl = "http://127.0.0.1:9090"

class PostRequest(urllib.request.Request):
    
    def get_method(self):
        return "POST"

    
class PutRequest(urllib.request.Request):
    
    def get_method(self):
        return "PUT"


class GetRequest(urllib.request.Request):

    pass


#get new id
data = "{}".encode("utf8")
headers = { 'Content-Type': 'application/json'  }
req = PutRequest(baseurl, data, headers)
res = urllib.request.urlopen(req)
data = json.loads(res.read().decode("utf8"))
id = data['id']
token = data['token']
print("new data:", data)
print()

#updata data
data['newdata'] = 'Alle meine Entchen'
headers = { 'Content-Type': 'application/json',  'X-icestorage-token': token }
data = json.dumps(data).encode("utf8")
print("post data:", data)
print()
req = PostRequest(baseurl + '/' + id, data, headers)
res = urllib.request.urlopen(req)

#retrieve data
req = GetRequest(baseurl + '/' + id)
res = urllib.request.urlopen(req)
data = json.loads(res.read().decode("utf8"))
print("retrieved data:", data)
print()

