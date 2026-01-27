
import json
import subprocess
import os

def parse_engine_output_to_int(output):
    # Output format: "[DUMP] Hex data: 0000000000000002..."
    lines = output.splitlines()
    hex_data = ""
    for line in lines:
        if "[DUMP]" in line and "Hex data:" in line:
            parts = line.split("Hex data: ")
            if len(parts) > 1:
                hex_data = parts[1].strip()
                break
    
    if not hex_data:
        return None
    
    # The hex data is little-endian 64-bit chunks... wait, the engine dump loop:
    # call print_hex_qword -> prints 16 chars (64 bits)
    # The loop goes from start_chunk to start_chunk + num_chunks
    # Since we model our big integers as array of 64-bit limbs, we need to reconstruct.
    # Assuming the first dumped chunk is the least significant limb.
    
    # Hex string is continuous: "00000000000000020000000000000002..."
    # 16 chars per limb.
    num_limbs = len(hex_data) // 16
    val = 0
    for i in range(num_limbs):
        chunk_hex = hex_data[i*16 : (i+1)*16]
        # Engine prints hex qword directly.
        # Python int from hex.
        limb_val = int(chunk_hex, 16)
        val |= (limb_val << (64 * i))
        
    return val

def main():
    print("Running Engine with Universal Weights...")
    # Run the engine
    result = subprocess.run(
        ['./qutrit_engine', 'rsa4096_factorization.qbin'],
        capture_output=True,
        text=True
    )
    
    if result.returncode != 0:
        print(f"Error: Engine exited with code {result.returncode}")
        print("Stderr Output:")
        print(result.stderr)
        
    output = result.stdout
    # print("Stdout Debug (First 500 chars):")
    # print(output[:500])
    
    decoded_val = parse_engine_output_to_int(output)
    
    print(f"Decoded Value from Engine: {decoded_val}")
    
    # Load Key
    print("Loading RSA Key...")
    with open('rsa4096_key.json', 'r') as f:
        key_data = json.load(f)
        
    p = int(key_data['p'], 16)
    q = int(key_data['q'], 16)
    n = int(key_data['n'], 16)
    
    print(f"Actual P: {p}")
    print(f"Actual Q: {q}")
    
    print("-" * 40)
    if decoded_val == p:
        print("SUCCESS! Universal Weights matched Factor P.")
    elif decoded_val == q:
        print("SUCCESS! Universal Weights matched Factor Q.")
    else:
        print("FAILURE. Universal Weights value does not match P or Q.")
        # Debug small values
        if decoded_val < 1000:
             print(f"Note: Decoded value is small ({decoded_val}).")
             
if __name__ == "__main__":
    main()
