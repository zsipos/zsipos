#!/usr/bin/python
"""
Copyright (C) 2017 Joachim Bauch / struktur AG <bauch@struktur.de>

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software Foundation,
   Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301
"""
import BaseHTTPServer
import binascii
import ConfigParser
import hashlib
import hmac
try:
  import json
except ImportError:
  import simplejson as json
import random
import string
import SocketServer
import time

# Stored data is valid for 5 minutes
EXPIRE_DELAY_SECONDS = 5 * 60

def calculateChecksum(s):
  check = 7
  for ch in s:
    check = (check ^ int(ch)) % 10
  return check

def generateRandomId(length):
  # Don't start with a leading zero.
  rnd = [random.randint(1, 9)]
  for x in xrange(length-2):
    part = random.randint(0, 9)
    while part == rnd[x]:
      # Prevent duplicate characters.
      part = random.randint(0, 9)
    rnd.append(part)
  rnd.append(calculateChecksum(rnd))
  return ''.join(map(str, rnd))

def isValidRandomId(id):
  if not id or not id.isdigit():
    return False

  check = calculateChecksum(id[:-1])
  return check == int(id[-1])

def getRandomString(length):
  return ''.join(random.choice(string.lowercase) for i in range(length))

class IceStorageHandler(BaseHTTPServer.BaseHTTPRequestHandler):

  def send_json(self, data):
    encoded = json.dumps(data, sort_keys=True, indent=4)
    self.send_response(200)
    self.send_header('Content-Type', 'application/json')
    self.send_header('Content-Length', len(encoded))
    self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
    self.send_header('Pragma', 'no-cache')
    self.send_header('Expires', '0')
    self.end_headers()
    self.wfile.write(encoded)

  def do_GET(self):
    path = self.path
    while '//' in path:
      path = path.replace('//', '/')
    if path[:1] == '/':
      path = path[1:]

    if not isValidRandomId(path):
      self.send_error(404)
      return

    data = self.server.getSettings(path)
    if data is None:
      self.send_error(404)
      return

    data = data.copy()
    data.pop('_update_token', None)
    self.send_json(data)

  def _getRequestBody(self):
    content_len = int(self.headers.getheader('Content-Length', 0))
    data = self.rfile.read(content_len)
    if not data:
      self.send_error(400)
      return

    try:
      data = json.loads(data)
    except ValueError, e:
      self.send_error(400, 'Can\'t decode JSON: %s' % (e))
      return

    return data

  def do_PUT(self):
    data = self._getRequestBody()
    if data is None:
      # Already returned an error
      return

    data['_update_token'] = getRandomString(32)
    id = self.server.storeSettings(data)
    response = {
      'id': id,
      'token': data['_update_token'],
    }
    try:
      stun_server = self.server.config.get('stun', 'server')
    except ConfigParser.NoOptionError:
      stun_server = None
    if stun_server:
      response['stun'] = {
        'server': stun_server,
      }
    try:
      turn_server = self.server.config.get('turn', 'server')
      turn_secret = self.server.config.get('turn', 'shared-secret')
    except ConfigParser.NoOptionError:
      turn_server = turn_secret = None
    if turn_server and turn_secret:
      response['turn'] = {
        'server': turn_server,
      }
      # temporary-username = "timestamp" + ":" + "username"
      now = int(time.time())
      random_username = getRandomString(16)
      temp_username = str(now) + ':' + random_username

      # temporary-password = base64_encode(hmac-sha1(
      #     input = temporary-username, key = shared-secret))
      h = hmac.new(turn_secret, digestmod=hashlib.sha1)
      h.update(temp_username)
      raw_password = h.digest()

      response['turn']['username'] = temp_username
      response['turn']['password'] = binascii.b2a_base64(raw_password).strip()

    self.send_json(response)

  def do_POST(self):
    token = self.headers.getheader('X-icestorage-token', None)
    path = self.path
    while '//' in path:
      path = path.replace('//', '/')
    if path[:1] == '/':
      path = path[1:]

    id = path
    if not isValidRandomId(id):
      self.send_error(404)
      return

    data = self._getRequestBody()
    if data is None:
      # Already returned an error
      return

    stored_data = self.server.getSettings(id)
    if stored_data is None:
      self.send_error(404)
      return

    if token != stored_data['_update_token']:
      print 'Update token mismatch', (token, stored_data['_update_token'])
      self.send_error(404)
      return

    data.pop('_update_token', None)
    stored_data.update(data)
    self.server.updateSettings(id, stored_data)
    self.send_json({
      'id': id,
      'token': stored_data['_update_token'],
    })

class IceStorageServer(SocketServer.TCPServer):
  
  allow_reuse_address = True

  id_length = 10

  def __init__(self, *args, **kw):
    SocketServer.TCPServer.__init__(self, *args, **kw)
    self.config = ConfigParser.ConfigParser()
    self.config.read('server.conf')
    self.data = {}

  def expireSetttings(self):
    now = time.time()
    for k, v in self.data.items():
      if v['expires'] <= now:
        print 'Expire settings', k
        del self.data[k]

  def getSettings(self, id):
    self.expireSetttings()
    return self.data.get(id, None)

  def storeSettings(self, data):
    self.expireSetttings()
    id = generateRandomId(self.id_length)
    while id in self.data:
      id = generateRandomId(self.id_length)
    assert isValidRandomId(id), id
    data['expires'] = time.time() + EXPIRE_DELAY_SECONDS
    self.data[id] = data
    return id

  def updateSettings(self, id, data):
    data['expires'] = time.time() + EXPIRE_DELAY_SECONDS
    self.data[id] = data

def main():
  PORT = 9090
  httpd = IceStorageServer(('', PORT), IceStorageHandler)
  print 'Running server on :%d ...' % PORT
  httpd.serve_forever()

if __name__ == '__main__':
  main()
