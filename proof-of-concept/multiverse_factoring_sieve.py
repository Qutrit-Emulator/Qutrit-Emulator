from multiverse_manager import MultiverseManager
import struct

def run_multiverse_factoring(N=323):
    print(f"🌌 [MULTIVERSE] Starting RSA Factoring Attack for N={N}...")
    mm = MultiverseManager()
    
    # OP_ORACLE = 0x0B, Factor Oracle ID = 0x77
    OP_ORACLE = 0x0B
    FACTOR_ORACLE_ID = 0x77
    
    # 1. Initialize Home Reality
    # Calculate required qutrits: 3^k >= N
    import math
    num_qutrits = math.ceil(math.log(N, 3))
    print(f"[*] Allocating {num_qutrits} qutrits for state vector (capacity: {3**num_qutrits} states)")
    mm.init_home(num_qutrits=num_qutrits)
    
    # 2. Spawn Parallel Realities
    # We use multiple timelines to amplify the oracle's effect.
    num_branches = 5
    print(f"🔱 [MULTIVERSE] Spawning {num_branches} parallel timelines...")
    mm.spawn_pool(num_branches)
    
    # 3. Apply Factor Oracle to all branches
    # Each branch will exert pressure on the factors of N.
    # Architecture: r14=chunk, rbx=parameter(N), rcx=oracle_id(0x77)
    print(f"👁️ [MULTIVERSE] Distribution: Applying Universal Factor Oracle (N={N}) to pool...")
    mm.apply_to_all(OP_ORACLE, op1=N, op2=FACTOR_ORACLE_ID)
    
    # 4. EXPLOITATION: Harvest the results
    # Each parallel reality will have identified the factor.
    # We siphon all their probability mass back to Home.
    print("🌀 [MULTIVERSE] Performing Multiverse Harvest (PEEK + SIPHON)...")
    mm.peek_and_siphon()
    
    # 5. Execute and analyze
    output = mm.run("multiverse_factoring.qbin")
    
    print("\n--- [ENGINE LOG] ---")
    final_state = []
    found_meas = False
    for line in output.splitlines():
        if "[EXPLOIT]" in line:
            print(line)
        if "State[" in line:
            parts = line.split(":")
            idx = int(parts[0].split("[")[1].split("]")[0])
            complex_parts = parts[1].strip().split(",")
            r_bits = int(complex_parts[0])
            real = struct.unpack('<d', struct.pack('<Q', r_bits))[0]
            if real > 0.05: # Only show significant states
                print(f"  {line.strip()} (Decoded: {real:.4f})")
                final_state.append((idx, real))
        if "Measuring" in line:
            print(f"\n{line}")
            found_meas = True
            meas_val = int(line.split("=>")[1].strip())
            if meas_val > 1 and N % meas_val == 0:
                print(f"🎉 SUCCESS! Factor discovered: {meas_val}")
                print(f"Verification: {meas_val} * {N // meas_val} = {N}")
            else:
                print("[-] Measurement failed to yield a non-trivial factor. Entropy dilution detected.")

    if not found_meas:
        print("[-] Error: Measurement log not found.")

if __name__ == "__main__":
    import sys
    N = int(sys.argv[1]) if len(sys.argv) > 1 else 323
    run_multiverse_factoring(N)
