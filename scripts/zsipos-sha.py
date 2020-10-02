import hashlib

GRPLEN = 4
LLEN = 2

sha256_hash = hashlib.sha256()
with open ("output/rootfs.tar.gz", "rb") as f:
    # Read and update hash string value in blocks of 4K
    for byte_block in iter(lambda: f.read(8192), b""):
        sha256_hash.update(byte_block)
d = sha256_hash.hexdigest().upper()
n = 0
while len(d):
    print(d[:GRPLEN], '', end='')
    d = d[GRPLEN:]
    n += 1
    if n % LLEN == 0:
        print()

