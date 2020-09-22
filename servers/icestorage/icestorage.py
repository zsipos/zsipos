#!/usr/bin/python3

# SPDX-FileCopyrightText: 2020 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-FileCopyrightText: 2017 Joachim Bauch / struktur AG <bauch@struktur.de>
# SPDX-License-Identifier: GPL-3.0-or-later

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

import tornado.web
import tornado.ioloop

import json
import random
import string
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
    for x in range(length-2):
        part = random.randint(0, 9)
        while part == rnd[x]:
            # Prevent duplicate characters.
            part = random.randint(0, 9)
        rnd.append(part)
    rnd.append(calculateChecksum(rnd))
    return ''.join(map(str, rnd))


def isValidRandomId(dtmfid):
    if not dtmfid or not dtmfid.isdigit():
        return False
    check = calculateChecksum(dtmfid[:-1])
    return check == int(dtmfid[-1])


def getRandomString(length):
    return ''.join(random.choice(string.ascii_lowercase) for _ in range(length))


class IceStorageHandler(tornado.web.RequestHandler):
    
    def _send_json(self, data):
        encoded = json.dumps(data, sort_keys=True, indent=4).encode("utf8")
        self.set_status(200)
        self.set_header('Content-Type', 'application/json')
        self.set_header('Content-Length', len(encoded))
        self.set_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.set_header('Pragma', 'no-cache')
        self.set_header('Expires', '0')
        self.write(encoded)

    def _getRequestBody(self):
        try:
            data = json.loads(self.request.body)
        except ValueError as e:
            self.set_status(400, 'Can\'t decode JSON: %s' % (e))
            return
        return data
    
    def get(self):
        path = self.request.path
        while '//' in path:
            path = path.replace('//', '/')
        if path[:1] == '/':
            path = path[1:]

        if not isValidRandomId(path):
            self.send_error(404)
            return

        data = self.application.getSettings(path)
        if data is None:
            self.send_error(404)
            return

        data = data.copy()
        data.pop('_update_token', None)
        self._send_json(data)

    def put(self):
        data = self._getRequestBody()
        if data is None:
            # Already returned an error
            return
        data['_update_token'] = getRandomString(32)
        dtmfid = self.application.storeSettings(data)
        response = {
          'id': dtmfid,
          'token': data['_update_token'],
        }
        self._send_json(response)

    def post(self):
        token = self.request.headers.get('X-icestorage-token', None)
        path = self.request.path
        while '//' in path:
            path = path.replace('//', '/')
        if path[:1] == '/':
            path = path[1:]
        dtmfid = path
        if not isValidRandomId(dtmfid):
            self.send_error(404)
            return
        data = self._getRequestBody()
        if data is None:
            # Already returned an error
            return
        stored_data = self.application.getSettings(dtmfid)
        if stored_data is None:
            self.send_error(404)
            return
        if token != stored_data['_update_token']:
            print('Update token mismatch', (token, stored_data['_update_token']))
            self.set_error(404)
            return
        data.pop('_update_token', None)
        stored_data.update(data)
        self.application.updateSettings(dtmfid, stored_data)
        self._send_json({
          'id': dtmfid,
          'token': stored_data['_update_token'],
        })
        
        
class IceStorageApp(tornado.web.Application):
    
    allow_reuse_address = True
    id_length           = 10

    def __init__(self, *args, **kwargs):
        tornado.web.Application.__init__(self, *args, **kwargs)
        self.data = {}

    def expireSetttings(self):
        now = time.time()
        for k, v in list(self.data.items()):
            if v['expires'] <= now:
                print('Expire settings', k)
                del self.data[k]

    def getSettings(self, dtmfid):
        self.expireSetttings()
        return self.data.get(dtmfid, None)

    def storeSettings(self, data):
        self.expireSetttings()
        dtmfid = generateRandomId(self.id_length)
        while dtmfid in self.data:
            dtmfid = generateRandomId(self.id_length)
        assert isValidRandomId(dtmfid), dtmfid
        data['expires'] = time.time() + EXPIRE_DELAY_SECONDS
        self.data[dtmfid] = data
        return dtmfid

    def updateSettings(self, dtmfid, data):
        data['expires'] = time.time() + EXPIRE_DELAY_SECONDS
        self.data[dtmfid] = data


def main():
    PORT = 9090
    print('Running server on :%d ...' % PORT)
    application = IceStorageApp([
        (r"/[0-9]*", IceStorageHandler),
    ])
    application.listen(PORT)
    tornado.ioloop.IOLoop.current().start()


if __name__ == '__main__':
    main()
