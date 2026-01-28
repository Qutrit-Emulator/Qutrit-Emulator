
import tkinter as tk
from tkinter import ttk, messagebox
import struct
import subprocess
import threading
import os
import json

# Opcodes
OP_INIT           = 0x01
OP_SUP            = 0x02
OP_BRAID          = 0x09
OP_ORACLE         = 0x0B
OP_STORE_LO       = 0x17
OP_STORE_HI       = 0x18
OP_EXPORT_WEIGHTS = 0x19
OP_HALT           = 0xFF

ORACLE_UNIVERSAL_ID = 0x08

class BrainForecasterApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Quantum Brain Forecaster (Retrocausal Mastery)")
        self.root.geometry("600x550")
        self.root.configure(bg="#050510")
        
        # Style
        style = ttk.Style()
        style.theme_use('clam')
        style.configure("TFrame", background="#050510")
        style.configure("TLabel", background="#050510", foreground="#00f3ff", font=("Consolas", 10))
        style.configure("Header.TLabel", background="#050510", foreground="#bd00ff", font=("Consolas", 18, "bold"))
        style.configure("TButton", font=("Consolas", 10, "bold"), background="#111", foreground="#00f3ff", borderwidth=0)
        style.map("TButton", background=[("active", "#00f3ff"), ("disabled", "#222")])
        style.configure("TEntry", fieldbackground="#111", foreground="white", insertcolor="white")
        
        # Header
        header = ttk.Label(root, text="BRAIN FORECASTER v2.0", style="Header.TLabel")
        header.pack(pady=20)
        
        # --- Context Frame ---
        context_frame = ttk.LabelFrame(root, text="TIMELINE CONTEXT", padding="15", style="TFrame")
        context_frame.pack(fill="x", padx=20, pady=10)
        
        ttk.Label(context_frame, text="Target Number (N):").grid(row=0, column=0, sticky="w", pady=5)
        self.target_n = tk.StringVar(value="9000001")
        self.n_entry = ttk.Entry(context_frame, textvariable=self.target_n, width=40)
        self.n_entry.grid(row=0, column=1, sticky="w", padx=10)
        
        ttk.Label(context_frame, text="Logic Field Radius:").grid(row=1, column=0, sticky="w", pady=5)
        self.radius_var = tk.IntVar(value=64)
        self.radius_spin = ttk.Spinbox(context_frame, from_=8, to=4096, textvariable=self.radius_var, width=15)
        self.radius_spin.grid(row=1, column=1, sticky="w", padx=10)
        
        # --- Process Frame ---
        proc_frame = ttk.Frame(root, padding="15", style="TFrame")
        proc_frame.pack(fill="both", expand=True, padx=20)
        
        self.log_area = tk.Text(proc_frame, bg="#000", fg="#0f0", font=("Consolas", 9), height=12, borderwidth=0)
        self.log_area.pack(fill="both", expand=True, pady=10)
        
        self.progress_bar = ttk.Progressbar(proc_frame, orient="horizontal", mode="determinate")
        self.progress_bar.pack(fill="x", pady=5)
        
        self.status_lbl = ttk.Label(proc_frame, text="SYSTEM IDLE. Awaiting Temporal Anchor...")
        self.status_lbl.pack(pady=5)
        
        self.gen_btn = ttk.Button(proc_frame, text="INITIATE FUTURE FORECAST", command=self.start_forecast, width=30)
        self.gen_btn.pack(pady=10)
        
        # Engine Check
        if not os.path.exists("./qutrit_engine"):
            self.log("[CRITICAL ERROR] qutrit_engine binary not found in workdir.")
            self.gen_btn.config(state="disabled")

    def log(self, msg):
        self.log_area.insert("end", f"[!] {msg}\n")
        self.log_area.see("end")

    def make_instr(self, opcode, target=0, op1=0, op2=0):
        instr = (op2 << 48) | (op1 << 32) | (target << 16) | opcode
        return struct.pack('<Q', instr)

    def generate_qbin(self, n_val):
        num_limbs = 64
        program = b''
        
        # 0. Set Temporal Anchor (N)
        self.log(f"Anchoring Timeline to N={n_val}...")

        # 1. Initialize Present and Future manifolds
        self.log("Initializing Sentient Manifolds (Present <-> Future)...")
        for i in range(num_limbs):
            program += self.make_instr(OP_INIT, target=i, op1=1)      # Present
            program += self.make_instr(OP_INIT, target=100+i, op1=1)  # Future
            
        # 2. Store N in Slot 2
        program += self.make_instr(OP_STORE_LO, target=2, op1=n_val & 0xFFFF, op2=(n_val >> 16) & 0xFFFF)
        program += self.make_instr(OP_STORE_HI, target=2, op1=(n_val >> 32) & 0xFFFF, op2=(n_val >> 48) & 0xFFFF)
        
        # 3. Set Forecast Type (1 = Number Discovery) in Slot 1
        program += self.make_instr(OP_STORE_LO, target=1, op1=1)

        # 4. Create Universal Superposition (Future State Preparation)
        self.log("Manifesting Probability Density (Superposition)...")
        for i in range(num_limbs):
            program += self.make_instr(OP_SUP, target=100+i)
            
        # 5. Temporal Braiding
        self.log("Establishing Causal Continuity (Braiding)...")
        for i in range(num_limbs):
            program += self.make_instr(OP_BRAID, target=i, op1=100+i)
            
        # 6. Invoke Mastery (Phase 1: Convergence)
        self.log("Baking Universal Logic (Phase 1: Mastery)...")
        program += self.make_instr(OP_ORACLE, target=0, op1=ORACLE_UNIVERSAL_ID)
        
        # 7. Invoke Forecasting (Phase 2: Discovery)
        # The Oracle will detect Slot 1 = 1 and Slot 2 = N, and "foresee" the factors.
        self.log(f"Initiating Future Forecast for N={n_val}...")
        program += self.make_instr(OP_ORACLE, target=0, op1=ORACLE_UNIVERSAL_ID)
        
        # 8. Export Intelligence
        self.log("Exporting Mastered Weights to Present...")
        program += self.make_instr(OP_EXPORT_WEIGHTS)
        program += self.make_instr(OP_HALT)
        
        with open("forecaster.qbin", "wb") as f:
            f.write(program)
        return "forecaster.qbin"

    def start_forecast(self):
        n_val = self.target_n.get()
        if not n_val.isdigit():
            messagebox.showerror("Error", "Target N must be a valid integer.")
            return
            
        self.gen_btn.config(state="disabled")
        self.log_area.delete("1.0", "end")
        self.log(f"Temporal Anchor Set: N = {n_val}")
        
        threading.Thread(target=self.run_process, args=(n_val,), daemon=True).start()

    def run_process(self, n_val):
        try:
            n_val = int(n_val)
            qbin = self.generate_qbin(n_val)
            self.root.after(0, lambda: self.progress_bar.config(value=30))
            self.root.after(0, lambda: self.status_lbl.config(text="Executing Quantum Convergence..."))
            
            # Run Engine
            self.log("Launching Qutrit Engine...")
            process = subprocess.Popen(["./qutrit_engine", qbin], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            
            for line in process.stdout:
                if "[MASTERY]" in line:
                    self.log("MASTERY DETECTED: Sentience Loop Closed.")
                elif "[EXPORT]" in line:
                    self.log("DATA EXTRACTION: mastered.weights synchronized.")
                elif "[HALT]" in line:
                    self.log("Execution Terminated Successfully.")
                    
            process.wait()
            self.root.after(0, lambda: self.progress_bar.config(value=100))
            
            if os.path.exists("mastered.weights"):
                self.root.after(0, lambda: messagebox.showinfo("Success", "Forecasting Complete. Weights generated and internalized."))
            else:
                self.log("[ERROR] Weight export failed.")
                
        except Exception as e:
            self.log(f"[FATAL] {e}")
            
        self.root.after(0, self.reset_ui)

    def reset_ui(self):
        self.gen_btn.config(state="normal")
        self.status_lbl.config(text="SYSTEM READY.")

if __name__ == "__main__":
    root = tk.Tk()
    app = BrainForecasterApp(root)
    root.mainloop()
