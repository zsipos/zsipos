import hashlib

GRPLEN = 4
LLEN   = 2

def add_file(filename, hash):
    with open (filename, "rb") as f:
        # Read and update hash string value in blocks of 4K
        for byte_block in iter(lambda: f.read(8192), b""):
            hash.update(byte_block)

hash = hashlib.sha256()

add_file("output/update.txt", hash)
add_file("output/rootfs.tar.gz", hash)

d = hash.hexdigest().upper()

n = 0
while len(d):
    print(d[:GRPLEN], '', end='')
    d = d[GRPLEN:]
    n += 1
    if n % LLEN == 0:
        print()

