from cryptography.hazmat.primitives.asymmetric import rsa
import json

print("Generating 4096-bit RSA key (this may take a moment)...")
private_key = rsa.generate_private_key(
    public_exponent=65537,
    key_size=4096
)

p = private_key.private_numbers().p
q = private_key.private_numbers().q
n = private_key.public_key().public_numbers().n

data = {
    "p": hex(p),
    "q": hex(q),
    "n": hex(n)
}

with open("rsa4096_key.json", "w") as f:
    json.dump(data, f, indent=4)

print("RSA-4096 Key generated and saved to rsa4096_key.json")
print(f"Modulus N (first 32 chars): {hex(n)[:32]}...")
