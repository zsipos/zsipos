#!/usr/bin/python3
import os
import subprocess
import sys
import signal
import time
import traceback

tmpdir    = "/tmp/zsipos_tmp"
rcvdir    = "/tmp/zsipos_rcv"
keeptemp  = True	# keep temporary files after error
debug     = True 
timeout   = 120		# timeout in seconds
blocksize = 8192	# for read operations

v = os.environ.get("RECVLOG_TMPDIR")
if v:
	tmpdir = v
v = os.environ.get("RECVLOG_RCVDIR")
if v:
	rcvdir = v

def alarm_signal(signum, frame):
	sys.stderr.write("timeout after %d bytes\n" % (total_len,))
	sys.exit(0)


def get_filename():
	return time.strftime("%Y%m%d_%H%M%S") + "_" + str(os.getpid())
	

def receive_with_len(f, length):
	global total_len
	length = int(os.environ["CONTENT_LENGTH"])
	done = 0
	while done < length:
		signal.alarm(timeout)
		block = sys.stdin.buffer.read(min(length - done, blocksize))
		if len(block) == 0:
			sys.stderr.write("EOF while reading data\n")
			break
		f.write(block)
		done += len(block)
		total_len = done
	signal.alarm(0)


def myreadline(f):
	ret = b""
	while True:
		c = f.read(1)
		ret += c
		if c == b"":
			return b""
		elif c == b"\n":
			return ret
		
		
def receive_chunked(f):
	global total_len
	while True:
		signal.alarm(timeout)
		chunk_len = myreadline(sys.stdin.buffer)
		if chunk_len == b"":
			sys.stderr.write("EOF while expecting chunk size\n")
			break
		chunk_len = int(chunk_len[:-2], 16)
		if chunk_len == 0:
			break
		read_len = 0
		while read_len < chunk_len:
			signal.alarm(timeout)
			block = sys.stdin.buffer.read(min(blocksize, chunk_len-read_len))
			if block == b"":
				sys.stderr.write("EOF while expecting chunk data\n")
				break
			read_len += len(block)
			f.write(block)
		total_len += read_len
		signal.alarm(timeout)
		if myreadline(sys.stdin.buffer) == b"":
			sys.stderr.write("EOF while expecting newline\n")
			break
	signal.alarm(0)


print("Content-Type: text/html")    # HTML is following
print()                             # blank line, end of headers

try:
	os.makedirs(tmpdir, exist_ok=True)
	os.makedirs(rcvdir, exist_ok=True)
	signal.signal(signal.SIGALRM, alarm_signal)
	length = os.environ.get("CONTENT_LENGTH")
	total_len = 0
	tmpname = os.path.join(tmpdir, get_filename())
	with open(tmpname, "wb") as f:
		if not length or length == '':
			print("receiving chunked data.")
			receive_chunked(f)
		else:
			print("receiving %s bytes." % (length,))
			receive_with_len(f, int(length))
	rcvname = os.path.join(rcvdir, get_filename())
	os.rename(tmpname, rcvname) 
except:
	if debug:
		traceback.print_exc(file=sys.stdout)
	print("sorry, got an error")
	if not keeptemp and os.path.exists(tmpname):
		os.remove(tmpname)
	raise

print("%d bytes received." % (total_len,))
print("Thank you.")

