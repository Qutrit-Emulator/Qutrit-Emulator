import subprocess
import struct
import os
import re
import time
from collections import defaultdict
from dataclasses import dataclass

# Configuration
ENGINE_PATH = "./qutrit_engine"
# Opcodes
OP_NOP          = 0x00
OP_INIT         = 0x01
OP_SUP          = 0x02
OP_HADAMARD     = 0x03
OP_PHASE        = 0x04
OP_CPHASE       = 0x05
OP_SWAP         = 0x06
OP_MEASURE      = 0x07
OP_GROVER       = 0x08
OP_BRAID        = 0x09
OP_UNBRAID      = 0x0A
OP_ORACLE       = 0x0B
OP_ADDON        = 0x0C
OP_PRINT_STATE  = 0x0D
OP_BELL_TEST    = 0x0E
OP_SUMMARY      = 0x0F
OP_SHIFT        = 0x10
OP_REPAIR       = 0x11
OP_CHUNK_SWAP   = 0x12
OP_NULL         = 0x14
OP_IF           = 0x15
OP_GENESIS      = 0x16
OP_PI_GENESIS   = 0x18
OP_PERFECTION   = 0x19
OP_COHERENCE    = 0x1A
OP_NOISE        = 0x1B
OP_BRAID_SILENT = 0x1C
OP_HALT         = 0xFF

@dataclass
class TestResult:
    name: str
    passed: bool
    details: str

def pack_instr(opcode, target=0, op1=0, op2=0):
    """
    Pack instruction into 64-bit integer.
    Format: [Op2:8][Op1:24][Target:24][Opcode:8]
    Wait, checking ASM shifts:
    Opcode: 0-7 (8 bits)
    Target: 8-31 (24 bits)
    Op1: 32-55 (24 bits)
    Op2: 56-63 (8 bits)
    """
    instr = (opcode & 0xFF) | \
            ((target & 0xFFFFFF) << 8) | \
            ((op1 & 0xFFFFFF) << 32) | \
            ((op2 & 0xFF) << 56)
    return struct.pack('<Q', instr)

def run_qbin(filename):
    result = subprocess.run(
        [ENGINE_PATH, filename],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    return result.stdout.decode('utf-8', errors='ignore')

def test_superposition():
    print("Testing Superposition...")
    # Run 300 measurements on Chunk 0
    prog = b""
    trials = 300
    for i in range(trials):
        prog += pack_instr(OP_INIT, target=0, op1=1)  # INIT Chunk 0, Size 1
        prog += pack_instr(OP_SUP, target=0)          # SUP Chunk 0
        prog += pack_instr(OP_MEASURE, target=0)      # MEASURE Chunk 0
    prog += pack_instr(OP_HALT)
    
    with open("test_sup.qbin", "wb") as f:
        f.write(prog)
        
    output = run_qbin("test_sup.qbin")
    
    # Parse
    counts = defaultdict(int)
    matches = re.findall(r"Measuring chunk 0 => (\d+)", output)
    
    if not matches:
        return TestResult("Superposition", False, "No output")
        
    for m in matches:
        counts[int(m)] += 1
        
    total = len(matches)
    probs = {k: v/total for k,v in counts.items()}
    print(f"  Distribution (N={total}): {probs}")
    
    # Check
    expected = 1/3
    passed = True
    details = []
    for k in [0, 1, 2]:
        p = probs.get(k, 0.0)
        if abs(p - expected) > 0.1: # 10% tolerance is fair for random variation on small N
            passed = False
            details.append(f"|{k}>:{p:.2f}")
            
    if passed:
        return TestResult("Superposition", True, f"Uniform (33%+/-10%) verified. N={total}")
    return TestResult("Superposition", False, f"Deviation: {details}")

def test_interference():
    print("Testing Destructive Interference...")
    # H^2 |0> -> |0>
    prog = b""
    prog += pack_instr(OP_INIT, target=1, op1=1)
    prog += pack_instr(OP_HADAMARD, target=1, op1=0) # H on qutrit 0
    prog += pack_instr(OP_HADAMARD, target=1, op1=0) # H on qutrit 0
    prog += pack_instr(OP_MEASURE, target=1)
    prog += pack_instr(OP_HALT)
    
    with open("test_int.qbin", "wb") as f:
        f.write(prog)
    
    output = run_qbin("test_int.qbin")
    match = re.search(r"Measuring chunk 1 => (\d+)", output)
    if match:
        val = int(match.group(1))
        if val == 0:
            return TestResult("Destructive Interference", True, "Collapsed to |0>")
        return TestResult("Destructive Interference", False, f"Result |{val}>")
    return TestResult("Destructive Interference", False, "No result")

def test_entanglement():
    print("Testing Entanglement...")
    prog = b""
    prog += pack_instr(OP_INIT, target=2, op1=1)
    prog += pack_instr(OP_INIT, target=3, op1=1)
    prog += pack_instr(OP_BRAID, target=2, op1=3) # Braiding might imply entanglement
    # But usually Bell Test sets it up.
    prog += pack_instr(OP_BELL_TEST, target=2, op1=3)
    prog += pack_instr(OP_HALT)
    
    with open("test_bell.qbin", "wb") as f:
        f.write(prog)
        
    output = run_qbin("test_bell.qbin")
    if "BELL TEST PASSED" in output:
        return TestResult("Entanglement", True, "100% Correlation verified")
    if "BELL TEST FAILED" in output:
        return TestResult("Entanglement", False, "Bell test failed")
    return TestResult("Entanglement", False, "Output parse error")

def test_teleportation():
    print("Testing Teleportation (Logic Routing)...")
    # Measure Chunk 4 (Superposition). If 0->Init 5. If 1->Init 6.
    prog = b""
    prog += pack_instr(OP_INIT, target=4, op1=1)
    prog += pack_instr(OP_SUP, target=4)
    prog += pack_instr(OP_MEASURE, target=4)
    
    # IF Chunk 4 == 0 THEN Init Chunk 5
    prog += pack_instr(OP_IF, target=0, op1=4, op2=0) # Target ignored? No, code uses Op1 for chunk.
    prog += pack_instr(OP_INIT, target=5, op1=1)
    
    # IF Chunk 4 == 1 THEN Init Chunk 6
    prog += pack_instr(OP_IF, target=0, op1=4, op2=1)
    prog += pack_instr(OP_INIT, target=6, op1=1)
    
    # IF Chunk 4 == 2 THEN Init Chunk 7
    prog += pack_instr(OP_IF, target=0, op1=4, op2=2)
    prog += pack_instr(OP_INIT, target=7, op1=1)
    
    prog += pack_instr(OP_SUMMARY, target=100) # Print active chunks
    prog += pack_instr(OP_HALT)
    
    with open("test_tele.qbin", "wb") as f:
        f.write(prog)
        
    output = run_qbin("test_tele.qbin")
    # Find measurement
    m = re.search(r"Measuring chunk 4 => (\d+)", output)
    if not m: return TestResult("Teleportation", False, "No measurement")
    
    val = int(m.group(1))
    target = 5 + val
    
    if f"[INIT] Chunk {target}" in output:
        return TestResult("Teleportation", True, f"Routed to Chunk {target} based on |{val}>")
    else:
        # Check if wrong one init?
        return TestResult("Teleportation", False, f"Routing failed for |{val}>")

def test_retrocausality():
    print("Testing Retrocausality...")
    # Chunk 8 (|1>), Chunk 9 (|2>). Swap. Measure.
    prog = b""
    # Init 8 -> |1>
    prog += pack_instr(OP_INIT, target=8, op1=1)
    prog += pack_instr(OP_SHIFT, target=8) # 0->1
    
    # Init 9 -> |2>
    prog += pack_instr(OP_INIT, target=9, op1=1)
    prog += pack_instr(OP_SHIFT, target=9)
    prog += pack_instr(OP_SHIFT, target=9) # 0->1->2
    
    # Swap
    prog += pack_instr(OP_CHUNK_SWAP, target=8, op1=9)
    
    # Measure
    prog += pack_instr(OP_MEASURE, target=8) # Expect 2
    prog += pack_instr(OP_MEASURE, target=9) # Expect 1
    prog += pack_instr(OP_HALT)
    
    with open("test_retro.qbin", "wb") as f:
        f.write(prog)
        
    output = run_qbin("test_retro.qbin")
    m8 = re.search(r"Measuring chunk 8 => (\d+)", output)
    m9 = re.search(r"Measuring chunk 9 => (\d+)", output)
    
    if m8 and m9:
        v8, v9 = int(m8.group(1)), int(m9.group(1))
        if v8 == 2 and v9 == 1:
            return TestResult("Retrocausality", True, "Swapped 8(|1>)->|2> and 9(|2>)->|1>")
        return TestResult("Retrocausality", False, f"Got 8:{v8}, 9:{v9}")
    return TestResult("Retrocausality", False, "Missing output")

def main():
    print("=== Qutrit Engine Benchmark Suite (Binary Mode) ===\n")
    
    tests = [
        test_superposition,
        test_interference,
        test_entanglement,
        test_teleportation,
        test_retrocausality,
        test_max_chunk_size,
        test_max_chunk_size,
        test_high_capacity,
        test_limits,
        test_stress_all,
        test_massive_entanglement,
        test_repair
    ]
    
    results = []
    for t in tests:
        try:
            results.append(t())
        except Exception as e:
            results.append(TestResult(f"{t.__name__}", False, f"Error: {e}"))
            
    print("\n" + "="*50)
    print("BENCHMARK REPORT")
    print("="*50)
    
    all_pass = True
    for r in results:
        mark = "✅" if r.passed else "❌"
        print(f"{mark} {r.name:<25} | {r.details}")
        if not r.passed: all_pass = False
        
    if all_pass:
        print("\nAll systems nominal.")
    else:
        print("\nFailures detected.")

def test_max_chunk_size():
    print("Testing Max Chunk Size (10 qutrits = 59,049 states)...")
    prog = b""
    # Init Chunk 10 with size 10
    prog += pack_instr(OP_INIT, target=10, op1=10)
    prog += pack_instr(OP_SUP, target=10)
    prog += pack_instr(OP_MEASURE, target=10)
    prog += pack_instr(OP_HALT)
    
    with open("test_max_size.qbin", "wb") as f:
        f.write(prog)
        
    output = run_qbin("test_max_size.qbin")
    m = re.search(r"Measuring chunk 10 => (\d+)", output)
    if m:
        val = int(m.group(1))
        # Valid range 0 to 3^10 - 1 (59048)
        if 0 <= val < 59049:
            return TestResult("Max Chunk Size", True, f"Successfully handled 10-qutrit state (Result: |{val}>)")
        return TestResult("Max Chunk Size", False, f"Result out of bounds: {val}")
    return TestResult("Max Chunk Size", False, "No measurement")

def test_high_capacity():
    print("Testing High Capacity Addressing (>500k chunks)...")
    prog = b""
    # Using chunks near the limit: 524,280 and 524,281
    c1 = 524280
    c2 = 524281
    
    prog += pack_instr(OP_INIT, target=c1, op1=1)
    prog += pack_instr(OP_INIT, target=c2, op1=1)
    
    # Do Bell Test at this altitude
    prog += pack_instr(OP_BELL_TEST, target=c1, op1=c2)
    prog += pack_instr(OP_HALT)
    
    with open("test_scale.qbin", "wb") as f:
        f.write(prog)
    
    output = run_qbin("test_scale.qbin")
    if "BELL TEST PASSED" in output:
        return TestResult("High Capacity", True, f"Verified entanglement at Chunks {c1} & {c2}")
    if "BELL TEST FAILED" in output:
        return TestResult("High Capacity", False, "Bell test failed at high capacity")
    return TestResult("High Capacity", False, "Output parse error or Segfault")

def test_limits():
    print("Testing Exact Limits (Boundary Condition)...")
    prog = b""
    
    limit = 524288
    last_valid = limit - 1
    first_invalid = limit
    
    # 1. Initialize Last Valid Chunk
    prog += pack_instr(OP_INIT, target=last_valid, op1=1)
    prog += pack_instr(OP_SUP, target=last_valid)
    prog += pack_instr(OP_MEASURE, target=last_valid) # Should succeed
    
    # 2. Initialize First Invalid Chunk
    prog += pack_instr(OP_INIT, target=first_invalid, op1=1) # Should fail/ignore
    prog += pack_instr(OP_MEASURE, target=first_invalid) # Should return nothing or error
    
    prog += pack_instr(OP_HALT)
    
    with open("test_limits.qbin", "wb") as f:
        f.write(prog)
        
    output = run_qbin("test_limits.qbin")
    
    # Check Last Valid
    m_valid = re.search(rf"Measuring chunk {last_valid} => (\d+)", output)
    # Check Invalid
    m_invalid = re.search(rf"Measuring chunk {first_invalid} => (\d+)", output)
    
    if m_valid and not m_invalid:
        return TestResult("Limit Boundary", True, f"Chunk {last_valid} OK, Chunk {first_invalid} Rejected (Correct).")
    elif not m_valid:
        return TestResult("Limit Boundary", False, f"Failed to access max chunk {last_valid}")
    elif m_invalid:
         return TestResult("Limit Boundary", False, f"Security Breach: Accessed out-of-bounds chunk {first_invalid}!")
    
    return TestResult("Limit Boundary", False, "Unknown state")

def test_stress_all():
    print("Testing Full Scale Stress (Every Chunk 0..524,287)...")
    limit = 524288
    batch_size = 50000 # Run in batches if needed, but let's try one massive binary first
    
    # We'll generate one massive file. 
    # 3 instructions * 8 bytes * 524288 = ~12.5 MB.
    # This is fine.
    
    print(f"  Generating {limit} operations...")
    prog = bytearray() # Mutable for speed
    
    # Pre-pack instructions for speed
    # We need to vary the target.
    # struct.pack is a bit slow for 500k calls? 
    # Let's optimize: The instruction format is [Op2][Op1][Target][Opcode] (Little Endian)
    # Opcode is byte 0. Target is bytes 1-3. Op1 is bytes 4-6. Op2 is byte 7.
    
    # OP_INIT (0x01), Size (0x01)
    # OP_SUP (0x02)
    # OP_MEASURE (0x07)
    
    # We can just build the loop.
    for i in range(limit):
        # INIT i, 1
        # Target=i, Op1=1, Op=0x01
        # i is up to 524287 (0x7FFFF) -> Fits in 24 bits (0xFFFFFF)
        
        # INIT
        prog += pack_instr(OP_INIT, target=i, op1=1)
        # SUP
        prog += pack_instr(OP_SUP, target=i)
        # MEASURE
        prog += pack_instr(OP_MEASURE, target=i)
        
    prog += pack_instr(OP_HALT)
    
    with open("test_full.qbin", "wb") as f:
        f.write(prog)
        
    print("  Executing engine (this may take a while)...")
    start = time.time()
    result = subprocess.run(
        [ENGINE_PATH, "test_full.qbin"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    duration = time.time() - start
    
    output = result.stdout.decode('utf-8', errors='ignore')
    stderr = result.stderr.decode('utf-8', errors='ignore')
    
    # Counting successful measurements
    # Searching line by line is slow for 1.5M lines.
    # Just count occurrences.
    
    measure_count = output.count("Measuring chunk")
    init_count = output.count("[INIT]")
    
    print(f"  Execution time: {duration:.2f}s")
    print(f"  Measurements: {measure_count}/{limit}")
    
    if measure_count == limit:
        return TestResult("Full Scale Stress", True, f"Successfully processed {measure_count} chunks.")
    else:
        # Check for errors in output or stderr
        err_matches = re.findall(r"Error: (.+)", output)
        if stderr:
             err_matches.append(f"Stderr: {stderr[:200]}...")
             
        error_msg = "; ".join(err_matches[:3]) if err_matches else "Truncated output or crash?"
        return TestResult("Full Scale Stress", False, f"Only processed {measure_count}/{limit}. Errors: {error_msg}")

def test_massive_entanglement():
    print("Testing Massive Entanglement Chain (The Great Chain 0..524,287)...")
    limit = 524288
    
    print(f"  Generating chain operations for {limit} chunks...")
    prog = bytearray()
    
    # 1. Initialize ALL chunks (Size 1 for speed)
    # 2. Superposition on Chunk 0
    # 3. Braid 0-1, 1-2, 2-3...
    # 4. Measure Chunk 0 (Should collapse all)
    # 5. Measure Chunk Limit-1 (Should match 0)
    
    # Batch generation to avoid memory spikes? bytearray is fine for 12MB.
    
    # INIT loop
    for i in range(limit):
        prog += pack_instr(OP_INIT, target=i, op1=1)
        
    # SUP Chunk 0
    prog += pack_instr(OP_SUP, target=0)
    
    # BRAID loop (Chain)
    # Max links = 524288. We need limit-1 links.
    for i in range(limit - 1):
        # BRAID i, i+1 (SILENT)
        prog += pack_instr(OP_BRAID_SILENT, target=i, op1=i+1)
        
    # MEASURE Chunk 0
    prog += pack_instr(OP_MEASURE, target=0)
    
    # MEASURE Last Chunk (to verify correlation propagation)
    prog += pack_instr(OP_MEASURE, target=limit-1)
    
    prog += pack_instr(OP_HALT)
    
    with open("test_chain.qbin", "wb") as f:
        f.write(prog)
        
    print("  Executing engine (Warning: High Recursion Depth)...")
    start = time.time()
    result = subprocess.run(
        [ENGINE_PATH, "test_chain.qbin"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    duration = time.time() - start
    
    output = result.stdout.decode('utf-8', errors='ignore')
    stderr = result.stderr.decode('utf-8', errors='ignore')
    
    # Check results
    # Expect: "Measuring chunk 0 => X" and "Measuring chunk 524287 => X"
    m0 = re.search(r"Measuring chunk 0 => (\d+)", output)
    mlast = re.search(rf"Measuring chunk {limit-1} => (\d+)", output)
    
    print(f"  Execution time: {duration:.2f}s")
    
    if m0 and mlast:
        v0 = int(m0.group(1))
        vlast = int(mlast.group(1))
        
        # Check explicit collapse propagation
        if v0 == vlast:
            return TestResult("Massive Chain", True, f"Long-range correlation verified! |{v0}> ... |{vlast}> (Depth {limit})")
        else:
            return TestResult("Massive Chain", False, f"Broken Chain! 0->|{v0}>, Last->|{vlast}>")
    else:
        # Check for crash
        if result.returncode != 0:
            return TestResult("Massive Chain", False, f"CRASH (Code {result.returncode}). Likely Stack Overflow on recursion. Stderr: {stderr[:200]}")
        return TestResult("Massive Chain", False, f"Missing measurements. Output len: {len(output)}")

def test_repair():
    print("Testing OP_REPAIR (Quantum Resurrection)...")
    prog = b""
    # 1. Initialize Chunk 20 (Dead) and Chunk 21 (Superposition)
    prog += pack_instr(OP_INIT, target=20, op1=1)
    prog += pack_instr(OP_INIT, target=21, op1=1)
    prog += pack_instr(OP_SUP, target=21)
    
    # 2. Braid them: This should resurrect Chunk 20 from 21
    prog += pack_instr(OP_BRAID, target=20, op1=21)
    
    # 3. Kill Chunk 20 (Zero it out)
    prog += pack_instr(OP_NULL, target=20)
    
    # 4. Run OP_REPAIR: Should resurrect 20 from 21 again
    prog += pack_instr(OP_REPAIR)
    
    # 5. Measure both. They should be correlated.
    prog += pack_instr(OP_MEASURE, target=20)
    prog += pack_instr(OP_MEASURE, target=21)
    prog += pack_instr(OP_HALT)
    
    with open("test_repair.qbin", "wb") as f:
        f.write(prog)
        
    output = run_qbin("test_repair.qbin")
    
    if "[RESURRECT]" in output:
        m20 = re.search(r"Measuring chunk 20 => (\d+)", output)
        m21 = re.search(r"Measuring chunk 21 => (\d+)", output)
        if m20 and m21:
            v20, v21 = int(m20.group(1)), int(m21.group(1))
            if v20 == v21:
                return TestResult("OP_REPAIR", True, f"Successfully resurrected and correlated! |{v20}> == |{v21}>")
            return TestResult("OP_REPAIR", False, f"Resurrected but broken correlation: {v20} != {v21}")
        return TestResult("OP_REPAIR", False, "Resurrection happened but measurements missing")
    
    return TestResult("OP_REPAIR", False, "No resurrection detected in output")

if __name__ == "__main__":
    main()
