import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
import subprocess
import os
import struct
import tempfile
import threading

# Opcodes from qutrit_engine_born_rule.asm
OP_HALT             = 0xFF
OP_LOAD_N_PART      = 0x29
OP_SHOR_INIT        = 0x20
OP_MOD_EXP          = 0x21
OP_QFT              = 0x22
OP_REALITY_COLLAPSE = 0x2A

class ShorFactoringGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("Qutrit Engine - Shor's Factoring")
        self.root.geometry("800x600")
        self.root.configure(bg='#1a1a2e')

        self.style = ttk.Style()
        self.style.theme_use('clam')
        self.style.configure("TFrame", background="#1a1a2e")
        self.style.configure("TLabel", background="#1a1a2e", foreground="#e0e0e0", font=("Inter", 11))
        self.style.configure("TButton", font=("Inter", 11, "bold"))
        self.style.configure("Header.TLabel", font=("Inter", 18, "bold"), foreground="#4cc9f0")

        self.main_frame = ttk.Frame(self.root, padding="20")
        self.main_frame.pack(fill=tk.BOTH, expand=True)

        # Header
        header = ttk.Label(self.main_frame, text="Shor's Factoring Algorithm", style="Header.TLabel")
        header.pack(pady=(0, 20))

        # Input Frame
        input_frame = ttk.Frame(self.main_frame)
        input_frame.pack(fill=tk.X, pady=10)

        ttk.Label(input_frame, text="Number to Factor (N):").grid(row=0, column=0, sticky=tk.W, padx=5, pady=5)
        self.n_entry = ttk.Entry(input_frame, width=30, font=("Consolas", 12))
        self.n_entry.insert(0, "261980999226229")
        self.n_entry.grid(row=0, column=1, sticky=tk.W, padx=5, pady=5)

        ttk.Label(input_frame, text="Number of Chunks:").grid(row=1, column=0, sticky=tk.W, padx=5, pady=5)
        self.chunks_entry = ttk.Entry(input_frame, width=10, font=("Consolas", 12))
        self.chunks_entry.insert(0, "8")
        self.chunks_entry.grid(row=1, column=1, sticky=tk.W, padx=5, pady=5)

        ttk.Label(input_frame, text="Qutrits per Chunk:").grid(row=2, column=0, sticky=tk.W, padx=5, pady=5)
        self.qutrits_entry = ttk.Entry(input_frame, width=10, font=("Consolas", 12))
        self.qutrits_entry.insert(0, "10")
        self.qutrits_entry.grid(row=2, column=1, sticky=tk.W, padx=5, pady=5)

        # Action Buttons
        btn_frame = ttk.Frame(self.main_frame)
        btn_frame.pack(fill=tk.X, pady=20)

        self.run_btn = ttk.Button(btn_frame, text="▶ FACTOR N", command=self.run_factoring)
        self.run_btn.pack(side=tk.LEFT, padx=5)

        # Log Area
        ttk.Label(self.main_frame, text="Engine Logs:").pack(anchor=tk.W, pady=(10, 5))
        self.log_area = scrolledtext.ScrolledText(
            self.main_frame, bg='#0f0f1a', fg='#00ff41', 
            font=("Consolas", 10), insertbackground='white'
        )
        self.log_area.pack(fill=tk.BOTH, expand=True)

        self.engine_path = os.path.join(os.getcwd(), "qutrit_engine_born_rule")

    def log(self, message):
        self.log_area.insert(tk.END, message + "\n")
        self.log_area.see(tk.END)

    def pack_instruction(self, opcode, target=0, op1=0, op2=0):
        # Format: [Op2:16][Op1:16][Target:16][Opcode:16] (little-endian)
        return struct.pack("<HHHH", opcode, target, op1, op2)

    def generate_qbin(self, n, num_chunks, qutrits_per_chunk):
        instructions = []
        
        # 1. Load N in 32-bit parts
        # N is up to 4096 bits in the engine, but we only need a few parts for this N
        temp_n = n
        part_idx = 0
        while temp_n > 0:
            part = temp_n & 0xFFFFFFFF
            op1 = part & 0xFFFF
            op2 = (part >> 16) & 0xFFFF
            instructions.append(self.pack_instruction(OP_LOAD_N_PART, target=part_idx, op1=op1, op2=op2))
            temp_n >>= 32
            part_idx += 1

        # 2. Initialize Shor's registers
        # Target = num_chunks, Op1 = N_lower_16 (legacy), Op2 = qutrits_per_chunk
        instructions.append(self.pack_instruction(OP_SHOR_INIT, target=num_chunks, op1=(n & 0xFFFF), op2=qutrits_per_chunk))

        # 3. Apply Modular Exponentiation for each chunk
        for i in range(num_chunks):
            instructions.append(self.pack_instruction(OP_MOD_EXP, target=i))

        # 4. Apply QFT
        instructions.append(self.pack_instruction(OP_QFT))

        # 5. Reality Collapse (Factor Extraction)
        instructions.append(self.pack_instruction(OP_REALITY_COLLAPSE))

        # 6. Halt
        instructions.append(self.pack_instruction(OP_HALT))

        return b"".join(instructions)

    def run_factoring(self):
        try:
            n = int(self.n_entry.get())
            num_chunks = int(self.chunks_entry.get())
            qutrits = int(self.qutrits_entry.get())
        except ValueError:
            messagebox.showerror("Error", "Invalid inputs. Please enter integers.")
            return

        self.run_btn.config(state=tk.DISABLED)
        self.log_area.delete(1.0, tk.END)
        self.log(f"Starting Shor's algorithm for N={n}...")
        self.log(f"Configuration: {num_chunks} chunks, {qutrits} qutrits per chunk.")
        
        threading.Thread(target=self.execute_engine, args=(n, num_chunks, qutrits), daemon=True).start()

    def execute_engine(self, n, num_chunks, qutrits):
        qbin_data = self.generate_qbin(n, num_chunks, qutrits)
        
        with tempfile.NamedTemporaryFile(suffix=".qbin", delete=False) as tmp:
            tmp.write(qbin_data)
            tmp_path = tmp.name

        try:
            if not os.path.exists(self.engine_path):
                # Try to build it if missing
                self.log("Engine binary not found. Attempting to build...")
                build_cmd = "nasm -f elf64 qutrit_engine_born_rule.asm -o qutrit_engine_born_rule.o && ld -o qutrit_engine_born_rule qutrit_engine_born_rule.o"
                subprocess.run(build_cmd, shell=True, check=True)
            
            os.chmod(self.engine_path, 0o755)
            
            process = subprocess.Popen(
                [self.engine_path, tmp_path],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                universal_newlines=True
            )

            for line in process.stdout:
                self.log(line.strip())
            
            process.wait()
            
            if process.returncode == 0:
                self.log("\nSuccess: Factoring complete.")
            else:
                self.log(f"\nError: Engine exited with code {process.returncode}")

        except Exception as e:
            self.log(f"\nExecution Error: {str(e)}")
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)
            self.root.after(0, lambda: self.run_btn.config(state=tk.NORMAL))

if __name__ == "__main__":
    root = tk.Tk()
    app = ShorFactoringGUI(root)
    root.mainloop()
