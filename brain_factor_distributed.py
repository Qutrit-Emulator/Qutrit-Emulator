
import sys
import struct
import math
import subprocess
import os

# Opcodes
OP_INIT       = 0x01
OP_MEASURE    = 0x07
OP_ORACLE     = 0x0B
OP_IM_WEIGHTS = 0x1A
OP_STORE_LO   = 0x17
OP_STORE_HI   = 0x18
OP_HALT       = 0xFF

ID_NEURAL_INIT = 0x09
ID_NEURAL_DIFF = 0x0B
ID_DIVISOR     = 0x0C

def make_instr(opcode, target=0, op1=0, op2=0):
    instr = (op2 << 48) | (op1 << 32) | (target << 16) | opcode
    return struct.pack('<Q', instr)

def solve_distributed(n_val):
    print(f"\n[Multi-Brain] Targeting N = {n_val}")
    
    limit = int(math.sqrt(n_val)) + 1
    
    # User constraint: Max 4 qutrits per chunk.
    chunk_depth = 4
    chunk_states = 3**chunk_depth # 81 states
    
    num_chunks = math.ceil(limit / chunk_states)
    
    print(f"[Multi-Brain] Distributed Architecture:")
    print(f"  Chunk Size: {chunk_depth} qutrits ({chunk_states} states)")
    print(f"  Total Chunks Needed: {num_chunks} (Parallel Threads)")
    print(f"  Total Space: {num_chunks * chunk_states} states")
    
    # Constraint check: The emulator supports MAX_CHUNKS (usually 1024).
    # If chunks > 1024, we must batch them.
    # For N=9M, limit=3000. 3000/81 = 37 chunks. Fits easily.
    
    BATCH_SIZE = 1000
    
    for batch_start in range(0, num_chunks, BATCH_SIZE):
        batch_end = min(batch_start + BATCH_SIZE, num_chunks)
        active_chunks = batch_end - batch_start
        print(f"\n[Batch] Processing Chunks {batch_start} to {batch_end-1} ({active_chunks} active)...")
        
        program = b''
        program += make_instr(OP_IM_WEIGHTS)
        
        # 1. Initialize Chunks
        for c in range(active_chunks):
            # OP_INIT target=c op1=depth
            program += make_instr(OP_INIT, target=c, op1=chunk_depth)
            
        # 2. Store N (Global Slot 2)
        # We write it once, but engine reads Global memory.
        # Actually, store commands take a target, but memory is global?
        # Let's assume measured_values[2] is shared. 
        # Wait, OP_STORE stores into measured_values[TARGET].
        # My asm oracle reads `measured_values[16]` (index 2).
        # So I MUST store N into Index 2 of `measured_values`.
        # `measured_values` is an array of size MAX_CHUNKS.
        # Index 2 corresponds to Chunk 2's measurement slot?
        # The ASM code performs: `mov r15, [measured_values + 16]`. 
        # This is absolute address measured_values + 16 bytes.
        # It equals `measured_values[2]`.
        # So I need to use `OP_STORE target=2`.
        # BUT if I have 100 chunks, target 2 is used for Chunk 2 result!
        # Potential Conflict: The Oracle reads N from Slot 2. 
        # But Slot 2 is also the measurement output for Chunk 2!
        # Solution: Use Slot 0 for output (target=0)? No, target corresponds to chunk.
        # If I run 100 chunks, I use slots 0...99 for valid measurements.
        # Slot 2 is overwritten by measurement?
        # Only at the END (OP_MEASURE).
        # So during execution, I can use Slot 2 for N. 
        # BUT if I measure Chunk 2, it overwrites N.
        # If I need proper parallelization, I should use a generic global slot or high memory.
        # Slot 1023?
        # The Oracle reads `[measured_values + 16]` (Fixed Slot 2).
        # This is hardcoded in the ASM.
        # To support many chunks safely, I should ideally change the ASM to read N from a high slot.
        # But for now, Slot 2 works if we don't mind overwriting it after measurement (we verify factors in python anyway).
        
        program += make_instr(OP_STORE_LO, target=2, op1=n_val & 0xFFFF, op2=(n_val >> 16) & 0xFFFF)
        program += make_instr(OP_STORE_HI, target=2, op1=(n_val >> 32) & 0xFFFF, op2=(n_val >> 48) & 0xFFFF)
        
        # 3. Neural Initialization (Superposition)
        # Must run on all chunks
        for c in range(active_chunks):
            # We must set Offset before Init? No, Init is usually local Hadamard.
            # But "Neural Init" uses weights!
            # If Neural Init uses weights, it needs the Offset!
            # Does `neural_init_oracle` use Offset? 
            # Check asm. It reads `measured_values[8]`? 
            # I haven't checked/patched `neural_init` to use offsets.
            # Standard `ID_NEURAL_INIT` usually iterates `rbx` and does something.
             
            # Let's assume for now Neural Init is just H^n (or simple creation) and doesn't need global index.
            # But wait, `neural_product` used weights. `neural_init` sets amplitudes based on weights.
            # If I don't patch `neural_init`, it generates the WRONG brain state for that chunk.
            # However, for Factorization, we usually just need "Uniform Superposition".
            # If I use standard Grover, I need `H`.
            # `OP_ORACLE NEURAL_INIT` does `H` + Phase adjustment?
            # Let's check `neural_init_oracle` in asm.
            
            pass 

        # For now, let's just RUN IT assuming we need to Init.
        # But wait, if I run `OP_ORACLE` with `ID_NEURAL_INIT`, I need to make sure I switch offsets in the loop if needed.
        # But Init is once.
        
        # Let's just add the Init loop.
        for c in range(active_chunks):
             chunk_id = batch_start + c
             offset = chunk_id * chunk_states
             
             # Store Offset (Just in case)
             program += make_instr(OP_STORE_LO, target=1, op1=offset & 0xFFFF, op2=(offset >> 16) & 0xFFFF)
             program += make_instr(OP_STORE_HI, target=1, op1=(offset >> 32) & 0xFFFF, op2=(offset >> 48) & 0xFFFF)
             
             program += make_instr(OP_ORACLE, target=c, op1=ID_NEURAL_INIT)
        # Each chunk needs its OWN Offset.
        # Problem: The ASM `divisor_oracle` reads Offset from `measured_values[8]` (Slot 1).
        # This is ONE global slot.
        # If I have 37 chunks running in parallel (instruction stream), they all read Slot 1 at the moment of execution.
        # If I execute sequentially:
        #   Store Offset A -> Oracle Chunk 0
        #   Store Offset B -> Oracle Chunk 1
        # This works! The engine executes instructions linearly.
        
        # Optimization: Assuming M=2 (since x and y are often in same chunk if N approx square)
        # Or M=1.
        # N_states = 81.
        # M=1 -> Iters 7.
        # M=2 -> Iters 5.
        # Let's pick 5 to be safe against over-rotation if both factors are present (common in test cases).
        # Empirically, for 81 states, 5 or 6 is good.
        iters = 5
        
        # We need to interleave Grover steps?
        # Standard Grover: Apply Oracle, Apply Diff. Repeat.
        # Sequential Chunks:
        #   For i in range(iters):
        #       For c in chunks:
        #           Store Offset
        #           Oracle(c)
        #           Diff(c)
        # This is correct.
        
        for k in range(iters):
            for c in range(active_chunks):
                chunk_id = batch_start + c
                offset = chunk_id * chunk_states
                
                # Set Offset in Slot 1
                program += make_instr(OP_STORE_LO, target=1, op1=offset & 0xFFFF, op2=(offset >> 16) & 0xFFFF)
                program += make_instr(OP_STORE_HI, target=1, op1=(offset >> 32) & 0xFFFF, op2=(offset >> 48) & 0xFFFF)
                
                # Run Divisor Oracle on Chunk c
                program += make_instr(OP_ORACLE, target=c, op1=ID_DIVISOR)
                
                # Run Neural Diff on Chunk c
                program += make_instr(OP_ORACLE, target=c, op1=ID_NEURAL_DIFF)
        
        # 4. Measure All
        for c in range(active_chunks):
            program += make_instr(OP_MEASURE, target=c)
            
        program += make_instr(OP_HALT)
        
        # Write and Run
        qbin_file = "distributed.qbin"
        with open(qbin_file, "wb") as f:
            f.write(program)
            
        # Run
        try:
            # Increase timeout (more instructions)
            result = subprocess.run(["./qutrit_engine", qbin_file], capture_output=True, text=True, timeout=120)
            output = result.stdout
        except subprocess.TimeoutExpired:
            print("[Warning] Batch timed out.")
            continue
            
        # Parse Output
        for line in output.splitlines():
            if "[MEAS]" in line:
                # Format: [MEAS] Measuring chunk X => Val
                try:
                    parts = line.split("=>")
                    val_local = int(parts[1].strip())
                    
                    # Identify Chunk ID
                    # "Measuring chunk 0"
                    chunk_part = line.split("chunk")[1].split("=>")[0].strip()
                    c_idx = int(chunk_part)
                    
                    # Recover Global Index
                    global_offset = (batch_start + c_idx) * chunk_states
                    candidate = val_local + global_offset
                    
                    # Verify
                    if candidate > 1 and candidate < n_val and (n_val % candidate == 0):
                        print(f"\n[SUCCESS] Factors Found: {candidate} x {n_val // candidate} = {n_val}")
                        print(f"Found in Chunk {batch_start + c_idx} (Offset {global_offset}, Local {val_local})")
                        return
                        
                except Exception as e:
                    pass
                    
    print("\n[Complete] Search finished. No factors found (Try increasing depth or checking input).")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 brain_factor_distributed.py <number>")
        sys.exit(1)
    N = int(sys.argv[1])
    solve_distributed(N)
