import io
import os
import requests
import subprocess

url = "http://127.0.0.1:8000/cgi-bin/recvlog.py"
files = [ "test.py" ]


LOGSEND_GZIP    = False
LOGSEND_CHUNKED = False

def do_send_http(url, files):
    
    def to_upload_progress(s):
        print(s)
    
    def update_percent(percent):
        nonlocal last_percent
        
        if (percent > last_percent):
            if (percent > 100):
                percent = 100
            last_percent = percent
            print(percent, "%")
            
    try:    
        print("uploading logfiles started...")
        logpack_name = 'logpack.tgz'
        chunk_size = 1024 * 8
        last_percent = -1
        total_size = 0
        for i in files:
            total_size += 512 #file header
            file_size = os.path.getsize(i)
            blocks = file_size // 512
            if file_size % 512: #pad last block
                blocks += 1 
            total_size += blocks * 512
        total_size += 1024 #end blocks
        proc_tar = subprocess.Popen(["tar",  "cf",  "-"] + list(files), stdout=subprocess.PIPE)
        if LOGSEND_GZIP: 
            
            class MyFile():
                """local helper class for progress display"""
                
                def __init__(self, name):
                    self.total_size = os.path.getsize(name)
                    self.done = 0
                    self.f = open(name, "rb")
                    
                def read(self, l=-1):
                    b = self.f.read(l)
                    self.done += len(b)
                    update_percent(100 * self.done // self.total_size)
                    return b
                
                def seek(self, offset, whence=io.SEEK_SET):
                    return self.f.seek(offset, whence)
                
                def tell(self):
                    return self.f.tell()
                
                def close(self):
                    self.f.close()
                    self.f = None
        
            to_upload_progress("preparing: ")
            proc_gzip = subprocess.Popen(["gzip -1 -c >" + logpack_name], stdin=subprocess.PIPE, shell=True)
            for block in iter(lambda: proc_tar.stdout.buffer.read(chunk_size), b""):
                proc_gzip.stdin.write(block)
                processed += len(block)
                update_percent(100 * processed // total_size)
            proc_tar.wait()
            proc_gzip.stdin.close()
            proc_gzip.wait()
            update_percent(100)
            to_upload_progress("done.\n")
            data = MyFile(logpack_name)
            
        else: # !LOGSEND_GZIP
            
            if LOGSEND_CHUNKED:
                
                def do_read():
                    """local helper function for progress display"""
                    nonlocal processed
                    block = proc_tar.stdout.read(chunk_size)
                    if block == b"":
                        proc_tar.wait()
                    processed += len(block)
                    update_percent(100 * processed // total_size)
                    return block
                
                processed = 0                
                data = iter(lambda: do_read(), b"")
            
            else: # !LOGSEND_CHUNKED
                
                class MyIter:                    
                    """local ierator class with len function for progess display"""
                    
                    def __init__(self):
                        self.done = 0
                    
                    def __iter__(self):
                        return self
                    
                    def __next__(self):
                        block = proc_tar.stdout.read(chunk_size)
                        if block == b"":
                            proc_tar.wait()
                            raise StopIteration
                        self.done += len(block)
                        update_percent(100 * self.done // total_size)
                        return block
                    
                    def __len__(self):
                        return total_size
                            
                data = MyIter()
                
        to_upload_progress("uploading: ")
        last_percent = -1
        headers = {'content-type': 'application/octet-stream'}
        reply=requests.post(url, data=data, headers=headers)
        print(reply.text)
        update_percent(100)
        to_upload_progress("done.\nall selected logfiles uploaded.\n")
                
    except:
        raise
     

do_send_http(url, files)

