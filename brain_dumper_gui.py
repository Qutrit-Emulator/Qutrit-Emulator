
import tkinter as tk
from tkinter import ttk, messagebox, filedialog
import struct
import subprocess
import threading
import os

# Opcodes
OP_INIT       = 0x01
OP_IM_WEIGHTS = 0x1A
OP_ORACLE     = 0x0B
OP_STORE_LO   = 0x17
OP_STORE_HI   = 0x18
OP_HALT       = 0xFF

ID_BRAIN_DUMP = 0x20 # Corrected: Engine adds 0x80 to reach 0xA0

class BrainDumperApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Infinite Brain Dumper")
        self.root.geometry("500x400")
        
        # Style
        style = ttk.Style()
        style.theme_use('clam')
        
        # --- Config Frame ---
        config_frame = ttk.LabelFrame(root, text="Configuration", padding="10")
        config_frame.pack(fill="x", padx=10, pady=10)
        
        # Qutrits per Chunk
        ttk.Label(config_frame, text="Qutrits per Chunk:").grid(row=0, column=0, sticky="w", pady=5)
        self.qutrits_var = tk.IntVar(value=10)
        self.qutrits_spin = ttk.Spinbox(config_frame, from_=1, to=14, textvariable=self.qutrits_var, width=10)
        self.qutrits_spin.grid(row=0, column=1, sticky="w", pady=5)
        ttk.Label(config_frame, text="(3^N states per chunk)").grid(row=0, column=2, sticky="w", padx=5)
        
        # Total Chunks
        ttk.Label(config_frame, text="Total Chunks:").grid(row=1, column=0, sticky="w", pady=5)
        self.chunks_var = tk.IntVar(value=10)
        self.chunks_entry = ttk.Entry(config_frame, textvariable=self.chunks_var, width=12)
        self.chunks_entry.grid(row=1, column=1, sticky="w", pady=5)
        
        # Start Offset
        ttk.Label(config_frame, text="Start Chunk Index:").grid(row=2, column=0, sticky="w", pady=5)
        self.start_var = tk.IntVar(value=0)
        self.start_entry = ttk.Entry(config_frame, textvariable=self.start_var, width=12)
        self.start_entry.grid(row=2, column=1, sticky="w", pady=5)
        
        # Output File
        file_frame = ttk.Frame(root, padding="0 10")
        file_frame.pack(fill="x", padx=10)
        
        ttk.Label(file_frame, text="Output File:").pack(anchor="w")
        self.file_path = tk.StringVar(value="brain_dump.txt")
        self.file_entry = ttk.Entry(file_frame, textvariable=self.file_path)
        self.file_entry.pack(side="left", fill="x", expand=True)
        ttk.Button(file_frame, text="Browse", command=self.browse_file).pack(side="right", padx=5)
        
        # --- Action Area ---
        action_frame = ttk.Frame(root, padding="10")
        action_frame.pack(fill="x", padx=10)
        
        self.progress_var = tk.DoubleVar()
        self.progress_bar = ttk.Progressbar(action_frame, variable=self.progress_var, maximum=100)
        self.progress_bar.pack(fill="x", pady=10)
        
        self.status_label = ttk.Label(action_frame, text="Ready.")
        self.status_label.pack(anchor="w")
        
        self.dump_btn = ttk.Button(action_frame, text="START BRAIN DUMP", command=self.start_dump, width=20)
        self.dump_btn.pack(pady=10)
        
        # Check Engine
        if not os.path.exists("./qutrit_engine"):
            self.status_label.config(text="Error: qutrit_engine not found!", foreground="red")
            self.dump_btn.config(state="disabled")

    def browse_file(self):
        f = filedialog.asksaveasfilename(defaultextension=".txt", initialfile="brain_dump.txt")
        if f:
            self.file_path.set(f)

    def make_instr(self, opcode, target=0, op1=0, op2=0):
        instr = (op2 << 48) | (op1 << 32) | (target << 16) | opcode
        return struct.pack('<Q', instr)
        
    def generate_qbin(self, filename):
        num_qutrits = self.qutrits_var.get()
        total_chunks = self.chunks_var.get()
        start_chunk = self.start_var.get()
        
        states_per_chunk = 3**num_qutrits
        
        program = b''
        program += self.make_instr(OP_INIT, target=0, op1=num_qutrits)
        program += self.make_instr(OP_IM_WEIGHTS)
        
        for i in range(total_chunks):
            chunk_id = start_chunk + i
            offset = chunk_id * states_per_chunk
            
            # Store Offset
            program += self.make_instr(OP_STORE_LO, target=1, op1=offset & 0xFFFF, op2=(offset >> 16) & 0xFFFF)
            program += self.make_instr(OP_STORE_HI, target=1, op1=(offset >> 32) & 0xFFFF, op2=(offset >> 48) & 0xFFFF)
            
            # Dump
            program += self.make_instr(OP_ORACLE, target=0, op1=ID_BRAIN_DUMP)
            
        program += self.make_instr(OP_HALT)
        
        with open(filename, 'wb') as f:
            f.write(program)
            
        return states_per_chunk, total_chunks

    def start_dump(self):
        self.dump_btn.config(state="disabled")
        self.status_label.config(text="Generating Logic Stream...", foreground="black")
        self.progress_var.set(0)
        
        threading.Thread(target=self.run_engine, daemon=True).start()
        
    def run_engine(self):
        qbin_name = "gui_dump.qbin"
        out_name = self.file_path.get()
        
        try:
            _, total_chunks = self.generate_qbin(qbin_name)
        except Exception as e:
            self.root.after(0, lambda: messagebox.showerror("Error", str(e)))
            self.root.after(0, self.reset_ui)
            return

        cmd = ["./qutrit_engine", qbin_name]
        
        try:
            with open(out_name, "w") as outfile:
                process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
                
                chunks_done = 0
                
                # Check line by line for progress
                # Format: [BRAIN] Exporting ... (Header for each chunk call? No)
                # brain_dump_oracle prints "  [BRAIN] Exporting ... Size: X"
                # So counting those lines = chunks processed.
                
                while True:
                    line = process.stdout.readline()
                    if not line:
                        break
                    
                    outfile.write(line)
                    
                    if "[BRAIN] Exporting" in line:
                        chunks_done += 1
                        pct = (chunks_done / total_chunks) * 100
                        self.root.after(0, lambda p=pct: self.progress_var.set(p))
                        self.root.after(0, lambda c=chunks_done: self.status_label.config(text=f"Processed Chunk {c}/{total_chunks}"))
                
                process.wait()
                
            self.root.after(0, lambda: messagebox.showinfo("Success", f"Dump complete: {out_name}"))
            
        except Exception as e:
            self.root.after(0, lambda: messagebox.showerror("Error", str(e)))
            
        self.root.after(0, self.reset_ui)

    def reset_ui(self):
        self.dump_btn.config(state="normal")
        self.status_label.config(text="Ready.")

if __name__ == "__main__":
    root = tk.Tk()
    app = BrainDumperApp(root)
    root.mainloop()
