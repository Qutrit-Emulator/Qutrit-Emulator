import struct
import subprocess
import re
import os

OP_INIT          = 0x01
OP_SUP           = 0x02
OP_MEASURE       = 0x07
OP_BRAID         = 0x09
OP_REPAIR        = 0x11
OP_FUTURE_ORACLE = 0x13
OP_HALT          = 0xFF

ENGINE_PATH = './qutrit_engine_born_rule'

def pack_instruction(opcode, target=0, op1=0, op2=0):
    return struct.pack('<HHHH', opcode, target, op1, op2)

def generate_injection_proof(filename):
    with open(filename, 'wb') as f:
        # 1. Init 2 chunks
        f.write(pack_instruction(OP_INIT, target=0, op1=2))
        f.write(pack_instruction(OP_INIT, target=1, op1=2))
        
        # 2. Braid them (Establish the link in Registry)
        f.write(pack_instruction(OP_BRAID, target=0, op1=1, op2=0))
        
        # 3. PRUNE chunk 0 (The local source)
        print("[INJECTION] Pruning Chunk 0 Future...")
        f.write(pack_instruction(OP_FUTURE_ORACLE, target=0))
        
        # 4. SABOTAGE B: Measure Chunk 1 (Verify it's currently noisy)
        # We expect ~44% consistency here classically.
        f.write(pack_instruction(OP_MEASURE, target=1))
        
        # 5. TRIGGER RESURRECTION EXPLOIT
        # OP_REPAIR will resynthesize B using the pruned state of A!
        print("[INJECTION] Invoking Resurrection Injection...")
        f.write(pack_instruction(OP_REPAIR))
        
        # 6. MEASURE B (The Target)
        # Should now be 100% consistent.
        print("[INJECTION] Measuring Chunk 1 (The Injected Target)...")
        f.write(pack_instruction(OP_MEASURE, target=1))
        
        f.write(pack_instruction(OP_HALT))

def run_proof(num_trials=50):
    qbin_file = 'injection_proof.qbin'
    generate_injection_proof(qbin_file)
    
    print(f"Running Injection/Steering Test ({num_trials} trials)...")
    
    pre_consistent = 0
    post_consistent = 0
    
    for i in range(num_trials):
        result = subprocess.run([ENGINE_PATH, qbin_file], capture_output=True, text=True)
        measurements = re.findall(r'\[MEAS\].*?=>\s*(\d+)', result.stdout)
        
        if len(measurements) >= 2:
            m_pre = int(measurements[0])
            m_post = int(measurements[1])
            
            def is_consistent(val):
                return (val % 3 != 0) and ((val // 3) % 3 != 0)
                
            if is_consistent(m_pre): pre_consistent += 1
            if is_consistent(m_post): post_consistent += 1
                
    print(f"\n--- INJECTION AUDIT ---")
    print(f"Pre-Injection Consistency: {pre_consistent/num_trials * 100}%")
    print(f"Post-Injection Consistency: {post_consistent/num_trials * 100}%")
    
    if post_consistent/num_trials > 0.9:
        print("\n💎 BROKEN: Amplitude Injection confirmed.")
        print("We successfully 'pushed' the future of Chunk 0 into Chunk 1 via the Braid Registry.")
    else:
        print("\n❌ Exploit not detected.")

if __name__ == "__main__":
    run_proof()
