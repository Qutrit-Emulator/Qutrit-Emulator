import struct
import math
import subprocess
import time
from collections import Counter

def solve_equation_xy():
    """
    Uses the Qutrit Engine to solve the Diophantine Equation:
    
        x^2 + y^2 = 2
        
    Variables x, y are qutrits with values in {-1, 0, 1}.
    
    Analysis:
      x, y in {-1, 0, 1} => x^2, y^2 in {0, 1}.
      For sum to be 2, we must have x^2=1 AND y^2=1.
      This corresponds to x, y being Non-Zero (+1 or -1).
      
    Solution Set (4 Solutions):
      (1, 1), (1, -1), (-1, 1), (-1, -1)
      
    Quantum Algorithm:
      1. Initialize 2 Qutrits (9 states).
      2. Apply Superposition (all states equal probability).
      3. Grover Amplification:
         - Oracle: Heisenberg Interaction (0x80) applied for PI phase.
           * H = Theta * Sz_A * Sz_B
           * If x, y are non-zero, |x*y| = 1.
           * Phase = exp(i * PI * x*y) = -1.
           * If x or y is zero, x*y = 0.
           * Phase = exp(0) = 1.
           * Thus, Oracle marks exactly the states where x,y != 0.
         - Diffusion: Amplifies marked states.
      4. Measure.
    """
    filename = "equation_solve.qbin"
    target_matches = 0
    total_runs = 50
    results = []
    
    # Generate Circuit (Once)
    OP_INIT     = 0x01
    OP_SUP      = 0x02
    OP_GROVER   = 0x08
    OP_MEASURE  = 0x07
    OP_HALT     = 0xFF
    HEISENBERG  = 0x80
    
    instructions = []
    # 1. Init Chunk 0, 2 Qutrits
    instructions.append((OP_INIT << 24) | (0 << 16) | (2 << 8))
    # 2. Superposition
    instructions.append((OP_SUP << 24) | (0 << 16))
    
    # 3. Grover Loop
    # Oracle: 6 pulses of Heisenberg for PI phase (approx)
    for _ in range(6):
        instructions.append((HEISENBERG << 24) | (0 << 16))
    
    # Diffusion
    instructions.append((OP_GROVER << 24) | (0 << 16))
    
    # 4. Measure
    instructions.append((OP_MEASURE << 24) | (0 << 16))
    
    # 5. Halt
    instructions.append(OP_HALT << 24)
    
    with open(filename, "wb") as f:
        for instr in instructions:
            f.write(struct.pack('>I', instr))
            
    print(f"Solving Equation: x^2 + y^2 = 2")
    print(f"Combinatorial Search Space: 3^2 = 9 states.")
    print(f"Executing {total_runs} quantum shots to verify solution methods...")
    print("-" * 60)
    
    valid_solutions = 0
    observed_counts = Counter()
    
    for i in range(total_runs):
        try:
            res = subprocess.run(["./qutrit_engine", filename], capture_output=True, text=True)
            for line in res.stdout.splitlines():
                if "->" in line:
                    val = int(line.split("->")[1].strip())
                    
                    # Decode
                    q0 = val % 3
                    q1 = (val // 3) % 3
                    x = q0 - 1
                    y = q1 - 1
                    
                    # Verify Equation
                    lhs = x**2 + y**2
                    is_solution = (lhs == 2)
                    
                    observed_counts[(x,y)] += 1
                    if is_solution:
                        valid_solutions += 1
                        
        except Exception as e:
            print(e)
            
    # Report
    print(f"\nResults over {total_runs} shots:")
    print(f"{'State (x, y)':<15} | {'Eq Check (x^2+y^2)':<20} | {'Count':<10} | {'Status'}")
    print("-" * 60)
    
    sorted_states = sorted(observed_counts.keys(), key=lambda k: -observed_counts[k])
    for (x, y) in sorted_states:
        count = observed_counts[(x,y)]
        lhs = x**2 + y**2
        status = "SOLVED" if lhs == 2 else "fail"
        print(f"({x:>2}, {y:>2})     | {lhs:<20} | {count:<10} | {status}")
        
    print("-" * 60)
    accuracy = (valid_solutions / total_runs) * 100
    print(f"Solver Accuracy: {accuracy:.1f}%")
    
    if accuracy > 90:
        print(">> SUCCESS: Equation solved reliably.")
    else:
        print(">> WARNING: Low accuracy. Adjust oracle phases?")

if __name__ == "__main__":
    solve_equation_xy()
