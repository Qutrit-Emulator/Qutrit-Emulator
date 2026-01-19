import tkinter as tk
from tkinter import ttk, messagebox, filedialog
import struct
import os

# Opcode Definitions
OPCODES = {
    "NOP (0x00)": 0x00,
    "INIT (0x01)": 0x01,
    "SUP (Superposition) (0x02)": 0x02,
    "MEASURE (0x07)": 0x07,
    "GROVER (Diffusion) (0x08)": 0x08,
    "BRAID (0x09)": 0x09,
    "UNBRAID (0x0A)": 0x0A,
    "PRINT_STATE (0x0D)": 0x0D,
    "BELL_TEST (0x0E)": 0x0E,
    "HEISENBERG (Spin-1) (0x80)": 0x80,
    "GELLMANN (XY Interact) (0x81)": 0x81,
    "MULT (Oracle) (0x82)": 0x82,
    "HALT (0xFF)": 0xFF
}

class QbinComposerApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Qutrit Circuit Composer")
        self.root.geometry("900x600")
        
        # Style
        self.style = ttk.Style()
        self.style.theme_use('clam')
        self._configure_styles()
        
        self.instructions = []
        
        self._create_layout()
        
    def _configure_styles(self):
        bg_color = "#161b22"
        fg_color = "#c9d1d9"
        accent = "#58a6ff"
        
        self.root.configure(bg=bg_color)
        
        self.style.configure("TFrame", background=bg_color)
        self.style.configure("TLabel", background=bg_color, foreground=fg_color, font=("Segoe UI", 10))
        self.style.configure("TButton", background="#238636", foreground="white", font=("Segoe UI", 10, "bold"))
        self.style.map("TButton", background=[("active", "#2ea043")])
        self.style.configure("Delete.TButton", background="#da3633")
        self.style.map("Delete.TButton", background=[("active", "#f85149")])
        
        self.style.configure("Treeview", 
                           background="#0d1117", 
                           foreground=fg_color, 
                           fieldbackground="#0d1117",
                           font=("Consolas", 10))
        self.style.configure("Treeview.Heading", background="#21262d", foreground=accent, font=("Segoe UI", 10, "bold"))
        self.style.map("Treeview", background=[('selected', '#1f6feb')])

    def _create_layout(self):
        # Main Container
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.pack(fill=tk.BOTH, expand=True)
        
        # Left Panel (Controls)
        left_panel = ttk.Frame(main_frame)
        left_panel.pack(side=tk.LEFT, fill=tk.Y, padx=(0, 10))
        
        ttk.Label(left_panel, text="Add Instruction", font=("Segoe UI", 14, "bold"), foreground="#58a6ff").pack(pady=(0, 15))
        
        # Opcode
        ttk.Label(left_panel, text="Opcode:").pack(anchor=tk.W)
        self.opcode_var = tk.StringVar()
        self.opcode_combo = ttk.Combobox(left_panel, textvariable=self.opcode_var, values=list(OPCODES.keys()), state="readonly")
        self.opcode_combo.current(0)
        self.opcode_combo.pack(fill=tk.X, pady=(0, 10))
        
        # Target
        ttk.Label(left_panel, text="Target (Chunk/Qutrit):").pack(anchor=tk.W)
        self.target_var = tk.IntVar(value=0)
        tk.Entry(left_panel, textvariable=self.target_var, bg="#0d1117", fg="white", insertbackground="white").pack(fill=tk.X, pady=(0, 10))
        
        # Operand 1
        ttk.Label(left_panel, text="Operand 1:").pack(anchor=tk.W)
        self.op1_var = tk.IntVar(value=0)
        tk.Entry(left_panel, textvariable=self.op1_var, bg="#0d1117", fg="white", insertbackground="white").pack(fill=tk.X, pady=(0, 10))
        
        # Operand 2
        ttk.Label(left_panel, text="Operand 2:").pack(anchor=tk.W)
        self.op2_var = tk.IntVar(value=0)
        tk.Entry(left_panel, textvariable=self.op2_var, bg="#0d1117", fg="white", insertbackground="white").pack(fill=tk.X, pady=(0, 10))
        
        # Add Button
        ttk.Button(left_panel, text="Add Instruction", command=self.add_instruction).pack(fill=tk.X, pady=10)
        
        ttk.Separator(left_panel, orient='horizontal').pack(fill=tk.X, pady=15)
        
        # File Ops
        ttk.Button(left_panel, text="Save .qbin", command=self.save_file).pack(fill=tk.X, pady=5)
        ttk.Button(left_panel, text="Clear All", command=self.clear_all, style="Delete.TButton").pack(fill=tk.X, pady=5)

        # Right Panel (List)
        right_panel = ttk.Frame(main_frame)
        right_panel.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True)
        
        ttk.Label(right_panel, text="Circuit Sequence", font=("Segoe UI", 12, "bold")).pack(anchor=tk.W, pady=(0, 10))
        
        cols = ("Index", "Opcode", "Hex Code", "Target", "Op1", "Op2")
        self.tree = ttk.Treeview(right_panel, columns=cols, show='headings', selectmode='browse')
        
        self.tree.heading("Index", text="#")
        self.tree.heading("Opcode", text="Opcode")
        self.tree.heading("Hex Code", text="Hex Code")
        self.tree.heading("Target", text="Target")
        self.tree.heading("Op1", text="Op1")
        self.tree.heading("Op2", text="Op2")
        
        self.tree.column("Index", width=40, anchor=tk.CENTER)
        self.tree.column("Opcode", width=120)
        self.tree.column("Hex Code", width=100, anchor=tk.CENTER)
        self.tree.column("Target", width=60, anchor=tk.CENTER)
        self.tree.column("Op1", width=60, anchor=tk.CENTER)
        self.tree.column("Op2", width=60, anchor=tk.CENTER)
        
        self.tree.pack(fill=tk.BOTH, expand=True)
        
        # Scrollbar
        scrollbar = ttk.Scrollbar(self.tree, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscroll=scrollbar.set)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        
        # Bind double click to delete
        self.tree.bind("<Double-1>", self.on_double_click)

    def add_instruction(self):
        op_name = self.opcode_var.get()
        op_code = OPCODES[op_name]
        target = self.target_var.get()
        op1 = self.op1_var.get()
        op2 = self.op2_var.get()
        
        # Validate 0-255
        if not all(0 <= x <= 255 for x in [target, op1, op2]):
            messagebox.showerror("Error", "Values must be between 0 and 255")
            return
            
        # Calculate Hex
        packed = (op_code << 24) | (target << 16) | (op1 << 8) | op2
        hex_str = f"0x{packed:08X}"
        
        idx = len(self.instructions) + 1
        self.instructions.append(packed)
        
        self.tree.insert("", tk.END, values=(idx, op_name.split(' (')[0], hex_str, target, op1, op2))
        
    def save_file(self):
        if not self.instructions:
            messagebox.showwarning("Warning", "No instructions to save!")
            return
            
        file_path = filedialog.asksaveasfilename(defaultextension=".qbin", 
                                                 filetypes=[("Qutrit Binary", "*.qbin"), ("All Files", "*.*")])
        if file_path:
            try:
                with open(file_path, "wb") as f:
                    for instr in self.instructions:
                        f.write(struct.pack('>I', instr))
                messagebox.showinfo("Success", f"Saved {len(self.instructions)} instructions to {os.path.basename(file_path)}")
            except Exception as e:
                messagebox.showerror("Error", f"Failed to save: {e}")

    def clear_all(self):
        if messagebox.askyesno("Confirm", "Clear all instructions?"):
            self.instructions = []
            for item in self.tree.get_children():
                self.tree.delete(item)

    def on_double_click(self, event):
        item = self.tree.selection()[0]
        # In a real app we'd map item ID to list index, but for now simple clear/re-add is safer
        # or just delete from end. Implementing delete specific item requires tracking IDs.
        # For MVP, we'll just show info.
        pass

if __name__ == "__main__":
    root = tk.Tk()
    app = QbinComposerApp(root)
    root.mainloop()
