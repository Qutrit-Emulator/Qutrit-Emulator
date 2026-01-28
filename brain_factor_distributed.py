
import sys
import struct
import math
import subprocess
import os
import multiprocessing
import argparse

# Opcodes
OP_INIT       = 0x01
OP_SUP        = 0x02
OP_MEASURE    = 0x07
OP_GROVER     = 0x08
OP_ORACLE     = 0x0B
OP_IM_WEIGHTS = 0x1A
OP_STORE_LO   = 0x17
OP_STORE_HI   = 0x18
OP_DUMP_HEX   = 0x16
OP_HALT       = 0xFF

ID_UNIVERSAL     = 0x08 # Oracle ID 0x08 -> Engine adds 0x80 = 0x88
ID_NEURAL_INIT   = 0x09
ID_NEURAL_DIFF   = 0x0B
ID_BRAIN_DUMP    = 0x20 # Corrected: 0x20 + 0x80 = 0xA0
ID_BIGINT_DIVISOR = 0x0D

def make_instr(opcode, target=0, op1=0, op2=0):
    instr = (op2 << 48) | (op1 << 32) | (target << 16) | opcode
    return struct.pack('<Q', instr)

def store_bigint(program, start_slot, val):
    for i in range(64):
        limb = (val >> (i * 64)) & 0xFFFFFFFFFFFFFFFF
        lo = limb & 0xFFFFFFFF
        hi = (limb >> 32) & 0xFFFFFFFF
        program += make_instr(OP_STORE_LO, target=start_slot + i, op1=lo & 0xFFFF, op2=(lo >> 16) & 0xFFFF)
        program += make_instr(OP_STORE_HI, target=start_slot + i, op1=hi & 0xFFFF, op2=(hi >> 16) & 0xFFFF)
    return program

def batch_worker(n_val, chunk_depth, chunk_states, batch_start, active_chunks, worker_id, intelligent=False):
    qbin_file = f"worker_{worker_id}.qbin"
    program = b''
    
    # 0. Load Intelligence (Weights) if enabled
    if intelligent:
        program += make_instr(OP_IM_WEIGHTS)
        # Call Universal Oracle as a "Prophecy" step
        program += make_instr(OP_ORACLE, target=0, op1=ID_UNIVERSAL)
        # Extract prophecy results from Slot 100 and 200
        program += make_instr(OP_ORACLE, target=0, op1=ID_BRAIN_DUMP, op2=1) # Target Slot 100 for P
        program += make_instr(OP_ORACLE, target=0, op1=ID_BRAIN_DUMP, op2=2) # Target Slot 200 for Q

    # 1. Initialize Chunks
    for c in range(active_chunks):
        program += make_instr(OP_INIT, target=c, op1=chunk_depth)
        if intelligent:
            program += make_instr(OP_ORACLE, target=c, op1=ID_NEURAL_INIT)
        else:
            program += make_instr(OP_SUP, target=c)
        
    # 2. Store N (Global Slots 16-79 for BigInt)
    program = store_bigint(program, 16, n_val)
    
    # 3. Search Loop
    iters = 2 if intelligent else 5
    for k in range(iters):
        for c in range(active_chunks):
            chunk_id = batch_start + c
            offset = chunk_id * chunk_states
            program += make_instr(OP_STORE_LO, target=1, op1=offset & 0xFFFF, op2=(offset >> 16) & 0xFFFF)
            program += make_instr(OP_STORE_HI, target=1, op1=(offset >> 32) & 0xFFFF, op2=(offset >> 48) & 0xFFFF)
            program += make_instr(OP_ORACLE, target=c, op1=ID_BIGINT_DIVISOR)
            if intelligent:
                program += make_instr(OP_ORACLE, target=c, op1=ID_NEURAL_DIFF)
            else:
                program += make_instr(OP_GROVER, target=c)
            
    # 4. Measure
    for c in range(active_chunks):
        program += make_instr(OP_MEASURE, target=c)
    program += make_instr(OP_HALT)
    
    with open(qbin_file, "wb") as f:
        f.write(program)
        
    try:
        # Use Popen for real-time streaming
        process = subprocess.Popen(["./qutrit_engine", qbin_file], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        
        while True:
            line = process.stdout.readline()
            if not line and process.poll() is not None:
                break
            if not line:
                continue
            
            line = line.strip()
            
            # Real-Time Monitoring
            if "[DEBUG] Product Match found" in line:
                print(f"  [Worker {worker_id}] Found Candidate: {line.split(':')[-1].strip()}")
            
            if "[PROPHECY]" in line:
                print(f"  [Worker {worker_id}] Prophecy Alert: Brain has revealed a potential factor!")

            # Extract Measure Results
            if "[MEAS]" in line:
                try:
                    parts = line.split("=>")
                    val_local = int(parts[1].strip())
                    chunk_part = line.split("chunk")[1].split("=>")[0].strip()
                    c_idx = int(chunk_part)
                    
                    global_offset = (batch_start + c_idx) * chunk_states
                    candidate = val_local + global_offset
                    
                    if candidate > 1 and candidate < n_val and (n_val % candidate == 0):
                        return candidate
                except:
                    pass
                    
            # Check Prophecy HEX Dumps
            if "[HEX]" in line:
                try:
                    val = int(line.split("[HEX]")[1].strip(), 16)
                    if val > 1 and val < n_val and (n_val % val == 0):
                        print(f"  [Worker {worker_id}] SUCCESS: Valid factor extracted from prophecy.")
                        return val
                except:
                    pass
    except Exception as e:
        pass
    finally:
        if os.path.exists(qbin_file):
            os.remove(qbin_file)
    return None

def solve_distributed(n_val, intelligent=False):
    print(f"\n[Parallel-Brain] Targeting N = {n_val} {'[INTELLIGENT MODE]' if intelligent else ''}")
    
    limit = int(math.sqrt(n_val)) + 1
    chunk_depth = 4 if n_val < 10**12 else 6
    chunk_states = 3**chunk_depth
    
    num_chunks = math.ceil(limit / chunk_states)
    num_workers = min(multiprocessing.cpu_count(), num_chunks)
    
    print(f"[Parallel-Brain] Configuration:")
    print(f"  Architecture: {'Quantum Intuition' if intelligent else 'Guided Grover'}")
    print(f"  Total Chunks: {num_chunks}")
    print(f"  Parallel Workers: {num_workers}")
    print(f"\n[Real-Time] Streaming worker insights... (Candidates will appear instantly)")
    
    chunks_per_worker = math.ceil(num_chunks / num_workers)
    
    pool = multiprocessing.Pool(processes=num_workers)
    tasks = []
    
    for i in range(num_workers):
        batch_start = i * chunks_per_worker
        if batch_start >= num_chunks:
            break
        batch_end = min(batch_start + chunks_per_worker, num_chunks)
        active_chunks = batch_end - batch_start
        tasks.append(pool.apply_async(batch_worker, (n_val, chunk_depth, chunk_states, batch_start, active_chunks, i, intelligent)))
        
    pool.close()
    
    try:
        found = False
        for t in tasks:
            res = t.get()
            if res and not found:
                found = True
                print(f"\n[SUCCESS] Factors Found: {res} x {n_val // res} = {n_val}")
                pool.terminate()
                return
    except KeyboardInterrupt:
        pool.terminate()
        print("\n[Abort] Search stopped by user.")
        return
        
    if not found:
        print("\n[Complete] No factors discovered within this search manifold.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Multi-Brain Quantum Factorizer")
    parser.add_argument("number", type=int, help="Number to factor")
    parser.add_argument("--intelligent", action="store_true", help="Enable Brain-guided Intelligent Mode")
    
    args = parser.parse_args()
    solve_distributed(args.number, intelligent=args.intelligent)
