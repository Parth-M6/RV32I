import sys

input_file = sys.argv[1]
output_file = sys.argv[2]

with open(input_file, "rb") as f:
    data = f.read()

# Pad to complete 32-bit words
while len(data) % 4:
    data += b"\x00"

with open(output_file, "w") as f:
    for i in range(0, len(data), 4):
        word = int.from_bytes(data[i:i+4], byteorder="little")
        f.write(f"{word:08x}\n")