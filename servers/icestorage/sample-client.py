#!/usr/bin/python -u
# SPDX-FileCopyrightText: 2017 Joachim Bauch / struktur AG <bauch@struktur.de>
#
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
try:
  import json
except ImportError:
  import simplejson as json
import logging
import random
try:
  import readline
except ImportError:
  # Ignore, readline is optional
  pass
import socket
import sys
import threading
import time
import urllib2

import sys
sys.path.append('..')

try:
  from x86_64 import re_rtpstream
except ImportError:
  from openrisc import re_rtpstream

class PutRequest(urllib2.Request):

  def get_method(self):
    return 'PUT'

def deferCall(delay, f, *args, **kw):

  class DeferThread(threading.Thread):
    def run(self):
      time.sleep(delay)
      f(*args, **kw)

  t = DeferThread()
  t.start()

def splitServer(server, defaultPort):
  if ':' in server:
    hostname, port = server.split(':', 1)
  else:
    hostname = server
    port = defaultPort
  return hostname, int(port)

class ICESocket(re_rtpstream.CyICESock):

  connected = False
  failed = False

  other = None
  storage_id = None

  def __init__(self, *args, **kw):
    super(ICESocket, self).__init__(*args, **kw)
    self.data = {
      'ufrag': self.local_ufrag,
      'pwd': self.local_pwd,
    }

  def setStorageServer(self, url, disableStun=False, disableTurn=False):
    self.storage_url = url
    data = self.storeData()
    if not disableStun:
      self._setStunData(data.get('stun', None))
    else:
      print 'STUN is disabled'
    if not disableTurn:
      self._setTurnData(data.get('turn', None))
    else:
      print 'TURN is disabled'
    self.startGathering()

  def _setStunData(self, stun):
    if not stun:
      print 'No STUN settings received'
      return

    hostname, port = splitServer(stun['server'], 3478)
    ip = socket.gethostbyname(hostname)
    print 'Using STUN server %s (%s:%d)' % (stun['server'], ip, port)
    self.setStunServer(ip, port)

  def _setTurnData(self, turn):
    if not turn:
      print 'No TURN settings received'
      return

    hostname, port = splitServer(turn['server'], 3478)
    ip = socket.gethostbyname(hostname)
    print 'Using TURN server %s (%s:%d) with credentials %s / %s' % (
        turn['server'], ip, port, turn['username'], turn['password'])
    self.setTurnServer(ip, port, turn['username'], turn['password'])

  def storeData(self):
    data = json.dumps(self.data)
    headers = {
      'Content-Type': 'application/json',
    }
    url = self.storage_url
    if self.storage_id:
      headers['X-icestorage-token'] = self.storage_token
      if url[-1:] != '/':
        url += '/'
      request = urllib2.Request(url + self.storage_id, data, headers)
    else:
      request = PutRequest(url, data, headers)

    response = urllib2.urlopen(request)
    data = json.loads(response.read())
    if not self.storage_id:
      self.storage_id = data['id']
      self.storage_token = data['token']
      print 'Stored data as remote id', self.storage_id
    return data

  def loadData(self, id):
    url = self.storage_url
    if url[-1:] != '/':
      url += '/'
    request = urllib2.Request(url + id)
    response = urllib2.urlopen(request)
    data = response.read()
    return json.loads(data)

  def setRemoteId(self, id):
    data = self.loadData(id)
    print 'Loaded data for remote id', id
    self.setRemoteCredentials(data['ufrag'], data['pwd'])
    self.setRemoteCandidates(data['candidates'])

  def onCandidates(self, candidates):
    #print 'onCandidates:', candidates
    self.data['candidates'] = candidates
    data = self.storeData()
    if self.other is None:
      return

    # The "id" should now be sent through DTMF to the remote peer.
    # Defer a bit to simulate delayed input.
    deferCall(1.0 + random.random(), self.other.setRemoteId, data['id'])

  def onConnectionError(self, err):
    print 'onConnectionError:', err
    self.failed = True

  def onConnected(self, update):
    print 'onConnected:', update
    self.connected = True

def main_loopback():
  if len(sys.argv) < 2:
    print >> sys.stderr, 'USAGE: %s <storage-url>' % (sys.argv[0])
    sys.exit(1)

  re_rtpstream.libreinit()

  storage_url = sys.argv[1]
  print 'Using %s as storage server' % (storage_url)

  alice = ICESocket("alice", re_rtpstream.ICE_ROLE_CONTROLLING)
  bob = ICESocket("bob", re_rtpstream.ICE_ROLE_CONTROLLING)
  alice.other = bob
  bob.other = alice

  alice.setStorageServer(storage_url)
  bob.setStorageServer(storage_url)

  print 'Waiting for connections to be established ...'
  connected = set()
  start = time.time()
  timeout = start + 60*3
  while len(connected) < 2:
    if time.time() > timeout:
      raise TypeError('Timeout while waiting for connection')

    time.sleep(0.01)
    if alice.connected:
      connected.add(alice)
    elif alice.failed:
      raise TypeError('Could not establish connection for Alice')

    if bob.connected:
      connected.add(bob)
    elif bob.failed:
      raise TypeError('Could not establish connection for Bob')

  print 'Connections established, took %.3f seconds (including delay)' % (time.time() - start)
  alice.sendString("Hello from Alice")
  bob.sendString("Hello from Bob")

  time.sleep(20)

def main():
  try:
    sys.argv.remove('--no-stun')
  except ValueError:
    no_stun = False
  else:
    no_stun = True

  try:
    sys.argv.remove('--no-turn')
  except ValueError:
    no_turn = False
  else:
    no_turn = True

  if len(sys.argv) < 2:
    print >> sys.stderr, 'USAGE: %s [options] <storage-url>' % (sys.argv[0])
    sys.exit(1)

  re_rtpstream.libreinit()

  storage_url = sys.argv[1]
  print 'Using %s as storage server' % (storage_url)

  sock = ICESocket("iceconn", re_rtpstream.ICE_ROLE_CONTROLLING)
  sock.setStorageServer(storage_url, no_stun, no_turn)

  try:
    remote_id = raw_input("remote> ")
    remote_id = remote_id.strip()
  except EOFError:
    remote_id = None
  if not remote_id:
    print 'Cancelled'
    return
  elif remote_id == sock.storage_id:
    print 'Can\'t connect to the own id'
    return

  sock.setRemoteId(remote_id)

  print 'Waiting for connection to be established ...'
  connected = set()
  start = time.time()
  timeout = start + 60*3
  while not sock.connected:
    if time.time() > timeout:
      raise TypeError('Timeout while waiting for connection')

    time.sleep(0.01)
    if sock.failed:
      raise TypeError('Could not establish connection')

  print 'Connection established, took %.3f seconds' % (time.time() - start)
  sock.sendString("Hello from ICE connection")

  time.sleep(20)

if __name__ == '__main__':
  #logging.basicConfig(level=logging.DEBUG)
  main()
