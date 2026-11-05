# build_assets.py — XOR-encrypts mock_rat.exe into assets.dat

KEY = bytes([0x5A, 0x5B, 0x5C, 0x5D])

with open("mock_rat.exe", "rb") as f:
    data = f.read()

out = bytearray(len(data))
for i, b in enumerate(data):
    out[i] = b ^ KEY[i % len(KEY)]

with open("assets.dat", "wb") as f:
    f.write(out)

print(f"wrote assets.dat ({len(out)} bytes)")
