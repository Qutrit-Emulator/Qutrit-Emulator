"""
Qutrit Engine GUI - Comprehensive Interactive Interface
A visual quantum programming environment for the Qutrit Engine simulator.

Features:
- Visual instruction builder with drag-and-drop
- Topology visualization for chunk braiding
- State amplitude visualization
- Preset experiments
- WSL integration for direct execution
"""

import tkinter as tk
from tkinter import ttk, messagebox, filedialog, scrolledtext
import struct
import subprocess
import os
import math
import json
from dataclasses import dataclass
from typing import List, Optional, Tuple, Dict
from pathlib import Path

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS - Opcodes matching qutrit_engine.asm
# ═══════════════════════════════════════════════════════════════════════════════

OPCODES = {
    'NOP':          0x00,
    'INIT':         0x01,
    'SUP':          0x02,
    'HADAMARD':     0x03,
    'PHASE':        0x04,
    'CPHASE':       0x05,
    'SWAP':         0x06,
    'MEASURE':      0x07,
    'GROVER':       0x08,
    'BRAID':        0x09,
    'UNBRAID':      0x0A,
    'ORACLE':       0x0B,
    'ADDON':        0x0C,
    'PRINT_STATE':  0x0D,
    'BELL_TEST':    0x0E,
    'SUMMARY':      0x0F,
    'SHIFT':        0x10,
    'REPAIR':       0x11,
    'HEISENBERG':   0x80,
    'GELLMANN':     0x81,
    'HALT':         0xFF,
}

OPCODE_NAMES = {v: k for k, v in OPCODES.items()}

# ═══════════════════════════════════════════════════════════════════════════════
# DATA STRUCTURES
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class Instruction:
    """Represents a single quantum instruction."""
    opcode: int
    args: List[int]
    comment: str = ""
    
    def to_bytes(self) -> bytes:
        """Pack instruction to 64-bit binary format.
        
        Format: [Op2:16][Op1:16][Target:16][Opcode:16] (little-endian)
        Each instruction is exactly 8 bytes.
        """
        # Extract arguments with defaults
        target = self.args[0] if len(self.args) > 0 else 0
        op1 = self.args[1] if len(self.args) > 1 else 0
        op2 = self.args[2] if len(self.args) > 2 else 0
        
        # Pack into 64-bit little-endian
        # Bits 0-15: opcode, 16-31: target, 32-47: op1, 48-63: op2
        packed = (
            (self.opcode & 0xFFFF) |
            ((target & 0xFFFF) << 16) |
            ((op1 & 0xFFFF) << 32) |
            ((op2 & 0xFFFF) << 48)
        )
        return struct.pack('<Q', packed)
    
    def to_python(self) -> str:
        """Generate Python code for this instruction."""
        name = OPCODE_NAMES.get(self.opcode, f'0x{self.opcode:02X}')
        target = self.args[0] if len(self.args) > 0 else 0
        op1 = self.args[1] if len(self.args) > 1 else 0
        op2 = self.args[2] if len(self.args) > 2 else 0
        comment = f"  # {self.comment}" if self.comment else ""
        return f"pack64(0x{self.opcode:02X}, {target}, {op1}, {op2}),{comment}  # {name}"

@dataclass
class Chunk:
    """Represents a quantum chunk."""
    id: int
    qutrits: int
    x: float = 0
    y: float = 0
    
    @property
    def states(self) -> int:
        return 3 ** self.qutrits

@dataclass
class BraidLink:
    """Represents entanglement between chunks."""
    chunk_a: int
    chunk_b: int
    qutrit_a: int = 0
    qutrit_b: int = 0
    strength: float = 1.0

# ═══════════════════════════════════════════════════════════════════════════════
# PRESET EXPERIMENTS
# ═══════════════════════════════════════════════════════════════════════════════

PRESETS = {
    "🔔 Bell State Demo": {
        "description": "Create a simple Bell state between two chunks and verify entanglement.",
        "instructions": [
            Instruction(OPCODES['INIT'], [0, 2, 0], "Initialize chunk 0 with 2 qutrits"),
            Instruction(OPCODES['INIT'], [1, 2, 0], "Initialize chunk 1 with 2 qutrits"),
            Instruction(OPCODES['SUP'], [0], "Create superposition on chunk 0"),
            Instruction(OPCODES['BRAID'], [0, 1, 0, 0], "Braid chunk 0 ↔ 1 at qutrit 0"),
            Instruction(OPCODES['BELL_TEST'], [0, 1], "Test entanglement"),
            Instruction(OPCODES['SUMMARY'], [], "Show global state"),
            Instruction(OPCODES['HALT'], [], "End program"),
        ]
    },
    "🌀 Grover Search": {
        "description": "Apply Grover's diffusion operator to amplify target states.",
        "instructions": [
            Instruction(OPCODES['INIT'], [0, 4, 0], "Initialize chunk 0 with 4 qutrits"),
            Instruction(OPCODES['SUP'], [0], "Create uniform superposition"),
            Instruction(OPCODES['GROVER'], [0], "Apply Grover diffusion"),
            Instruction(OPCODES['GROVER'], [0], "Second iteration"),
            Instruction(OPCODES['MEASURE'], [0], "Measure result"),
            Instruction(OPCODES['SUMMARY'], [], "Show result"),
            Instruction(OPCODES['HALT'], [], "End program"),
        ]
    },
    "💫 Triple Chunk Ring": {
        "description": "Create a ring topology with 3 chunks for wormhole experiments.",
        "instructions": [
            Instruction(OPCODES['INIT'], [0, 3, 0], "Initialize chunk 0"),
            Instruction(OPCODES['INIT'], [1, 3, 0], "Initialize chunk 1"),
            Instruction(OPCODES['INIT'], [2, 3, 0], "Initialize chunk 2"),
            Instruction(OPCODES['SUP'], [0], "Superposition on chunk 0"),
            Instruction(OPCODES['BRAID'], [0, 1, 0, 0], "Braid 0 ↔ 1"),
            Instruction(OPCODES['BRAID'], [1, 2, 0, 0], "Braid 1 ↔ 2"),
            Instruction(OPCODES['BRAID'], [2, 0, 0, 0], "Braid 2 ↔ 0 (close ring)"),
            Instruction(OPCODES['BELL_TEST'], [0, 2], "Test transitivity"),
            Instruction(OPCODES['SUMMARY'], [], "Show topology"),
            Instruction(OPCODES['HALT'], [], "End"),
        ]
    },
    "🧲 Heisenberg Frustration": {
        "description": "Apply Heisenberg exchange oracle to create spin frustration.",
        "instructions": [
            Instruction(OPCODES['INIT'], [0, 4, 0], "Initialize 4-qutrit chunk"),
            Instruction(OPCODES['SUP'], [0], "Create superposition"),
            Instruction(OPCODES['HEISENBERG'], [0, 100, 50], "J=100, dt=50"),
            Instruction(OPCODES['GROVER'], [0], "Amplify ground state"),
            Instruction(OPCODES['MEASURE'], [0], "Find minimum"),
            Instruction(OPCODES['HALT'], [], "End"),
        ]
    },
    "🔄 Topological Dissolution": {
        "description": "Demonstrate surgical unbraiding to dissolve entanglement.",
        "instructions": [
            Instruction(OPCODES['INIT'], [0, 2, 0], "Chunk 0"),
            Instruction(OPCODES['INIT'], [1, 2, 0], "Chunk 1"),
            Instruction(OPCODES['SUP'], [0], "Superposition"),
            Instruction(OPCODES['BRAID'], [0, 1, 0, 0], "Create entanglement"),
            Instruction(OPCODES['BELL_TEST'], [0, 1], "Verify entanglement"),
            Instruction(OPCODES['UNBRAID'], [0, 1, 0, 0], "Remove entanglement"),
            Instruction(OPCODES['BELL_TEST'], [0, 1], "Verify dissolution"),
            Instruction(OPCODES['HALT'], [], "End"),
        ]
    },
    "🎯 Prime Eraser (Small)": {
        "description": "Small-scale version of the Prime Manifold experiment.",
        "instructions": [
            Instruction(OPCODES['INIT'], [i, 4, 0], f"Chunk {i}") for i in range(7)
        ] + [
            Instruction(OPCODES['SUP'], [i], f"Superposition {i}") for i in range(7)
        ] + [
            Instruction(OPCODES['BRAID'], [i, (i+1)%7, 0, 0], f"Ring link {i}→{(i+1)%7}") for i in range(7)
        ] + [
            Instruction(OPCODES['HEISENBERG'], [0, 100, 50], "Heisenberg stress"),
            Instruction(OPCODES['SUMMARY'], [], "Show state"),
            Instruction(OPCODES['HALT'], [], "End"),
        ]
    },
}

# ═══════════════════════════════════════════════════════════════════════════════
# TOPOLOGY VISUALIZATION CANVAS
# ═══════════════════════════════════════════════════════════════════════════════

class TopologyCanvas(tk.Canvas):
    """Interactive canvas for visualizing chunk topology."""
    
    def __init__(self, parent, **kwargs):
        super().__init__(parent, bg='#1a1a2e', highlightthickness=0, **kwargs)
        self.chunks: Dict[int, Chunk] = {}
        self.braids: List[BraidLink] = []
        self.selected_chunk: Optional[int] = None
        self.drag_start: Optional[Tuple[int, int]] = None
        
        # Bind events
        self.bind('<Button-1>', self._on_click)
        self.bind('<B1-Motion>', self._on_drag)
        self.bind('<ButtonRelease-1>', self._on_release)
        self.bind('<Configure>', lambda e: self.redraw())
        
        # Colors
        self.colors = {
            'chunk': '#4a69bd',
            'chunk_hover': '#6a89cc',
            'chunk_selected': '#f39c12',
            'braid_strong': '#e74c3c',
            'braid_medium': '#f39c12',
            'braid_weak': '#3498db',
            'text': '#ecf0f1',
            'grid': '#2d2d44',
        }
    
    def add_chunk(self, chunk: Chunk):
        """Add a chunk to the visualization."""
        if chunk.id not in self.chunks:
            # Auto-position in a circle if no position set
            if chunk.x == 0 and chunk.y == 0:
                n = len(self.chunks)
                angle = 2 * math.pi * n / max(len(self.chunks) + 1, 8)
                w, h = self.winfo_width() or 400, self.winfo_height() or 300
                chunk.x = w/2 + (min(w, h)/3) * math.cos(angle)
                chunk.y = h/2 + (min(w, h)/3) * math.sin(angle)
            self.chunks[chunk.id] = chunk
            self.redraw()
    
    def add_braid(self, braid: BraidLink):
        """Add a braid link."""
        self.braids.append(braid)
        self.redraw()
    
    def clear(self):
        """Clear all chunks and braids."""
        self.chunks.clear()
        self.braids.clear()
        self.redraw()
    
    def redraw(self):
        """Redraw the entire canvas."""
        self.delete('all')
        w, h = self.winfo_width() or 400, self.winfo_height() or 300
        
        # Draw grid
        for i in range(0, w, 50):
            self.create_line(i, 0, i, h, fill=self.colors['grid'], dash=(2, 4))
        for i in range(0, h, 50):
            self.create_line(0, i, w, i, fill=self.colors['grid'], dash=(2, 4))
        
        # Draw braid links
        for braid in self.braids:
            if braid.chunk_a in self.chunks and braid.chunk_b in self.chunks:
                a, b = self.chunks[braid.chunk_a], self.chunks[braid.chunk_b]
                color = (self.colors['braid_strong'] if braid.strength > 0.7 else
                         self.colors['braid_medium'] if braid.strength > 0.3 else
                         self.colors['braid_weak'])
                width = max(1, int(braid.strength * 4))
                self.create_line(a.x, a.y, b.x, b.y, fill=color, width=width, dash=(5, 3))
        
        # Draw chunks
        for chunk in self.chunks.values():
            r = 25 + chunk.qutrits * 3  # Size based on qutrits
            color = (self.colors['chunk_selected'] if chunk.id == self.selected_chunk 
                    else self.colors['chunk'])
            
            # Outer glow
            self.create_oval(chunk.x-r-4, chunk.y-r-4, chunk.x+r+4, chunk.y+r+4,
                           fill='', outline=color, width=2)
            # Main circle
            self.create_oval(chunk.x-r, chunk.y-r, chunk.x+r, chunk.y+r,
                           fill=color, outline='#fff', width=2)
            # Label
            self.create_text(chunk.x, chunk.y-8, text=f"Chunk {chunk.id}",
                           fill=self.colors['text'], font=('Segoe UI', 9, 'bold'))
            self.create_text(chunk.x, chunk.y+8, text=f"{chunk.qutrits}q • {chunk.states} states",
                           fill=self.colors['text'], font=('Segoe UI', 7))
        
        # Legend
        self.create_text(10, h-60, text="Braid Strength:", anchor='w',
                        fill=self.colors['text'], font=('Segoe UI', 8))
        self.create_oval(10, h-45, 18, h-37, fill=self.colors['braid_strong'], outline='')
        self.create_text(25, h-41, text="Strong", anchor='w', fill=self.colors['text'], font=('Segoe UI', 8))
        self.create_oval(70, h-45, 78, h-37, fill=self.colors['braid_medium'], outline='')
        self.create_text(85, h-41, text="Medium", anchor='w', fill=self.colors['text'], font=('Segoe UI', 8))
        self.create_oval(140, h-45, 148, h-37, fill=self.colors['braid_weak'], outline='')
        self.create_text(155, h-41, text="Weak", anchor='w', fill=self.colors['text'], font=('Segoe UI', 8))
    
    def _on_click(self, event):
        """Handle click on canvas."""
        for chunk in self.chunks.values():
            r = 25 + chunk.qutrits * 3
            if (chunk.x - r <= event.x <= chunk.x + r and
                chunk.y - r <= event.y <= chunk.y + r):
                self.selected_chunk = chunk.id
                self.drag_start = (event.x - chunk.x, event.y - chunk.y)
                self.redraw()
                return
        self.selected_chunk = None
        self.redraw()
    
    def _on_drag(self, event):
        """Handle drag to move chunks."""
        if self.selected_chunk is not None and self.drag_start:
            chunk = self.chunks[self.selected_chunk]
            chunk.x = event.x - self.drag_start[0]
            chunk.y = event.y - self.drag_start[1]
            self.redraw()
    
    def _on_release(self, event):
        """Handle mouse release."""
        self.drag_start = None

# ═══════════════════════════════════════════════════════════════════════════════
# INSTRUCTION LIST WIDGET
# ═══════════════════════════════════════════════════════════════════════════════

class InstructionList(ttk.Frame):
    """Widget for managing the instruction list."""
    
    def __init__(self, parent, on_change=None, **kwargs):
        super().__init__(parent, **kwargs)
        self.instructions: List[Instruction] = []
        self.on_change = on_change
        
        # Listbox with scrollbar
        self.listbox = tk.Listbox(self, bg='#1e1e2e', fg='#cdd6f4', 
                                  selectbackground='#45475a', selectforeground='#f5e0dc',
                                  font=('Consolas', 10), height=12, width=45)
        scrollbar = ttk.Scrollbar(self, orient='vertical', command=self.listbox.yview)
        self.listbox.configure(yscrollcommand=scrollbar.set)
        
        self.listbox.pack(side='left', fill='both', expand=True)
        scrollbar.pack(side='right', fill='y')
        
        # Bind events
        self.listbox.bind('<Delete>', lambda e: self.remove_selected())
        self.listbox.bind('<Double-1>', lambda e: self.edit_selected())
    
    def add_instruction(self, instr: Instruction):
        """Add an instruction to the list."""
        self.instructions.append(instr)
        self._refresh()
        if self.on_change:
            self.on_change()
    
    def remove_selected(self):
        """Remove the selected instruction."""
        sel = self.listbox.curselection()
        if sel:
            del self.instructions[sel[0]]
            self._refresh()
            if self.on_change:
                self.on_change()
    
    def edit_selected(self):
        """Edit the selected instruction (placeholder)."""
        pass  # Could open edit dialog
    
    def clear(self):
        """Clear all instructions."""
        self.instructions.clear()
        self._refresh()
        if self.on_change:
            self.on_change()
    
    def set_instructions(self, instructions: List[Instruction]):
        """Set the instruction list."""
        self.instructions = list(instructions)
        self._refresh()
        if self.on_change:
            self.on_change()
    
    def _refresh(self):
        """Refresh the listbox display."""
        self.listbox.delete(0, 'end')
        for i, instr in enumerate(self.instructions):
            name = OPCODE_NAMES.get(instr.opcode, f'0x{instr.opcode:02X}')
            args_str = ', '.join(str(a) for a in instr.args)
            text = f"{i+1:2}. {name:12} {args_str}"
            if instr.comment:
                text += f"  # {instr.comment}"
            self.listbox.insert('end', text)
    
    def move_up(self):
        """Move selected instruction up."""
        sel = self.listbox.curselection()
        if sel and sel[0] > 0:
            idx = sel[0]
            self.instructions[idx], self.instructions[idx-1] = \
                self.instructions[idx-1], self.instructions[idx]
            self._refresh()
            self.listbox.selection_set(idx-1)
            if self.on_change:
                self.on_change()
    
    def move_down(self):
        """Move selected instruction down."""
        sel = self.listbox.curselection()
        if sel and sel[0] < len(self.instructions) - 1:
            idx = sel[0]
            self.instructions[idx], self.instructions[idx+1] = \
                self.instructions[idx+1], self.instructions[idx]
            self._refresh()
            self.listbox.selection_set(idx+1)
            if self.on_change:
                self.on_change()

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN APPLICATION
# ═══════════════════════════════════════════════════════════════════════════════

class QutritEngineGUI(tk.Tk):
    """Main application window."""
    
    def __init__(self):
        super().__init__()
        
        self.title("🔮 Qutrit Engine GUI - Quantum Simulator")
        self.geometry("1280x800")
        self.configure(bg='#11111b')
        
        # Set theme colors
        self.style = ttk.Style()
        self.style.theme_use('clam')
        self._configure_styles()
        
        # Track state
        self.chunks: Dict[int, Chunk] = {}
        self.braids: List[BraidLink] = []
        
        # Build UI
        self._create_menu()
        self._create_toolbar()
        self._create_main_layout()
        
        # Show welcome message
        self._log("═" * 60)
        self._log("  QUTRIT ENGINE GUI v1.0")
        self._log("  |0⟩=△ Triangle  |1⟩=─ Line  |2⟩=□ Square")
        self._log("═" * 60)
        self._log("Welcome! Start by adding instructions or loading a preset.")
        self._log("")
    
    def _configure_styles(self):
        """Configure ttk styles for dark theme."""
        import platform
        
        # Platform-aware fonts
        if platform.system() == 'Linux':
            ui_font = 'DejaVu Sans'
            mono_font = 'DejaVu Sans Mono'
        else:
            ui_font = 'Segoe UI'
            mono_font = 'Consolas'
        
        self.ui_font = ui_font
        self.mono_font = mono_font
        
        colors = {
            'bg': '#1e1e2e',
            'fg': '#cdd6f4',
            'select': '#45475a',
            'button': '#313244',
            'button_active': '#45475a',
            'accent': '#89b4fa',
        }
        
        self.style.configure('TFrame', background=colors['bg'])
        self.style.configure('TLabel', background=colors['bg'], foreground=colors['fg'],
                           font=(ui_font, 10))
        self.style.configure('TButton', background=colors['button'], foreground=colors['fg'],
                           font=(ui_font, 10), padding=6)
        self.style.map('TButton', background=[('active', colors['button_active'])])
        self.style.configure('Header.TLabel', font=(ui_font, 12, 'bold'), 
                           foreground=colors['accent'])
        self.style.configure('TLabelframe', background=colors['bg'], foreground=colors['fg'])
        self.style.configure('TLabelframe.Label', background=colors['bg'], 
                           foreground=colors['accent'], font=(ui_font, 10, 'bold'))
        self.style.configure('TCombobox', fieldbackground=colors['bg'], 
                           background=colors['button'], foreground=colors['fg'])
        self.style.configure('TEntry', fieldbackground='#313244', foreground=colors['fg'])
        self.style.configure('Accent.TButton', background='#89b4fa', foreground='#1e1e2e',
                           font=(ui_font, 10, 'bold'))
    
    def _create_menu(self):
        """Create the menu bar."""
        menubar = tk.Menu(self, bg='#1e1e2e', fg='#cdd6f4', 
                         activebackground='#45475a', activeforeground='#f5e0dc')
        
        # File menu
        file_menu = tk.Menu(menubar, tearoff=0, bg='#1e1e2e', fg='#cdd6f4')
        file_menu.add_command(label="📂 Open .qbin...", command=self._load_qbin)
        file_menu.add_command(label="💾 Save .qbin...", command=self._save_qbin)
        file_menu.add_separator()
        file_menu.add_command(label="📄 Export Python...", command=self._export_python)
        file_menu.add_separator()
        file_menu.add_command(label="Exit", command=self.quit)
        menubar.add_cascade(label="File", menu=file_menu)
        
        # Presets menu
        preset_menu = tk.Menu(menubar, tearoff=0, bg='#1e1e2e', fg='#cdd6f4')
        for name in PRESETS:
            preset_menu.add_command(label=name, 
                                   command=lambda n=name: self._load_preset(n))
        menubar.add_cascade(label="🧪 Presets", menu=preset_menu)
        
        # Help menu
        help_menu = tk.Menu(menubar, tearoff=0, bg='#1e1e2e', fg='#cdd6f4')
        help_menu.add_command(label="📖 Quick Start", command=self._show_quickstart)
        help_menu.add_command(label="📚 Opcode Reference", command=self._show_opcodes)
        help_menu.add_separator()
        help_menu.add_command(label="About", command=self._show_about)
        menubar.add_cascade(label="Help", menu=help_menu)
        
        self.config(menu=menubar)
    
    def _create_toolbar(self):
        """Create the toolbar."""
        toolbar = ttk.Frame(self)
        toolbar.pack(fill='x', padx=5, pady=5)
        
        # Preset dropdown
        ttk.Label(toolbar, text="Quick Start:").pack(side='left', padx=(0, 5))
        self.preset_var = tk.StringVar(value="Select Preset...")
        preset_combo = ttk.Combobox(toolbar, textvariable=self.preset_var, 
                                   values=list(PRESETS.keys()), state='readonly', width=25)
        preset_combo.pack(side='left', padx=(0, 10))
        preset_combo.bind('<<ComboboxSelected>>', lambda e: self._load_preset(self.preset_var.get()))
        
        # Spacer
        ttk.Frame(toolbar).pack(side='left', fill='x', expand=True)
        
        # Action buttons
        ttk.Button(toolbar, text="🗑️ Clear", command=self._clear_all).pack(side='left', padx=2)
        ttk.Button(toolbar, text="💾 Save", command=self._save_qbin).pack(side='left', padx=2)
        
        # Run button (prominent)
        self.run_btn = ttk.Button(toolbar, text="▶ RUN", command=self._run_program, 
                                 style='Accent.TButton')
        self.run_btn.pack(side='left', padx=(10, 0))
    
    def _create_main_layout(self):
        """Create the main layout with panels."""
        # Main container with PanedWindow for resizable panels
        main_paned = ttk.PanedWindow(self, orient='horizontal')
        main_paned.pack(fill='both', expand=True, padx=5, pady=5)
        
        # Left panel: Instruction Builder
        left_frame = ttk.Frame(main_paned)
        self._create_instruction_panel(left_frame)
        main_paned.add(left_frame, weight=1)
        
        # Right panel container
        right_paned = ttk.PanedWindow(main_paned, orient='vertical')
        main_paned.add(right_paned, weight=2)
        
        # Top right: Topology + Code
        top_right = ttk.Frame(right_paned)
        self._create_top_right_panel(top_right)
        right_paned.add(top_right, weight=2)
        
        # Bottom right: Output log
        bottom_right = ttk.Frame(right_paned)
        self._create_output_panel(bottom_right)
        right_paned.add(bottom_right, weight=1)
    
    def _create_instruction_panel(self, parent):
        """Create the instruction builder panel."""
        # Header
        header = ttk.Frame(parent)
        header.pack(fill='x', pady=(0, 5))
        ttk.Label(header, text="📋 INSTRUCTION BUILDER", style='Header.TLabel').pack(side='left')
        
        # Add operation controls
        add_frame = ttk.LabelFrame(parent, text="➕ Add Operation", padding=10)
        add_frame.pack(fill='x', pady=(0, 10))
        
        # Operation selector
        op_row = ttk.Frame(add_frame)
        op_row.pack(fill='x', pady=2)
        ttk.Label(op_row, text="Operation:").pack(side='left')
        self.op_var = tk.StringVar(value='INIT')
        op_combo = ttk.Combobox(op_row, textvariable=self.op_var,
                               values=list(OPCODES.keys()), state='readonly', width=15)
        op_combo.pack(side='left', padx=5)
        op_combo.bind('<<ComboboxSelected>>', self._on_op_change)
        
        # Dynamic argument inputs
        self.args_frame = ttk.Frame(add_frame)
        self.args_frame.pack(fill='x', pady=5)
        self.arg_entries = []
        self._on_op_change(None)
        
        # Add button
        ttk.Button(add_frame, text="➕ Add Instruction", 
                  command=self._add_instruction).pack(fill='x', pady=(5, 0))
        
        # Instruction list
        list_frame = ttk.LabelFrame(parent, text="📜 Program Instructions", padding=5)
        list_frame.pack(fill='both', expand=True)
        
        self.instr_list = InstructionList(list_frame, on_change=self._on_program_change)
        self.instr_list.pack(fill='both', expand=True)
        
        # List controls
        btn_frame = ttk.Frame(list_frame)
        btn_frame.pack(fill='x', pady=(5, 0))
        ttk.Button(btn_frame, text="⬆", width=3, command=self.instr_list.move_up).pack(side='left', padx=1)
        ttk.Button(btn_frame, text="⬇", width=3, command=self.instr_list.move_down).pack(side='left', padx=1)
        ttk.Button(btn_frame, text="🗑", width=3, command=self.instr_list.remove_selected).pack(side='left', padx=1)
        ttk.Button(btn_frame, text="Clear All", command=self.instr_list.clear).pack(side='right')
    
    def _create_top_right_panel(self, parent):
        """Create the topology and code panels."""
        # Horizontal split
        paned = ttk.PanedWindow(parent, orient='horizontal')
        paned.pack(fill='both', expand=True)
        
        # Topology canvas
        topo_frame = ttk.LabelFrame(paned, text="🕸️ TOPOLOGY VISUALIZER", padding=5)
        paned.add(topo_frame, weight=1)
        
        self.topology = TopologyCanvas(topo_frame)
        self.topology.pack(fill='both', expand=True)
        
        # Code view
        code_frame = ttk.LabelFrame(paned, text="💻 GENERATED CODE", padding=5)
        paned.add(code_frame, weight=1)
        
        self.code_text = scrolledtext.ScrolledText(code_frame, bg='#1e1e2e', fg='#a6e3a1',
                                                   font=('Consolas', 9), wrap='none',
                                                   insertbackground='#cdd6f4')
        self.code_text.pack(fill='both', expand=True)
        
        # Copy button
        ttk.Button(code_frame, text="📋 Copy Code", 
                  command=self._copy_code).pack(fill='x', pady=(5, 0))
    
    def _create_output_panel(self, parent):
        """Create the output log panel."""
        # Header with controls
        header = ttk.Frame(parent)
        header.pack(fill='x')
        ttk.Label(header, text="📤 OUTPUT LOG", style='Header.TLabel').pack(side='left')
        ttk.Button(header, text="Clear", command=lambda: self.output_text.delete(1.0, 'end')).pack(side='right')
        
        # Output text
        self.output_text = scrolledtext.ScrolledText(parent, bg='#11111b', fg='#bac2de',
                                                    font=('Consolas', 9), height=8,
                                                    insertbackground='#cdd6f4')
        self.output_text.pack(fill='both', expand=True, pady=(5, 0))
        
        # Configure tags for colored output
        self.output_text.tag_configure('success', foreground='#a6e3a1')
        self.output_text.tag_configure('error', foreground='#f38ba8')
        self.output_text.tag_configure('info', foreground='#89b4fa')
        self.output_text.tag_configure('warning', foreground='#fab387')
    
    def _on_op_change(self, event):
        """Update argument inputs when operation changes."""
        # Clear existing
        for widget in self.args_frame.winfo_children():
            widget.destroy()
        self.arg_entries.clear()
        
        op = self.op_var.get()
        
        # Define argument specs for each operation
        arg_specs = {
            'INIT': [('Chunk ID:', 0), ('Qutrits:', 4), ('(reserved):', 0)],
            'SUP': [('Chunk ID:', 0)],
            'HADAMARD': [('Chunk ID:', 0), ('Qutrit Index:', 0)],
            'PHASE': [('Chunk ID:', 0), ('Phase (×π/3):', 1)],
            'BRAID': [('Chunk A:', 0), ('Chunk B:', 1), ('Qutrit A:', 0), ('Qutrit B:', 0)],
            'UNBRAID': [('Chunk A:', 0), ('Chunk B:', 1), ('Qutrit A:', 0), ('Qutrit B:', 0)],
            'GROVER': [('Chunk ID:', 0)],
            'MEASURE': [('Chunk ID:', 0)],
            'BELL_TEST': [('Chunk A:', 0), ('Chunk B:', 1)],
            'ORACLE': [('Chunk ID:', 0), ('Oracle Type:', 0), ('Param1:', 0)],
            'HEISENBERG': [('Chunk ID:', 0), ('Coupling J:', 100), ('Time dt:', 50)],
            'GELLMANN': [('Chunk ID:', 0)],
            'SHIFT': [('Chunk ID:', 0)],
            'SUMMARY': [],
            'PRINT_STATE': [('Chunk ID:', 0)],
            'HALT': [],
        }
        
        specs = arg_specs.get(op, [])
        for label, default in specs:
            row = ttk.Frame(self.args_frame)
            row.pack(fill='x', pady=1)
            ttk.Label(row, text=label, width=12).pack(side='left')
            entry = ttk.Entry(row, width=10)
            entry.insert(0, str(default))
            entry.pack(side='left', padx=5)
            self.arg_entries.append(entry)
    
    def _add_instruction(self):
        """Add instruction from form."""
        op = self.op_var.get()
        opcode = OPCODES.get(op, 0)
        
        args = []
        for entry in self.arg_entries:
            try:
                args.append(int(entry.get()))
            except ValueError:
                args.append(0)
        
        instr = Instruction(opcode, args, comment=op)
        self.instr_list.add_instruction(instr)
        
        # Update topology if needed
        if op == 'INIT' and len(args) >= 2:
            chunk = Chunk(id=args[0], qutrits=args[1])
            self.chunks[args[0]] = chunk
            self.topology.add_chunk(chunk)
        elif op == 'BRAID' and len(args) >= 2:
            braid = BraidLink(args[0], args[1], 
                            args[2] if len(args) > 2 else 0,
                            args[3] if len(args) > 3 else 0)
            self.braids.append(braid)
            self.topology.add_braid(braid)
        
        self._log(f"Added: {op} {args}")
    
    def _on_program_change(self):
        """Called when instructions change."""
        self._update_code_view()
    
    def _update_code_view(self):
        """Update the generated code view."""
        self.code_text.delete(1.0, 'end')
        
        code = '''# Qutrit Engine Program
# Generated by Qutrit GUI
# Instructions are 64-bit packed: [Op2:16][Op1:16][Target:16][Opcode:16]

import struct

def pack64(opcode, target=0, op1=0, op2=0):
    """Pack instruction into 64-bit format for qutrit_engine."""
    packed = (
        (opcode & 0xFFFF) |
        ((target & 0xFFFF) << 16) |
        ((op1 & 0xFFFF) << 32) |
        ((op2 & 0xFFFF) << 48)
    )
    return struct.pack('<Q', packed)

def create_qbin():
    """Generate .qbin binary payload."""
    instructions = [
'''
        for instr in self.instr_list.instructions:
            code += f"        {instr.to_python()}\n"
        
        code += '''    ]
    
    # Concatenate all 8-byte instructions
    data = b''.join(instructions)
    return data

if __name__ == "__main__":
    qbin = create_qbin()
    with open("program.qbin", "wb") as f:
        f.write(qbin)
    print(f"Written {len(qbin)} bytes to program.qbin")
'''
        self.code_text.insert(1.0, code)
    
    def _log(self, message: str, tag: str = None):
        """Add message to output log."""
        from datetime import datetime
        timestamp = datetime.now().strftime("%H:%M:%S")
        self.output_text.insert('end', f"[{timestamp}] ")
        if tag:
            self.output_text.insert('end', f"{message}\n", tag)
        else:
            self.output_text.insert('end', f"{message}\n")
        self.output_text.see('end')
    
    def _load_preset(self, name: str):
        """Load a preset experiment."""
        if name not in PRESETS:
            return
        
        preset = PRESETS[name]
        self._clear_all()
        
        self._log(f"Loading preset: {name}", 'info')
        self._log(f"  {preset['description']}")
        
        # Load instructions
        for instr in preset['instructions']:
            self.instr_list.add_instruction(instr)
            
            # Update topology
            if instr.opcode == OPCODES['INIT'] and len(instr.args) >= 2:
                chunk = Chunk(id=instr.args[0], qutrits=instr.args[1])
                self.chunks[instr.args[0]] = chunk
                self.topology.add_chunk(chunk)
            elif instr.opcode == OPCODES['BRAID'] and len(instr.args) >= 2:
                braid = BraidLink(instr.args[0], instr.args[1])
                self.braids.append(braid)
                self.topology.add_braid(braid)
        
        self._log(f"Loaded {len(preset['instructions'])} instructions", 'success')
        self.preset_var.set("Select Preset...")
    
    def _clear_all(self):
        """Clear everything."""
        self.instr_list.clear()
        self.topology.clear()
        self.chunks.clear()
        self.braids.clear()
        self._update_code_view()
    
    def _save_qbin(self):
        """Save program to .qbin file."""
        filename = filedialog.asksaveasfilename(
            defaultextension=".qbin",
            filetypes=[("Qutrit Binary", "*.qbin"), ("All files", "*.*")],
            initialfile="program.qbin"
        )
        if not filename:
            return
        
        data = b''
        for instr in self.instr_list.instructions:
            data += instr.to_bytes()
        
        with open(filename, 'wb') as f:
            f.write(data)
        
        self._log(f"Saved {len(data)} bytes to {filename}", 'success')
    
    def _load_qbin(self):
        """Load program from .qbin file."""
        filename = filedialog.askopenfilename(
            filetypes=[("Qutrit Binary", "*.qbin"), ("All files", "*.*")]
        )
        if not filename:
            return
        
        # TODO: Implement binary parsing
        self._log(f"Loading from {filename}...", 'info')
        messagebox.showinfo("Not Implemented", "Binary loading coming soon!")
    
    def _export_python(self):
        """Export as Python script."""
        filename = filedialog.asksaveasfilename(
            defaultextension=".py",
            filetypes=[("Python", "*.py"), ("All files", "*.*")],
            initialfile="qutrit_program.py"
        )
        if not filename:
            return
        
        with open(filename, 'w') as f:
            f.write(self.code_text.get(1.0, 'end'))
        
        self._log(f"Exported Python script to {filename}", 'success')
    
    def _copy_code(self):
        """Copy generated code to clipboard."""
        self.clipboard_clear()
        self.clipboard_append(self.code_text.get(1.0, 'end'))
        self._log("Code copied to clipboard", 'success')
    
    def _run_program(self):
        """Run the program - native on Linux, via WSL on Windows."""
        import platform
        
        if not self.instr_list.instructions:
            self._log("No instructions to run!", 'error')
            return
        
        # Detect platform
        is_linux = platform.system() == 'Linux'
        is_windows = platform.system() == 'Windows'
        
        if is_linux:
            self._log("Running natively on Linux...", 'info')
        elif is_windows:
            self._log("Detected Windows - will use WSL...", 'info')
        else:
            self._log(f"Platform: {platform.system()} - attempting native execution...", 'info')
        
        # Save temporary .qbin
        script_dir = Path(__file__).parent.resolve()
        temp_qbin = script_dir / "temp_program.qbin"
        data = b''
        for instr in self.instr_list.instructions:
            data += instr.to_bytes()
        
        with open(temp_qbin, 'wb') as f:
            f.write(data)
        
        self._log(f"Created temporary program ({len(data)} bytes)", 'info')
        
        # Check for binary
        binary_path = script_dir / "qutrit_engine"
        
        if is_linux or (not is_windows):
            # Native Linux execution
            if not binary_path.exists():
                self._log("Binary not found! Build it first:", 'error')
                self._log("  nasm -f elf64 -g -F dwarf qutrit_engine.asm -o qutrit_engine.o", 'info')
                self._log("  ld -o qutrit_engine qutrit_engine.o", 'info')
                return
            
            # Make sure it's executable
            try:
                os.chmod(binary_path, 0o755)
            except:
                pass
            
            self._log("Executing qutrit_engine...", 'info')
            self._log("-" * 50)
            
            try:
                result = subprocess.run(
                    [str(binary_path), str(temp_qbin)],
                    capture_output=True, text=True, timeout=120,
                    cwd=str(script_dir)
                )
                
                self._process_output(result)
                
            except subprocess.TimeoutExpired:
                self._log("Execution timed out after 120 seconds", 'error')
            except PermissionError:
                self._log("Permission denied. Try: chmod +x qutrit_engine", 'error')
            except Exception as e:
                self._log(f"Error running program: {e}", 'error')
        
        else:
            # Windows - use WSL
            try:
                result = subprocess.run(['wsl', '--status'], capture_output=True, timeout=5)
                has_wsl = result.returncode == 0
            except:
                has_wsl = False
            
            if not has_wsl:
                self._log("WSL not available.", 'warning')
                self._log(f"Program saved to: {temp_qbin}", 'info')
                self._log("Transfer to Linux and run: ./qutrit_engine temp_program.qbin", 'info')
                return
            
            # Get WSL path
            try:
                wsl_path = subprocess.run(
                    ['wsl', 'wslpath', '-a', str(script_dir)], 
                    capture_output=True, text=True
                ).stdout.strip()
            except:
                wsl_path = str(script_dir).replace('\\', '/').replace('C:', '/mnt/c')
            
            self._log("Executing via WSL...", 'info')
            self._log("-" * 50)
            
            try:
                result = subprocess.run(
                    ['wsl', 'bash', '-c', f'cd "{wsl_path}" && ./qutrit_engine temp_program.qbin'],
                    capture_output=True, text=True, timeout=120
                )
                
                self._process_output(result)
                
            except subprocess.TimeoutExpired:
                self._log("Execution timed out after 120 seconds", 'error')
            except FileNotFoundError:
                self._log("Binary not found in WSL. Build it first:", 'error')
                self._log(f"  cd {wsl_path}", 'info')
                self._log("  nasm -f elf64 qutrit_engine.asm -o qutrit_engine.o", 'info')
                self._log("  ld -o qutrit_engine qutrit_engine.o", 'info')
            except Exception as e:
                self._log(f"Error running program: {e}", 'error')
    
    def _process_output(self, result):
        """Process and display subprocess output."""
        if result.stdout:
            for line in result.stdout.split('\n'):
                if not line.strip():
                    continue
                if '✓' in line or 'PASS' in line:
                    self._log(line, 'success')
                elif 'ERROR' in line or '✗' in line or 'FAIL' in line:
                    self._log(line, 'error')
                elif '[' in line and ']' in line:
                    self._log(line, 'info')
                else:
                    self._log(line)
        
        if result.stderr:
            for line in result.stderr.split('\n'):
                if line.strip():
                    self._log(f"[stderr] {line}", 'warning')
        
        self._log("-" * 50)
        if result.returncode == 0:
            self._log("Program completed successfully!", 'success')
        else:
            self._log(f"Program exited with code {result.returncode}", 'error')
    
    def _show_quickstart(self):
        """Show quick start guide."""
        help_text = """
🚀 QUICK START GUIDE

1. SELECT A PRESET
   Use the "Presets" menu or dropdown to load a pre-built experiment.
   This is the fastest way to see the engine in action!

2. BUILD YOUR OWN PROGRAM
   • Select an operation from the dropdown
   • Fill in the parameters
   • Click "Add Instruction"
   • Repeat to build your program

3. RUN YOUR PROGRAM
   • Click "▶ RUN" to execute via WSL
   • Or save as .qbin and run on Linux

4. UNDERSTAND THE TOPOLOGY
   • INIT creates chunks (quantum registers)
   • BRAID entangles chunks together
   • The topology canvas shows connections
   • Drag chunks to rearrange

OPCODES REFERENCE:
   INIT(chunk, qutrits)  - Initialize a chunk
   SUP(chunk)            - Create superposition
   BRAID(a, b, qa, qb)   - Entangle chunks
   GROVER(chunk)         - Amplify states
   MEASURE(chunk)        - Collapse to classical
   BELL_TEST(a, b)       - Verify entanglement
"""
        messagebox.showinfo("Quick Start", help_text)
    
    def _show_opcodes(self):
        """Show opcode reference."""
        ref = "OPCODE REFERENCE\n\n"
        for name, code in sorted(OPCODES.items(), key=lambda x: x[1]):
            ref += f"0x{code:02X}  {name}\n"
        messagebox.showinfo("Opcode Reference", ref)
    
    def _show_about(self):
        """Show about dialog."""
        messagebox.showinfo("About", 
            "Qutrit Engine GUI v1.0\n\n"
            "A visual quantum programming environment for the\n"
            "Qutrit Engine parallel reality simulator.\n\n"
            "© 2026 - MIT License")

# ═══════════════════════════════════════════════════════════════════════════════
# ENTRY POINT
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    app = QutritEngineGUI()
    app.mainloop()
