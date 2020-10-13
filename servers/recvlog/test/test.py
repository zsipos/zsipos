import io
import os
import requests
import subprocess
import collections.abc

url = "http://update.zsipos.com/cgi-bin/recvlog.py"
sendfiles = [ 'test.py' ]

def do_send_http(url, files):

    class MyFile():
        
        def __init__(self, name):
            self.total_size = os.path.getsize(name)
            self.done = 0
            self.last_percent = -1
            self.f = open(name, "rb")
            
        def read(self, l=-1):
            #print("read", l)
            b = self.f.read(l)
            self.done += len(b)
            percent = 100 * self.done // self.total_size
            if percent > self.last_percent:
                self.last_percent = percent
                print(percent, "%")
            return b
        
        def seek(self, offset, whence=io.SEEK_SET):
            r = self.f.seek(offset, whence)
            #print("seek", offset, whence, r)
            return r
        
        def tell(self):
            r = self.f.tell()
            #print("tell", r)
            return r
        
        def close(self):
            self.f.close()
            self.f = None
            
    class MyIter(collections.abc.Iterator):
        
        def __init__(self, f):
            self.f = f 
            
        def __iter__(self):
            return self
        
        def __next__(self):
            block = self.f.read(1024)
            if block == b"":
                raise StopIteration
            return block
        
        def __len__(self):
            return total_size
                 
                        
    logpack_name = '/tmp/logpack.tgz'
    chunk_size = 1024 * 8
    total_size = 0
    processed = 0
    last_percent = -1
    for i in files:
        total_size += 512 #file header
        file_size = os.path.getsize(i)
        blocks = file_size // 512
        if file_size % 512: #pad last block
            blocks += 1 
        total_size += blocks * 512
    total_size += 1024 #end blocks
    print("prepare upload..")
    proc_tar = subprocess.Popen(["tar",  "cf",  "-"] + files, stdout=subprocess.PIPE)
    proc_gzip = subprocess.Popen(["gzip -c >" + logpack_name], stdin=subprocess.PIPE, shell=True)
    for block in iter(lambda: proc_tar.stdout.read(chunk_size), b""):
        proc_gzip.stdin.write(block)
        processed += len(block)
        percent = 100 * processed // total_size
        if percent > 100:
            percent = 100
        if (percent > last_percent):
            last_percent = percent
            print(percent, "%")
    proc_tar.wait()
    proc_gzip.stdin.close()
    proc_gzip.wait()
    print("upload..")
    total_size = os.path.getsize(logpack_name)
    headers = {"content-type": "application/octet-stream"}
    headers["content-length"] = str(total_size)
    f = MyFile(logpack_name)
    # normal file send
    data = f 
    # chunked iterator send
    data = iter(lambda: f.read(512), b"")
    # non-chunked iterator send
    data = MyIter(f)
    r=requests.post(url, data=data, headers=headers)
    print("reply=", r.text)
    f.close()


do_send_http(url, sendfiles)
