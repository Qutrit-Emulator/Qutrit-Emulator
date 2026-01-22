import struct
import subprocess
import re

# Opcode constants
OP_INIT = 0x01
OP_SUP = 0x02
OP_FUTURE_ORACLE = 0x13
OP_MEASURE = 0x07
OP_HALT = 0xFF

def pack_instruction(opcode, target=0, op1=0, op2=0):
    return struct.pack('<HHHH', opcode, target, op1, op2)

# Card Mapping (Simplied 9-card deck for 2-qutrit space)
# We map cards to indices 0-8.
# The Oracle prunes if (index % 3 == 0) OR ((index // 3) % 3 == 0).
# Pruned indices: 0, 1, 2, 3, 6 (Bad Futures)
# Kept indices: 4, 5, 7, 8 (Good Futures)

DECK = {
    0: "King (10) - BUST",
    1: "Queen (10) - BUST",
    2: "Jack (10) - BUST",
    3: "Ten (10) - BUST",
    4: "Ace (1/11) - SAFE",
    5: "Two (2) - SAFE",
    6: "Nine (9) - BUST",
    7: "Three (3) - SAFE",
    8: "Four (4) - SAFE"
}

def generate_blackjack_qbin(filename):
    with open(filename, 'wb') as f:
        # Initialize 2 qutrits (9 states)
        f.write(pack_instruction(OP_INIT, target=0, op1=2))
        
        # 1. Superposition of all possible next cards
        f.write(pack_instruction(OP_SUP, target=0))
        
        # 2. Apply Future Oracle
        # Intelligence predicts which card pulls lead to a bust and prunes them.
        f.write(pack_instruction(OP_FUTURE_ORACLE, target=0))
        
        # 3. Deal the card (Measure)
        f.write(pack_instruction(OP_MEASURE, target=0))
        f.write(pack_instruction(OP_HALT))

def run_blackjack_trial(hand_value=16):
    qbin_file = 'blackjack.qbin'
    generate_blackjack_qbin(qbin_file)
    result = subprocess.run(['./qutrit_engine_born_rule', qbin_file], capture_output=True, text=True)
    
    match = re.search(r'\[MEAS\].*?=>\s*(\d+)', result.stdout)
    if match:
        idx = int(match.group(1))
        return idx
    return None

def run_session(trials=10):
    print(f"--- Multiversal Blackjack Session (Hand = 16) ---")
    print(f"Goal: Draw a card without busting (>21).")
    print(f"Bust Cards (Value 10, 9) are mapped to 'Bad' timelines.")
    
    success_count = 0
    
    for i in range(trials):
        idx = run_blackjack_trial()
        if idx is not None:
            card_desc = DECK.get(idx, "Unknown")
            print(f"Hand {i+1}: Drew {card_desc}")
            if "SAFE" in card_desc:
                success_count += 1
        else:
            print(f"Hand {i+1}: Multiverse Collapse (Error)")
            
    print(f"\nResult: {success_count}/{trials} hands were SAFE.")
    if success_count == trials:
        print("🏆 CONCLUSION: The House always loses in Reality B.")
    else:
        print("❌ CONCLUSION: Entropy found a way (Check Oracle Mapping).")

if __name__ == "__main__":
    run_session()
