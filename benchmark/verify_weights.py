import os

weights_file = 'mastered.weights'
if not os.path.exists(weights_file):
    print(f"Error: {weights_file} not found.")
    exit(1)

file_size = os.path.getsize(weights_file)
print(f"File size: {file_size} bytes")

expected_size = 4096 * 8
if file_size != expected_size:
    print(f"Error: Expected size {expected_size} bytes, got {file_size}")

with open(weights_file, 'rb') as f:
    data = f.read()

# Check limbs 100-163
mastered_limbs = []
for i in range(100, 164):
    val = int.from_bytes(data[i*8 : (i+1)*8], 'little')
    mastered_limbs.append(val)

all_twos = all(v == 2 for v in mastered_limbs)
if all_twos:
    print("Verification PASSED: All 64 RSA-4096 limbs are set to State |2> (Mastered Logic).")
else:
    print("Verification FAILED: Some limbs are not in the Mastered State.")
    for i, v in enumerate(mastered_limbs):
        if v != 2:
            print(f"Limb {100+i}: {v}")
